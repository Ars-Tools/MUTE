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
import func BLAS.ger
import func BLAS.copy
import func LAPACK.gels
import func LAPACK.gesvd
import func MKL.vDSP_ctoz
import func NSP.wiener
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
                    duplicateTolerance: Float64 = 16384 * Float64.ulpOfOne,
                    feasibilityTolerance: Float64 = 4096 * Float64.ulpOfOne,
                    multiplierTolerance: Float64 = 4096 * Float64.ulpOfOne,
                    count: (b: Int, a: Int)) -> Direct.ChebyshevPowerRational {
        let m = ω.count
        precondition(m == x.count)
        precondition(m == y.count)
        precondition(m == w.count)
        precondition(0 <= count.b)
        precondition(0 <= count.a)
        precondition(ε.isFinite && 0 < ε && ε < 1)
        let pCount = count.b + 1
        let qCount = count.a + 1
        let n = pCount + qCount
        precondition(n <= m + 1)
        precondition(x.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(y.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(ω.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(w.withUnsafeBufferPointer { $0.allSatisfy { $0.isFinite && 0 <= $0 } })
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + 2 * m) { memory in
            memory.initialize(repeating: 0)
            let design = UnsafeMutableBufferPointer(rebasing: memory[0 ..< m * n])
            let abscissa = UnsafeMutableBufferPointer(rebasing: memory[m * n ..< m * (n + 1)])
            let scale = UnsafeMutableBufferPointer(rebasing: memory[m * (n + 1) ..< m * (n + 2)])

            // M[l,:] = sqrt(w[l]) [x[l]T_b, -y[l]T_a].
            vDSP.multiply(2, ω, result: &abscissa[0..<m])
            vForce.cosPi(abscissa, result: &abscissa[0..<m])
            vForce.sqrt(w, result: &scale[0..<m])
            vDSP.multiply(scale, x, result: &design[0..<m])
            vDSP.multiply(scale, y, result: &design[pCount * m ..< (pCount + 1) * m])
            vDSP.negative(design[pCount * m ..< (pCount + 1) * m],
                          result: &design[pCount * m ..< (pCount + 1) * m])

            if 1 < pCount {
                vDSP.multiply(abscissa, design[0..<m], result: &design[m..<2 * m])
            }
            for column in 2..<pCount {
                let result = column * m ..< (column + 1) * m
                vDSP.multiply(abscissa, design[(column - 1) * m ..< column * m], result: &design[result])
                vDSP.add(multiplication: (design[result], 2),
                         multiplication: (design[(column - 2) * m ..< (column - 1) * m], -1),
                         result: &design[result])
            }
            if 1 < qCount {
                vDSP.multiply(abscissa,
                              design[pCount * m ..< (pCount + 1) * m],
                              result: &design[(pCount + 1) * m ..< (pCount + 2) * m])
            }
            for column in 2..<qCount {
                let result = (pCount + column) * m ..< (pCount + column + 1) * m
                vDSP.multiply(abscissa,
                              design[(pCount + column - 1) * m ..< (pCount + column) * m],
                              result: &design[result])
                vDSP.add(multiplication: (design[result], 2),
                         multiplication: (design[(pCount + column - 2) * m ..< (pCount + column - 1) * m], -1),
                         result: &design[result])
            }

            return fit(
                design: .init(design),
                rowCount: m,
                minimum: ε,
                duplicateTolerance: duplicateTolerance,
                feasibilityTolerance: feasibilityTolerance,
                multiplierTolerance: multiplierTolerance,
                count: count
            )
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
