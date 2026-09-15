//
//  Linear+Fit.swift
//  MUTE
//
//  Created by Kota on 9/7/26.
//
import typealias Numerics.Complex128
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func Accelerate.vDSP_mmovD
import func BLAS.dot
import func BLAS.ger
import func BLAS.copy
import func BLAS.gemv
import func LAPACK.gels
import func LAPACK.gesvd
import func LAPACK.gglse
import func MKL.vDSP_ctoz
import func NSP.wiener
import func Layout.concat
// MARK: Complex Fit
extension Linear {
    @inlinable // J = Σ w[l] / (|X[l]|² + |Y[l]|²) * |A[l]Y[l] - B[l]X[l]|²
    static func fit(x: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
                    y: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
                    frequency: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                    weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                    count: (b: Int, a: Int)) -> Direct {
        let ω = frequency.count
        precondition(ω == x.r.count)
        precondition(ω == x.i.count)
        precondition(ω == y.r.count)
        precondition(ω == y.i.count)
        precondition(ω == w.count)
        precondition(0 <= count.b)
        precondition(0 <= count.a)
        let m = 2 * ω
        let n = 2 + count.b + count.a
        let l = gesvd(m, n,
                      .none, m,
                      .none,
                      .none, m,
                      .init(bitPattern: ~0), n,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + n * n + max(m, n) + max(m, l)) {
            let M = $0.extracting(0..<m*n)
            let v = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(n * n))
            let s = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n).prefix(max(m, n)))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n + max(m, n)).prefix(max(m, l)))
            let B = M.extracting((0 + 0 * count.b + 0 * count.a) * m ..< (1 + 1 * count.b + 0 * count.a) * m)
            let A = M.extracting((1 + 1 * count.b + 0 * count.a) * m ..< (2 + 1 * count.b + 1 * count.a) * m)
            assert((1 + count.b) * m == B.count)
            assert((1 + count.a) * m == A.count)
            // weight
            vDSP.add(multiplication: (x.r, x.r), multiplication: (x.i, x.i), result: &z[0..<ω])
            vDSP.add(multiplication: (y.r, y.r), multiplication: (y.i, y.i), result: &z[ω..<m])
            vDSP.add(z[0..<ω], z[ω..<m], result: &z[0..<ω])
            vDSP.divide(w, z[0..<ω], result: &z[0..<ω])
            vForce.sqrt(z[0..<ω], result: &z[0..<ω])
            // b0
            vDSP.multiply(x.r, z[0..<ω], result: &B[0..<ω])
            vDSP.multiply(x.i, z[0..<ω], result: &B[ω..<m])
            // a0
            vDSP.multiply(y.r, z[0..<ω], result: &A[0..<ω])
            vDSP.multiply(y.i, z[0..<ω], result: &A[ω..<m])
            vDSP.negative(A[0..<m], result: &A[0..<m])
            // basis
            for k in 0..<max(count.b, count.a) {
                let col = m * k + m
                vDSP.multiply(.init(-2*k-2), frequency, result: &z[ω..<m])
                vForce.cosPi(z[ω..<m], result: &z[0..<ω])
                vForce.sinPi(z[ω..<m], result: &z[ω..<m])
                if k < count.b {
                    vDSP.subtract(multiplication: (B[0..<ω], z[0..<ω]), multiplication: (B[ω..<m], z[ω..<m]), result: &B[col+0..<col+ω])
                    vDSP.add(multiplication: (B[0..<ω], z[ω..<m]), multiplication: (B[ω..<m], z[0..<ω]), result: &B[col+ω..<col+m])
                }
                if k < count.a {
                    vDSP.subtract(multiplication: (A[0..<ω], z[0..<ω]), multiplication: (A[ω..<m], z[ω..<m]), result: &A[col+0..<col+ω])
                    vDSP.add(multiplication: (A[0..<ω], z[ω..<m]), multiplication: (A[ω..<m], z[0..<ω]), result: &A[col+ω..<col+m])
                }
            }
            let ε = gesvd(m, n,
                          M.baseAddress, m,
                          s.baseAddress,
                          .none, m,
                          v.baseAddress, n,
                          z.baseAddress, z.count)
            assert(ε == 0)
            return.init(raw: (
                .init(unsafeUninitializedCapacity: 1 + count.b) {
                    $1 = $0.count
                    copy($1,
                         v.baseAddress.unsafelyUnwrapped.advanced(by: ( count.b * 0 + 1 ) * n - 1), n,
                         $0.baseAddress.unsafelyUnwrapped, 1)
                },
                .init(unsafeUninitializedCapacity: 1 + count.a) {
                    $1 = $0.count
                    copy($1,
                         v.baseAddress.unsafelyUnwrapped.advanced(by: ( count.b * 1 + 2 ) * n - 1), n,
                         $0.baseAddress.unsafelyUnwrapped, 1)
                }
            ))
        }
    }
    @inlinable // J = Σ_l w[l] * E[|A[l]Y[l] - B[l]X[l]|²] / (E[|X[l]|²] + E[|Y[l]|²])
    static func fit(x: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
                    y: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
                    cov c: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>), /* c(ω) = E[(X-E[X])*(Y-E[Y])^H] */
                    frequency: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                    weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                    count: (b: Int, a: Int)) -> Direct {
        let ω = frequency.count
        precondition(ω == x.r.count)
        precondition(ω == x.i.count)
        precondition(ω == y.r.count)
        precondition(ω == y.i.count)
        precondition(ω == c.r.count)
        precondition(ω == c.i.count)
        precondition(ω == x.σ².count)
        precondition(ω == y.σ².count)
        precondition(ω == w.count)
        precondition(0 <= count.b)
        precondition(0 <= count.a)
        let m = 4 * ω
        let n = 2 + count.b + count.a
        let l = gesvd(m, n,
                      .none, m,
                      .none,
                      .none, m,
                      .init(bitPattern: ~0), n,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + n * n + max(m, n) + max(m, l)) {
            let M = $0.extracting(0..<m*n)
            let v = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(n * n))
            let s = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n).prefix(max(m, n)))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n + max(m, n)).prefix(max(m, l)))
            let B = M.extracting((0 + 0 * count.b + 0 * count.a) * m ..< (1 + 1 * count.b + 0 * count.a) * m)
            let A = M.extracting((1 + 1 * count.b + 0 * count.a) * m ..< (2 + 1 * count.b + 1 * count.a) * m)
            // R
            vDSP.add(multiplication: (x.r, x.r), multiplication: (x.i, x.i), result: &s[0*ω..<1*ω])
            vDSP.add(x.σ², s[0*ω..<1*ω], result: &s[0*ω..<1*ω]) // E[XX]
            vDSP.add(multiplication: (y.r, y.r), multiplication: (y.i, y.i), result: &s[1*ω..<2*ω])
            vDSP.add(y.σ², s[1*ω..<2*ω], result: &s[1*ω..<2*ω]) // E[YY]
            vDSP.add(multiplication: (x.r, y.r), multiplication: (x.i, y.i), result: &s[2*ω..<3*ω])
            vDSP.add(c.r, s[2*ω..<3*ω], result: &s[2*ω..<3*ω]) // Re[E[XY^H]]
            vDSP.subtract(multiplication: (y.r, x.i), multiplication: (y.i, x.r), result: &s[3*ω..<4*ω])
            vDSP.add(c.i, s[3*ω..<4*ω], result: &s[3*ω..<4*ω]) // Im[E[XY^H]]
            vDSP.add(s[0*ω..<1*ω], s[1*ω..<2*ω], result: &M[0..<ω]) // M[0..<ω] = E[XX] + E[YY]
            // S
            vDSP.divide(s[0*ω..<1*ω], M[0..<ω], result: &z[0*ω..<1*ω]) // θ[0] = E[XX]/(E[XX]+E[YY])
            vDSP.divide(s[1*ω..<2*ω], M[0..<ω], result: &z[1*ω..<2*ω]) // θ[1] = E[YY]/(E[XX]+E[YY])
            vDSP.divide(s[2*ω..<3*ω], M[0..<ω], result: &z[2*ω..<3*ω]) // θ[2] = Re[E|XY^H|]/(E[XX]+E[YY])
            vDSP.divide(s[3*ω..<4*ω], M[0..<ω], result: &z[3*ω..<4*ω]) // θ[3] = Im[E|XY^H|]/(E[XX]+E[YY])
            vDSP.add(multiplication: (z[2*ω..<3*ω], z[2*ω..<3*ω]), multiplication: (z[3*ω..<4*ω], z[3*ω..<4*ω]), result: &M[1*ω..<2*ω]) // M[1] = |E[XY^H]|^2
            vDSP.subtract(multiplication: (z[0*ω..<1*ω], z[1*ω..<2*ω]), M[1*ω..<2*ω], result: &M[1*ω..<2*ω]) // M[1] = E[XX]E[YY]-|E[XY^H]|^2
            vDSP.threshold(M[1*ω..<2*ω], to: 0, with: .clampToThreshold, result: &M[1*ω..<2*ω])
            vForce.sqrt(M[1*ω..<2*ω], result: &M[1*ω..<2*ω]) // M[1] = sqrt(MAX(M[1], 0)) = δ
            vDSP.add(multiplication: (M[1*ω..<2*ω], 2), 1, result: &M[0*ω..<1*ω])
            vDSP.divide(w, M[0*ω..<1*ω], result: &M[0*ω..<1*ω])
            vForce.sqrt(M[0*ω..<1*ω], result: &M[0*ω..<1*ω]) // M[0] = sqrt(w/max(0, 2*δ+1)) = g
            vDSP.add(multiplication: (M[0*ω..<1*ω], 0), M[0*ω..<1*ω], result: &M[0*ω..<1*ω]) // replace inf with nan
            vDSP.invertedClip(M[0*ω..<1*ω], to: 0...0, result: &M[0*ω..<1*ω]) // replace nan with zero
            vDSP.add(z[0*ω..<1*ω], M[1*ω..<2*ω], result: &z[0*ω..<1*ω]) // r_xx + δ
            vDSP.add(z[1*ω..<2*ω], M[1*ω..<2*ω], result: &z[1*ω..<2*ω]) // r_yy + δ
            vDSP.multiply(M[0..<ω], z[0*ω..<1*ω], result: &z[0*ω..<1*ω]) // g * (r_xx + δ) = Sxx
            vDSP.multiply(M[0..<ω], z[1*ω..<2*ω], result: &z[1*ω..<2*ω]) // g * (r_yy + δ) = Syy
            vDSP.multiply(M[0..<ω], z[2*ω..<3*ω], result: &z[2*ω..<3*ω]) // g * (Re[E|XY^H|]) = Re[Sxy]
            vDSP.multiply(M[0..<ω], z[3*ω..<4*ω], result: &z[3*ω..<4*ω]) // g * (Im[E|XY^H|]) = Im[Sxy]
            // basis
            for k in 0..<max(count.b, count.a) + 1 {
                let col = m * k
                vDSP.multiply(.init(-2*k), frequency, result: &s[1*ω..<2*ω])
                vForce.cosPi(s[1*ω..<2*ω], result: &s[0*ω..<1*ω])
                vForce.sinPi(s[1*ω..<2*ω], result: &s[1*ω..<2*ω])
                if k < count.b + 1 {
                    vDSP.multiply(s[0*ω..<1*ω], z[0*ω..<1*ω], result: &B[col+0*ω..<col+1*ω])
                    vDSP.multiply(s[1*ω..<2*ω], z[0*ω..<1*ω], result: &B[col+1*ω..<col+2*ω])
                    vDSP.subtract(multiplication: (s[0*ω..<1*ω], z[2*ω..<3*ω]), multiplication: (s[1*ω..<2*ω], z[3*ω..<4*ω]), result: &B[col+2*ω..<col+3*ω])
                    vDSP.add(multiplication: (s[1*ω..<2*ω], z[2*ω..<3*ω]), multiplication: (s[0*ω..<1*ω], z[3*ω..<4*ω]), result: &B[col+3*ω..<col+4*ω])
                }
                if k < count.a + 1 {
                    vDSP.add(multiplication: (s[0*ω..<1*ω], z[2*ω..<3*ω]), multiplication: (s[1*ω..<2*ω], z[3*ω..<4*ω]), result: &A[col+0*ω..<col+1*ω])
                    vDSP.subtract(multiplication: (s[1*ω..<2*ω], z[2*ω..<3*ω]), multiplication: (s[0*ω..<1*ω], z[3*ω..<4*ω]), result: &A[col+1*ω..<col+2*ω])
                    vDSP.multiply(s[0*ω..<1*ω], z[1*ω..<2*ω], result: &A[col+2*ω..<col+3*ω])
                    vDSP.multiply(s[1*ω..<2*ω], z[1*ω..<2*ω], result: &A[col+3*ω..<col+4*ω])
                    vDSP.negative(A[col..<col+m], result: &A[col..<col+m])
                }
            }
            let ε = gesvd(m, n,
                          M.baseAddress, m,
                          s.baseAddress,
                          .none, m,
                          v.baseAddress, n,
                          z.baseAddress, z.count)
            assert(ε == 0)
            return.init(raw: (
                .init(unsafeUninitializedCapacity: 1 + count.b) {
                    $1 = $0.count
                    copy($1,
                         v.baseAddress.unsafelyUnwrapped.advanced(by: ( count.b * 0 + 1 ) * n - 1), n,
                         $0.baseAddress.unsafelyUnwrapped, 1)
                },
                .init(unsafeUninitializedCapacity: 1 + count.a) {
                    $1 = $0.count
                    copy($1,
                         v.baseAddress.unsafelyUnwrapped.advanced(by: ( count.b * 1 + 2 ) * n - 1), n,
                         $0.baseAddress.unsafelyUnwrapped, 1)
                }
            ))
        }
    }
}
// MARK: Power Fit
extension Linear {
    @inlinable // LS with constrains
    static func fit(m: Int, n: Int,
                    a: some AccelerateBuffer<Float64>, lda: Int,
                    c: some AccelerateBuffer<Float64>,
                    iteration: Int,
                    initial I: some AccelerateBuffer<Float64>,
                    subject S: some Collection<(Array<Float64>, Float64)>,
                    penalty P: (borrowing UnsafeBufferPointer<Float64>) -> some Collection<(Array<Float64>, Float64)>) -> Array<Float64> {
        .init(unsafeUninitializedCapacity: n) { θ, count in
            count = I.withUnsafeBufferPointer(θ.update(fromContentsOf:))
            let p = n // maximum constrains
            let l = SIMD3<Int>(
                gglse(m, n, p,
                      .none, m,
                      .none, p,
                      .none,
                      .none,
                      .none,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0),
                gels(n, n, 1,
                     .none, n, .N,
                     .none, n,
                     .none as Optional<UnsafeMutablePointer<Float64>>, 0),
                n
            )
            assert((0 .< l) == .init(repeating: true))
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + p * n + m + p + n + l.max()) { // A + c + B (maximum) + d (maximum) + x + workspace
                let A = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
                let B = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(p * n))
                let C = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + p * n).prefix(m))
                let D = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + p * n + m).prefix(p))
                let χ = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + p * n + m + p).prefix(n))
                let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + p * n + m + p + n).prefix(l.max()))
                var Q = (
                    active: Array<(Array<Float64>, Float64)>(),
                    pended: Array<(Array<Float64>, Float64)>(),
                    forced: S,
                )
                Q.active.reserveCapacity(p)
                Q.pended.reserveCapacity(p)
                loop: for () in repeatElement((), count: iteration) {
                    // MARK: GGLSE
                    a.withUnsafeBufferPointer {
                        vDSP_mmovD($0.baseAddress.unsafelyUnwrapped, A.baseAddress.unsafelyUnwrapped,
                                   .init(m), .init(n), .init(lda), .init(m))
                    }
                    c.withUnsafeBufferPointer {
                        copy(m,
                             $0.baseAddress.unsafelyUnwrapped, 1,
                             C.baseAddress.unsafelyUnwrapped, 1)
                    }
                    for (idx, (query, score)) in concat(Q.forced, Q.active).enumerated() {
                        copy(n,
                             query, 1,
                             B.baseAddress.unsafelyUnwrapped.advanced(by: idx), p)
                        D[idx] = score
                    }
                    switch gglse(m, n, Q.forced.count + Q.active.count,
                                 A.baseAddress, m,
                                 B.baseAddress, p,
                                 C.baseAddress,
                                 D.baseAddress,
                                 χ.baseAddress,
                                 w.baseAddress, w.count) {
                    case let s:
                        assert(s == 0)
                    }
                    // MARK: Line Search
                    vDSP.subtract(χ, θ, result: &w[0..<n]) // direction = candidate - current
                    // blocking
                    let b = Q.pended.enumerated().compactMap {
                        let χᵟ = dot(n, $1.0, 1, χ.baseAddress.unsafelyUnwrapped, 1)
                        let wᵟ = dot(n, $1.0, 1, w.baseAddress.unsafelyUnwrapped, 1)
                        let θᵟ = dot(n, $1.0, 1, θ.baseAddress.unsafelyUnwrapped, 1)
                        return χᵟ < $1.1 ?
                            .some(($0, min(0, $1.1 - θᵟ) / wᵟ)) :
                            .none as Optional<(Int, Float64)>
                    }.min {
                        $0.1 < $1.1
                    }
                    if let b {
                        Q.active.append(Q.pended.remove(at: b.0))
                        vDSP.add(multiplication: (w[0..<n], b.1), θ, result: &θ[0..<n])
                        continue loop
                    }
                    // update
                    switch θ.update(fromContentsOf: χ) {
                    case let eof:
                        assert(eof == θ.endIndex)
                    }
                    // removal
                    c.withUnsafeBufferPointer {
                        copy(m,
                             $0.baseAddress.unsafelyUnwrapped, 1,
                             C.baseAddress.unsafelyUnwrapped, 1)
                    }
                    a.withUnsafeBufferPointer {
                        gemv(m, n,
                             1,
                             $0.baseAddress.unsafelyUnwrapped, lda, .N,
                             χ.baseAddress.unsafelyUnwrapped, 1,
                             -1,
                             C.baseAddress.unsafelyUnwrapped, 1)
                        gemv(m, n,
                             -1,
                             $0.baseAddress.unsafelyUnwrapped, lda, .T,
                             C.baseAddress.unsafelyUnwrapped, 1,
                             0,
                             D.baseAddress.unsafelyUnwrapped, 1
                        )
                    }
                    // B = Kᵀ
                    for (col, q) in concat(Q.active, Q.forced).enumerated() {
                        copy(n,
                             q.0, 1,
                             B.baseAddress.unsafelyUnwrapped.advanced(by: col * n), 1)
                    }
                    // min ‖Kᵀλ + g‖
                    switch gels(n, Q.active.count + Q.forced.count, 1,
                                B.baseAddress, n, .N,
                                D.baseAddress, n,
                                w.baseAddress, w.count) {
                    case let s:
                        assert(s == 0)
                    }
                    let r = Q.active.indices.filter {
                        0 < D[$0]
                    }.max {
                        D[$0] < D[$1]
                    }
                    if let r {
                        Q.pended.append(Q.active.remove(at: r))
                        switch θ.update(fromContentsOf: χ) {
                        case let eof:
                            assert(eof == θ.endIndex)
                        }
                        continue loop
                    }
                    // MARK: violations
                    let v = P(.init(χ))
                    if !v.isEmpty {
                        Q.pended.append(contentsOf: Q.active)
                        Q.active.removeAll(keepingCapacity: true)
                        Q.pended.append(contentsOf: v)
                        switch I.withUnsafeBufferPointer(θ.update(fromContentsOf:)) {
                        case let eof:
                            assert(eof == θ.endIndex)
                        }
                        continue loop
                    }
                    break loop
                }
            }
        }
    }
    @inlinable // LS with constrains
    static func fit(m: Int, n: Int,
                    a: some AccelerateBuffer<Float64>, lda: Int,
                    c: some AccelerateBuffer<Float64>,
                    initial I: Array<Float64>,
                    subject S: Array<(Array<Float64>, Float64)>,
                    penalty P: (Array<Float64>) -> Array<(Array<Float64>, Float64)>) -> Array<Float64> {
        assert(I.count == n)
        let p = n // maximum constrains
        var Q = (
            active: Array<(Array<Float64>, Float64)>(),
            pended: Array<(Array<Float64>, Float64)>(),
            forced: S,
        )
        Q.active.reserveCapacity(p)
        Q.pended.reserveCapacity(p)
        let l = max(
            gglse(m, n, p,
                  .none, m,
                  .none, p,
                  .none,
                  .none,
                  .none,
                  .none as Optional<UnsafeMutablePointer<Float64>>, 0),
            gels(n, n, 1,
                 .none, n, .N,
                 .none, n,
                 .none as Optional<UnsafeMutablePointer<Float64>>, 0),
            n
        )
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + p * n + m + p + n + l) { // A + c + B (maximum) + d (maximum) + x + workspace
            let A = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let B = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(p * n))
            let C = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + p * n).prefix(m))
            let D = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + p * n + m).prefix(p))
            let θ = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + p * n + m + p).prefix(n))
            let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + p * n + m + p + n).prefix(l))
            switch θ.initialize(fromContentsOf: I) {
            case let eof:
                assert(eof == θ.endIndex)
            }
            for () in repeatElement((), count: m) {
                a.withUnsafeBufferPointer {
                    vDSP_mmovD($0.baseAddress.unsafelyUnwrapped, A.baseAddress.unsafelyUnwrapped,
                               .init(m), .init(n), .init(lda), .init(m))
                }
                c.withUnsafeBufferPointer {
                    copy(m,
                         $0.baseAddress.unsafelyUnwrapped, 1,
                         C.baseAddress.unsafelyUnwrapped, 1)
                }
                for (idx, (query, score)) in concat(Q.forced, Q.active).enumerated() {
                    copy(query.count,
                         query, 1,
                         B.baseAddress.unsafelyUnwrapped.advanced(by: idx), p)
                    D[idx] = score
                }
                let χ = Array<Float64>(unsafeUninitializedCapacity: n) {
                    $1 = $0.count
                    switch gglse(m, n, Q.forced.count + Q.active.count,
                                 A.baseAddress, m,
                                 B.baseAddress, p,
                                 C.baseAddress,
                                 D.baseAddress,
                                 $0.baseAddress,
                                 w.baseAddress, w.count) {
                    case let s:
                        assert(s == 0)
                    }
                }
                // line search
                vDSP.subtract(χ, θ, result: &w[0..<n]) // direction = candidate - current
                let b = Q.pended.enumerated().compactMap {
                    let χᵟ = dot(n, $1.0, 1, χ, 1)
                    let wᵟ = dot(n, $1.0, 1, w.baseAddress.unsafelyUnwrapped, 1)
                    let θᵟ = dot(n, $1.0, 1, θ.baseAddress.unsafelyUnwrapped, 1)
                    return χᵟ < $1.1 ?
                        .some(($0, min(0, $1.1 - θᵟ) / wᵟ)) :
                        .none as Optional<(Int, Float64)>
                }.min {
                    $0.1 < $1.1
                } // blocking
                if let b {
                    Q.active.append(Q.pended.remove(at: b.0))
                    vDSP.add(multiplication: (w[0..<n], b.1), θ, result: &θ[0..<n])
                } else {
                    switch θ.update(fromContentsOf: χ) {
                    case let eof:
                        assert(eof == θ.endIndex)
                    }
                    // dualInfeasibleConstraint
                    c.withUnsafeBufferPointer {
                        copy(m,
                             $0.baseAddress.unsafelyUnwrapped, 1,
                             C.baseAddress.unsafelyUnwrapped, 1)
                    }
                    a.withUnsafeBufferPointer {
                        gemv(m, n,
                             1,
                             $0.baseAddress.unsafelyUnwrapped, lda, .N,
                             χ, 1,
                             -1,
                             C.baseAddress.unsafelyUnwrapped, 1)
                        gemv(m, n,
                             -1,
                             $0.baseAddress.unsafelyUnwrapped, lda, .T,
                             C.baseAddress.unsafelyUnwrapped, 1,
                             0,
                             D.baseAddress.unsafelyUnwrapped, 1
                        )
                    }
                    // B = Kᵀ
                    for (col, q) in concat(Q.active, Q.forced).enumerated() {
                        copy(n,
                             q.0, 1,
                             B.baseAddress.unsafelyUnwrapped.advanced(by: col * n), 1)
                    }
                    // min ‖Kᵀλ + g‖
                    switch gels(n, Q.active.count + Q.forced.count, 1,
                                B.baseAddress, n, .N,
                                D.baseAddress, n,
                                w.baseAddress, w.count) {
                    case let s:
                        assert(s == 0)
                    }
                    let r = Q.active.indices.filter {
                        0 < D[$0]
                    }.max {
                        D[$0] < D[$1]
                    } // removal
                    if let r {
                        Q.pended.append(Q.active.remove(at: r))
                        switch θ.update(fromContentsOf: χ) {
                        case let eof:
                            assert(eof == θ.endIndex)
                        }
                    } else {
                        switch P(χ) {
                        case let v where v.isEmpty:
                            return χ
                        case let v:
                            Q.pended.append(contentsOf: Q.active)
                            Q.active.removeAll(keepingCapacity: true)
                            Q.pended.append(contentsOf: v)
                            switch θ.update(fromContentsOf: I) {
                            case let eof:
                                assert(eof == θ.endIndex)
                            }
                        } // violations
                    }
                }
            }
            assertionFailure()
            return I
        }
    }
}
extension Linear {
    @inlinable // Power LS (SVD)
    static func fit(X x: some AccelerateBuffer<Float64>, /* XX */
                    Y y: some AccelerateBuffer<Float64>, /* YY */
                    frequency ω: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                    weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                    count: (b: Int, a: Int)) -> Direct.ChebyshevPowerRational {
        let m = ω.count
        precondition(m == x.count)
        precondition(m == y.count)
        precondition(m == w.count)
        precondition(0 <= count.b)
        precondition(0 <= count.a)
        let n = 2 + count.b + count.a
        let l = gesvd(m, n,
                      .none, m,
                      .none,
                      .none, m,
                      .init(bitPattern: ~0), n,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + n * n + max(m, n) + max(m, l)) {
            let M = $0.extracting(0..<m*n)
            let B = UnsafeMutableBufferPointer(rebasing: M.prefix(m * (1 + count.b)))
            let A = UnsafeMutableBufferPointer(rebasing: M.suffix(m * (1 + count.a)))
            let v = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(n * n))
            let s = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n).prefix(max(m, n)))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n + max(m, n)).prefix(max(m, l)))
            // weight
            vForce.sqrt(w, result: &z[0..<m])
            // b0
            vDSP.multiply(z[0..<m], x, result: &B[0..<m])
            // a0
            vDSP.multiply(z[0..<m], y, result: &A[0..<m])
            vDSP.negative(A[0..<m], result: &A[0..<m])
            // basis
            for k in 0..<max(count.b, count.a) {
                let col = m * k + m
                vDSP.multiply(.init(2*k+2), ω, result: &z[0..<m])
                vForce.cosPi(z[0..<m], result: &z[0..<m])
                vDSP.multiply(2.0.squareRoot(), z[0..<m], result: &z[0..<m])
                if k < count.b { // b
                    vDSP.multiply(z[0..<m], B[0..<m], result: &B[col..<col+m])
                }
                if k < count.a { //a
                    vDSP.multiply(z[0..<m], A[0..<m], result: &A[col..<col+m])
                }
            }
            let ε = gesvd(m, n,
                          M.baseAddress, m,
                          s.baseAddress,
                          .none, m,
                          v.baseAddress, n,
                          z.baseAddress, z.count)
            assert(ε == 0)
            let pₛ = ( count.b * 0 + 1 ) * n - 1
            let qₛ = ( count.b * 1 + 2 ) * n - 1
            s[0] = v[pₛ].sign != v[qₛ].sign ? -1 : 1
            s.dropFirst().update(repeating: s[0] * 2.0.squareRoot())
            return.init(raw: (
                .init(unsafeUninitializedCapacity: 1 + count.b) {
                    $1 = $0.count
                    copy($1,
                         v.baseAddress.unsafelyUnwrapped.advanced(by: pₛ), n,
                         $0.baseAddress.unsafelyUnwrapped, 1)
                    vDSP.multiply(s[0..<$1], $0, result: &$0)
                },
                .init(unsafeUninitializedCapacity: 1 + count.a) {
                    $1 = $0.count
                    copy($1,
                         v.baseAddress.unsafelyUnwrapped.advanced(by: qₛ), n,
                         $0.baseAddress.unsafelyUnwrapped, 1)
                    vDSP.multiply(s[0..<$1], $0, result: &$0)
                }
            ))
        }
    }
    // Power LS with P(t), Q(t) >= ε for every t in [-1, 1].
    // The otherwise homogeneous scale is fixed symmetrically by p[0] + q[0] = 2.
    static func fit(X x: some AccelerateBuffer<Float64>, /* XX */
                    Y y: some AccelerateBuffer<Float64>, /* YY */
                    frequency ω: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                    weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                    minimum ε: Float64,
                    count: (p: Int, q: Int)) -> Direct.ChebyshevPowerRational {
        let m = ω.count
        precondition(m == x.count)
        precondition(m == y.count)
        precondition(m == w.count)
        precondition(0 <= count.p)
        precondition(0 <= count.q)
        precondition(ε.isFinite && 0 < ε && ε < 1)
        let (p, q) = switch count {
        case (let p, let q):
            (p + 1, q + 1)
        }
        let n = p + q
        precondition(n <= m + 1)
        precondition(x.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(y.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(ω.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(w.withUnsafeBufferPointer { $0.allSatisfy { $0.isFinite && 0 <= $0 } })
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + 2 * m) {
            let M = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(max(m, n)))
            // M[l,:] = sqrt(w[l]/(x^2 + y^2)) [x[l]T_b, -y[l]T_a].
            vForce.sqrt(w, result: &z[0..<m])
            vDSP.hypot(x, y, result: &M[p * m ..< p * m + m])
            vDSP.divide(x, M[p * m ..< p * m + m], result: &M[0 * m ..< 0 * m + m])
            vDSP.multiply(z[0..<m], M[0 * m ..< 0 * m + m], result: &M[0 * m ..< 0 * m + m])
            vDSP.invertedClip(M[0 * m ..< 0 * m + m], to: 0...0, result: &M[0 * m ..< 0 * m + m])
            vDSP.divide(y, M[p * m ..< p * m + m], result: &M[p * m ..< p * m + m])
            vDSP.multiply(z[0..<m], M[p * m ..< p * m + m], result: &M[p * m ..< p * m + m])
            vDSP.invertedClip(M[p * m ..< p * m + m], to: 0...0, result: &M[p * m ..< p * m + m])
            vDSP.negative(M[p * m ..< p * m + m], result: &M[p * m ..< p * m + m])
            /*
            vDSP.add(multiplication: (x, x),
                     multiplication: (y, y),
                     result: &z[0..<m])
            vDSP.divide(w, z[0..<m], result: &z[0..<m])
            vForce.sqrt(z[0..<m], result: &z[0..<m])
            vDSP.multiply(x, z[0..<m], result: &M[0 * m ..< 0 * m + m])
            vDSP.multiply(y, z[0..<m], result: &M[p * m ..< p * m + m])
            vDSP.negative(M[p * m ..< p * m + m], result: &M[p * m ..< p * m + m])
            */
            for k in 1..<max(p, q) {
                vDSP.multiply(.init(2 * k), ω, result: &z[0..<m])
                vForce.cosPi(z[0..<m], result: &z[0..<m])
                if k < p {
                    let r = (0 + k) * m ..< (0 + k) * m + m
                    vDSP.multiply(z[0..<m], M[0 * m ..< 0 * m + m], result: &M[r])
                }
                if k < q {
                    let r = (p + k) * m ..< (p + k) * m + m
                    vDSP.multiply(z[0..<m], M[p * m ..< p * m + m], result: &M[r])
                }
            }
            /* chebyshev procedure
            vDSP.multiply(2, ω, result: &z[0..<m])
            vForce.cosPi(z[0..<m], result: &z[0..<m])
            if 1 < p {
                vDSP.multiply(z[0..<m],
                              M[0 * m ..< 0 * m + m],
                              result: &M[0 * m + m ..< 0 * m + m + m])
            }
            for col in 2..<p {
                let r = (0 + col) * m ..< (0 + col) * m + m
                vDSP.multiply(z[0..<m], M[(0 + col - 1) * m ..< (0 + col) * m], result: &M[r])
                vDSP.add(multiplication: (M[r], 2),
                         multiplication: (M[(0 + col - 2) * m ..< (0 + col - 1) * m], -1),
                         result: &M[r])
            }
            if 1 < q {
                vDSP.multiply(z[0..<m],
                              M[p * m ..< p * m + m],
                              result: &M[p * m + m ..< p * m + m + m])
            }
            for col in 2..<q {
                let r = (p + col) * m ..< (p + col) * m + m
                vDSP.multiply(z[0..<m], M[(p + col - 1) * m ..< (p + col) * m], result: &M[r])
                vDSP.add(multiplication: (M[r], 2),
                         multiplication: (M[(p + col - 2) * m ..< (p + col - 1) * m], -1),
                         result: &M[r])
            }
            */
            let T = Array<Float64>(unsafeUninitializedCapacity: n) {
                $1 = $0.count
                vDSP.clear(&$0[0..<$1])
                $0[0] = 1
                $0[p] = 1
            }
            vDSP.clear(&z[0..<m])
            let S = fit(m: m, n: n,
                        a: M, lda: m,
                        c: z,
                        iteration: m,
                        initial: T,
                        subject: Array(arrayLiteral: (T, 2))) {
                [
                    (Direct.ChebyshevPolynomial(.init($0.prefix(p))).minimum, 0..<p),
                    (Direct.ChebyshevPolynomial(.init($0.suffix(q))).minimum, p..<n)
                ].compactMap { m, r in
                    m.value < ε ?
                        .some((.init(unsafeUninitializedCapacity: n) {
                            $1 = $0.count
                            vDSP.clear(&$0[0..<$1])
                            let eof = $0[r].update(from: Linear.Direct.ChebyshevPolynomial.basis(at: m.location)).index
                            assert(eof == $0[r].endIndex)
                        }, ε)) : .none
                }
            }
            return.init(raw: (
                Array(S.prefix(p)),
                Array(S.suffix(q))
            ))
        }
    }
}
// MARK: Power Adapters
extension Linear {
    @_disfavoredOverload
    @inlinable
    static func fit(x: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
                    y: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
                    cov c: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>), /* c(ω) = E[(X-E[X])*(Y-E[Y])^H] */
                    frequency: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                    weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                    count: (b: Int, a: Int)) -> Direct.ChebyshevPowerRational {
        let m = frequency.count
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: 4 * m) {
            let X = $0.extracting(0 * m ..< 1 * m)
            let Y = $0.extracting(1 * m ..< 2 * m)
            let Z = $0.extracting(2 * m ..< 3 * m)
            let W = $0.extracting(3 * m ..< 4 * m)
            // X
            vDSP.add(multiplication: (x.r, x.r), multiplication: (x.i, x.i), result: &X[0..<m])
            // Y
            vDSP.add(multiplication: (y.r, y.r), multiplication: (y.i, y.i), result: &Y[0..<m])
            // r
            vDSP.add(multiplication: (x.r, y.r), multiplication: (x.i, y.i), result: &Z[0..<m])
            vDSP.add(Z, c.r, result: &Z[0..<m])
            vDSP.subtract(multiplication: (y.r, x.i), multiplication: (x.r, y.i), result: &W[0..<m])
            vDSP.add(W, c.i, result: &W[0..<m])
            vDSP.add(multiplication: (Z, Z), multiplication: (W, W), result: &Z[0..<m])
            vDSP.multiply(Z, w, result: &Z[0..<m])
            vDSP.multiply(addition: (X, x.σ²),
                          addition: (Array(Y), y.σ².withUnsafeBufferPointer(Array.init)),/* Interface bug of vDSP.multiply*/
                          result: &W[0..<m])
            vDSP.divide(Z, W, result: &Z[0..<m])
//            vDSP.add(X, x.σ², result: &W[0..<m])
//            vDSP.divide(Z, W, result: &Z[0..<m])
//            vDSP.add(Y, y.σ², result: &W[0..<m])
//            vDSP.divide(Z, W, result: &Z[0..<m])
            return fit(X: X,
                       Y: Y,
                       frequency: frequency,
                       weight: Z,
                       count: count)
        }
        
    }
}
