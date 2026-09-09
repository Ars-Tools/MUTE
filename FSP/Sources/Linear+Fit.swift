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
import func BLAS.gemv
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
    /* GELS Driver
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
        precondition(0 < count.b)
        precondition(0 < count.a)
        let m = 2 * ω
        let n = 1 + count.b + count.a
        let l = gels(m, n, 1,
                     .none, m, .N,
                     .none, max(m, n),
                     .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + max(m, n) + max(m, l)) {
            let M = $0.extracting(0..<m*n)
            let θ = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(max(m, n)))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + max(m, n)).prefix(max(m, l)))
            // weight
            vDSP.add(multiplication: (y.r, y.r), multiplication: (y.i, y.i), result: &M[0..<ω])
            vDSP.add(multiplication: (x.r, x.r), multiplication: (x.i, x.i), result: &M[ω..<m])
            vDSP.add(M[0..<ω], M[ω..<m], result: &M[0..<ω])
            vDSP.divide(w, M[0..<ω], result: &M[0..<ω])
            vForce.sqrt(M[0..<ω], result: &M[0..<ω])
            vDSP.add(multiplication: (M[0..<ω], 0), M[0..<ω], result: &M[0..<ω]) // replace inf with nan
            vDSP.invertedClip(M[0..<ω], to: 0...0, result: &M[0..<ω]) // replace nan with zero
            // basis
            for k in 0..<max(count.b, count.a) {
                vDSP.multiply(.init(-2*k-2), frequency, result: &z[ω..<m])
                vForce.cosPi(z[ω..<m], result: &z[0..<ω])
                vForce.sinPi(z[ω..<m], result: &z[ω..<m])
                vDSP.multiply(M[0..<ω], z[0..<ω], result: &z[0..<ω])
                vDSP.multiply(M[0..<ω], z[ω..<m], result: &z[ω..<m])
                if k < count.b {
                    let col = ( 1 + k + 0 * count.b ) * m
                    vDSP.subtract(multiplication: (x.r, z[0..<ω]), multiplication: (x.i, z[ω..<m]), result: &M[col+0..<col+ω])
                    vDSP.add(multiplication: (x.r, z[ω..<m]), multiplication: (x.i, z[0..<ω]), result: &M[col+ω..<col+m])
                }
                if k < count.a {
                    let col = ( 1 + k + 1 * count.b ) * m
                    vDSP.subtract(multiplication: (y.r, z[0..<ω]), multiplication: (y.i, z[ω..<m]), result: &M[col+0..<col+ω])
                    vDSP.add(multiplication: (y.r, z[ω..<m]), multiplication: (y.i, z[0..<ω]), result: &M[col+ω..<col+m])
                    vDSP.negative(M[col..<col+m], result: &M[col..<col+m])
                }
            }
            // rhs (θ)
            vDSP.multiply(M[0..<ω], y.i, result: &θ[ω..<m])
            vDSP.multiply(M[0..<ω], y.r, result: &θ[0..<ω])
            // M[:,0] (DC)
            vDSP.multiply(M[0..<ω], x.i, result: &M[ω..<m])
            vDSP.multiply(M[0..<ω], x.r, result: &M[0..<ω])
            // solve
            let s = gels(m, n, 1,
                         M.baseAddress, m, .N,
                         θ.baseAddress, max(m, n),
                         z.baseAddress, z.count)
            assert(s == 0)
            return.init(raw: (
                .init(θ.prefix(1 + count.b)),
                .init(arrayLiteral: 1) + θ.dropFirst(1 + count.b).prefix(count.a)
            ))
        }
    }
     */
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
    // LS
//    @inlinable // J = Σ_l w[l] * E[|A[l]Y[l] - B[l]X[l]|²] / (E[|X[l]|²] + E[|Y[l]|²])
//    static func fit(x: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
//                    y: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
//                    cov c: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>), /* c(ω) = E[(X-E[X])*(Y-E[Y])^H] */
//                    frequency: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
//                    weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
//                    count: (b: Int, a: Int)) -> Direct {
//        let ω = frequency.count
//        precondition(ω == x.r.count)
//        precondition(ω == x.i.count)
//        precondition(ω == y.r.count)
//        precondition(ω == y.i.count)
//        precondition(ω == c.r.count)
//        precondition(ω == c.i.count)
//        precondition(ω == x.σ².count)
//        precondition(ω == y.σ².count)
//        precondition(ω == w.count)
//        precondition(0 < count.b)
//        precondition(0 < count.a)
//        let m = 4 * ω
//        let n = 1 + count.b + count.a
//        let l = gels(m, n, 1,
//                     .none, m, .N,
//                     .none, max(m, n),
//                     .none as Optional<UnsafeMutablePointer<Float64>>, 0)
//        assert(0 < l)
//        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + max(m, n) + max(m, l)) {
//            let M = $0.extracting(0..<m*n)
//            let θ = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(max(m, n)))
//            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + max(m, n)).prefix(max(m, l)))
//            // R
//            vDSP.add(multiplication: (x.r, x.r), multiplication: (x.i, x.i), result: &θ[0*ω..<1*ω])
//            vDSP.add(x.σ², θ[0*ω..<1*ω], result: &θ[0*ω..<1*ω]) // E[XX]
//            vDSP.add(multiplication: (y.r, y.r), multiplication: (y.i, y.i), result: &θ[1*ω..<2*ω])
//            vDSP.add(y.σ², θ[1*ω..<2*ω], result: &θ[1*ω..<2*ω]) // E[YY]
//            vDSP.add(multiplication: (x.r, y.r), multiplication: (x.i, y.i), result: &θ[2*ω..<3*ω])
//            vDSP.add(c.r, θ[2*ω..<3*ω], result: &θ[2*ω..<3*ω]) // Re[E[XY^H]]
//            vDSP.subtract(multiplication: (y.r, x.i), multiplication: (y.i, x.r), result: &θ[3*ω..<4*ω])
//            vDSP.add(c.i, θ[3*ω..<4*ω], result: &θ[3*ω..<4*ω]) // Im[E[XY^H]]
//            vDSP.add(θ[0*ω..<1*ω], θ[1*ω..<2*ω], result: &M[0..<ω]) // M[0..<ω] = E[XX] + E[YY]
//            // S
//            vDSP.divide(θ[0*ω..<1*ω], M[0..<ω], result: &z[0*ω..<1*ω]) // θ[0] = E[XX]/(E[XX]+E[YY])
//            vDSP.divide(θ[1*ω..<2*ω], M[0..<ω], result: &z[1*ω..<2*ω]) // θ[1] = E[YY]/(E[XX]+E[YY])
//            vDSP.divide(θ[2*ω..<3*ω], M[0..<ω], result: &z[2*ω..<3*ω]) // θ[2] = Re[E|XY^H|]/(E[XX]+E[YY])
//            vDSP.divide(θ[3*ω..<4*ω], M[0..<ω], result: &z[3*ω..<4*ω]) // θ[3] = Im[E|XY^H|]/(E[XX]+E[YY])
//            vDSP.add(multiplication: (z[2*ω..<3*ω], z[2*ω..<3*ω]), multiplication: (z[3*ω..<4*ω], z[3*ω..<4*ω]), result: &M[1*ω..<2*ω]) // M[1] = |E[XY^H]|^2
//            vDSP.subtract(multiplication: (z[0*ω..<1*ω], z[1*ω..<2*ω]), M[1*ω..<2*ω], result: &M[1*ω..<2*ω]) // M[1] = E[XX]E[YY]-|E[XY^H]|^2
//            vDSP.threshold(M[1*ω..<2*ω], to: 0, with: .clampToThreshold, result: &M[1*ω..<2*ω])
//            vForce.sqrt(M[1*ω..<2*ω], result: &M[1*ω..<2*ω]) // M[1] = sqrt(MAX(M[1], 0)) = δ
//            vDSP.add(multiplication: (M[1*ω..<2*ω], 2), 1, result: &M[0*ω..<1*ω])
//            vDSP.divide(w, M[0*ω..<1*ω], result: &M[0*ω..<1*ω])
//            vForce.sqrt(M[0*ω..<1*ω], result: &M[0*ω..<1*ω]) // M[0] = sqrt(w/max(0, 2*δ+1)) = g
//            vDSP.add(z[0*ω..<1*ω], M[1*ω..<2*ω], result: &z[0*ω..<1*ω]) // r_xx + δ
//            vDSP.add(z[1*ω..<2*ω], M[1*ω..<2*ω], result: &z[1*ω..<2*ω]) // r_yy + δ
//            vDSP.multiply(M[0..<ω], z[0*ω..<1*ω], result: &z[0*ω..<1*ω]) // g * (r_xx + δ) = Sxx
//            vDSP.multiply(M[0..<ω], z[1*ω..<2*ω], result: &z[1*ω..<2*ω]) // g * (r_yy + δ) = Syy
//            vDSP.multiply(M[0..<ω], z[2*ω..<3*ω], result: &z[2*ω..<3*ω]) // g * (Re[E|XY^H|]) = Re[Sxy]
//            vDSP.multiply(M[0..<ω], z[3*ω..<4*ω], result: &z[3*ω..<4*ω]) // g * (Im[E|XY^H|]) = Im[Sxy]
//            
//            // Replace non-finite square-root moment components with zero.
//            vDSP.add(multiplication: (z[0..<m], 0), z[0..<m], result: &z[0..<m]) // replace inf with nan
//            vDSP.invertedClip(z[0..<m], to: 0...0, result: &z[0..<m]) // replace nan with zero
//            
//            // basis
//            for k in 0..<max(count.b, count.a) {
//                vDSP.multiply(.init(-2*k-2), frequency, result: &M[1*ω..<2*ω])
//                vForce.cosPi(M[1*ω..<2*ω], result: &M[0*ω..<1*ω])
//                vForce.sinPi(M[1*ω..<2*ω], result: &M[1*ω..<2*ω])
//                if k < count.b {
//                    let col = ( 1 + k + 0 * count.b ) * m
//                    vDSP.multiply(M[0*ω..<1*ω], z[0*ω..<1*ω], result: &M[col+0*ω..<col+1*ω])
//                    vDSP.multiply(M[1*ω..<2*ω], z[0*ω..<1*ω], result: &M[col+1*ω..<col+2*ω])
//                    vDSP.subtract(multiplication: (M[0*ω..<1*ω], z[2*ω..<3*ω]), multiplication: (M[1*ω..<2*ω], z[3*ω..<4*ω]), result: &M[col+2*ω..<col+3*ω])
//                    vDSP.add(multiplication: (M[1*ω..<2*ω], z[2*ω..<3*ω]), multiplication: (M[0*ω..<1*ω], z[3*ω..<4*ω]), result: &M[col+3*ω..<col+4*ω])
//                }
//                if k < count.a {
//                    let col = ( 1 + k + 1 * count.b ) * m
//                    vDSP.add(multiplication: (M[0*ω..<1*ω], z[2*ω..<3*ω]), multiplication: (M[1*ω..<2*ω], z[3*ω..<4*ω]), result: &M[col+0*ω..<col+1*ω])
//                    vDSP.subtract(multiplication: (M[1*ω..<2*ω], z[2*ω..<3*ω]), multiplication: (M[0*ω..<1*ω], z[3*ω..<4*ω]), result: &M[col+1*ω..<col+2*ω])
//                    vDSP.multiply(M[0*ω..<1*ω], z[1*ω..<2*ω], result: &M[col+2*ω..<col+3*ω])
//                    vDSP.multiply(M[1*ω..<2*ω], z[1*ω..<2*ω], result: &M[col+3*ω..<col+4*ω])
//                    vDSP.negative(M[col..<col+m], result: &M[col..<col+m])
//                }
//            }
//            // RHS
//            vDSP.multiply( 1, z[2*ω..<3*ω], result: &θ[0*ω..<1*ω])
//            vDSP.multiply(-1, z[3*ω..<4*ω], result: &θ[1*ω..<2*ω])
//            vDSP.multiply( 1, z[1*ω..<2*ω], result: &θ[2*ω..<3*ω])
//            vDSP.multiply( 0, z[0*ω..<1*ω], result: &θ[3*ω..<4*ω])
//            // M[:,0] (DC)
//            vDSP.multiply( 1, z[0*ω..<1*ω], result: &M[0*ω..<1*ω])
//            vDSP.multiply( 0, z[1*ω..<2*ω], result: &M[1*ω..<2*ω])
//            vDSP.multiply( 1, z[2*ω..<3*ω], result: &M[2*ω..<3*ω])
//            vDSP.multiply( 1, z[3*ω..<4*ω], result: &M[3*ω..<4*ω])
//            // solve
//            let s = gels(m, n, 1,
//                         M.baseAddress, m, .N,
//                         θ.baseAddress, max(m ,n),
//                         z.baseAddress, z.count)
//            assert(s == 0)
//            return.init(raw: (
//                .init(θ.prefix(1 + count.b)),
//                .init(arrayLiteral: 1) + θ.dropFirst(1 + count.b).prefix(count.a)
//            ))
//        }
//    }
}
// MARK: Power Fit
extension Linear {
    @inlinable // Power LS (SVD)
    static func fit(xx x: some AccelerateBuffer<Float64>, /* XX */
                    yy y: some AccelerateBuffer<Float64>, /* YY */
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
            s[0] = 1
            s.dropFirst().update(repeating: 2.0.squareRoot())
            return.init(raw: (
                .init(unsafeUninitializedCapacity: 1 + count.b) {
                    $1 = $0.count
                    copy($1,
                         v.baseAddress.unsafelyUnwrapped.advanced(by: ( count.b * 0 + 1 ) * n - 1), n,
                         $0.baseAddress.unsafelyUnwrapped, 1)
                    vDSP.multiply(s[0..<$1], $0, result: &$0)
                },
                .init(unsafeUninitializedCapacity: 1 + count.a) {
                    $1 = $0.count
                    copy($1,
                         v.baseAddress.unsafelyUnwrapped.advanced(by: ( count.b * 1 + 2 ) * n - 1), n,
                         $0.baseAddress.unsafelyUnwrapped, 1)
                    vDSP.multiply(s[0..<$1], $0, result: &$0)
                }
            ))
        }
    }
    @inlinable // Power LS (Positively constraint)
    static func fit(xx x: some AccelerateBuffer<Float64>, /* XX */
                    yy y: some AccelerateBuffer<Float64>, /* YY */
                    frequency ω: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                    weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                    minimum ε: Float64,
                    count: (b: Int, a: Int)) -> Direct.ChebyshevPowerRational {
        fatalError()
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
            return fit(xx: X,
                       yy: Y,
                       frequency: frequency,
                       weight: Z,
                       count: count)
        }
        
    }
}
extension Linear {
    @inlinable // [0, 2π) complex spectrum → (b, a) direct-form, frequency is normalized angular frequency [0, 2π) → [0, 1.0)
    public static func Fit(frequency: some AccelerateBuffer<Float64>,
                           response: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
                           confidence: some AccelerateBuffer<Float64>, // weight
                           count: (b: Int, a: Int)) -> Direct {
        let ω = frequency.count
        precondition(ω == response.r.count)
        precondition(ω == response.i.count)
        precondition(ω == confidence.count)
        precondition(ω > count.b)
        precondition(ω > count.a)
        precondition(count.b > 0)
        precondition(count.a > 0)
        let m = response.r.count + response.i.count
        let n = 1 + count.b + count.a
        let l = gels(m, n, 1,
                     .none, m, .N,
                     .none, max(m, n),
                     .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + max(m, n) + max(m, l)) {
            let A = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let b = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(max(m, n)))
            let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + max(m, n)).prefix(max(m, l)))
            // Basis
            for k in 0..<max(count.b, count.a) {
                vDSP.multiply(.init(-2*k-2), frequency, result: &A[ω..<m])
                vForce.cosPi(A[ω..<m], result: &A[0..<ω])
                vForce.sinPi(A[ω..<m], result: &A[ω..<m])
                if k < count.b {
                    let v = (1+k+0*count.b) * m ..< (1+k+0*count.b) * m + m
                    switch A[v].update(fromContentsOf: A[0..<m]) {
                    case let eof:
                        assert(eof == A[v].endIndex)
                    }
                }
                if k < count.a {
                    let v = (1+k+1*count.b) * m ..< (1+k+1*count.b) * m + m
                    switch A[v].update(fromContentsOf: A[0..<m]) {
                    case let eof:
                        assert(eof == A[v].endIndex)
                    }
                }
            }
            // precondition by solving Yule-Walker
            vDSP.add(multiplication: (response.r, response.r), multiplication: (response.i, response.i), result: &b[ω..<m])
            b[0] = 1
            gemv(ω, count.a,
                 1 / vDSP.sum(b[ω..<m]),
                 A.baseAddress.unsafelyUnwrapped.advanced(by: count.b * m + m), m, .T,
                 b.baseAddress.unsafelyUnwrapped.advanced(by: ω), 1,
                 0,
                 b.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1) // IDFT
            vDSP.negative(b[1..<1+count.a], result: &w[0..<0+count.a]) // RHS
            wiener(b.baseAddress.unsafelyUnwrapped,
                   w.baseAddress.unsafelyUnwrapped,
                   b.baseAddress.unsafelyUnwrapped.advanced(by: ω),
                   A.baseAddress.unsafelyUnwrapped.advanced(by: 0), // ignore performance score
                   count.a) // solve Yule-Walker
            vDSP.fill(&A[0..<ω], with: 1)
            vDSP.clear(&A[ω..<m])
            gemv(m, count.a,
                 1,
                 A.baseAddress.unsafelyUnwrapped.advanced(by: count.b * m + m), m, .N,
                 b.baseAddress.unsafelyUnwrapped.advanced(by: ω), 1,
                 1,
                 A.baseAddress.unsafelyUnwrapped, 1) // DFT
            vDSP.add(multiplication: (A[0..<ω], A[0..<ω]), multiplication: (A[ω..<m], A[ω..<m]), result: &A[0..<ω])
            vDSP.divide(confidence, A[0..<ω], result: &A[0..<ω])
            vForce.sqrt(A[0..<ω], result: &A[0..<ω])
            vDSP.clear(&A[ω..<m])
            //
            for k in 0..<count.b {
                let c = (1+k+0*count.b) * m + 0 ..< (1+k+0*count.b) * m + ω
                let s = (1+k+0*count.b) * m + ω ..< (1+k+0*count.b) * m + m
                vDSP.multiply(A[0..<ω], A[c], result: &A[c])
                vDSP.multiply(A[0..<ω], A[s], result: &A[s])
            }
            for k in 0..<count.a {
                let c = (1+k+1*count.b) * m + 0 ..< (1+k+1*count.b) * m + ω
                let s = (1+k+1*count.b) * m + ω ..< (1+k+1*count.b) * m + m
                vDSP.subtract(multiplication: (A[c], response.r), multiplication: (A[s], response.i), result: &w[0..<ω])
                vDSP.add(multiplication: (A[c], response.i), multiplication: (A[s], response.r), result: &w[ω..<m])
                vDSP.negative(w[0..<m], result: &w[0..<m])
                vDSP.multiply(A[0..<ω], w[0..<ω], result: &A[c])
                vDSP.multiply(A[0..<ω], w[ω..<m], result: &A[s])
            }
            vDSP.multiply(A[0..<ω], response.r, result: &b[0..<ω])
            vDSP.multiply(A[0..<ω], response.i, result: &b[ω..<m])
            let s = gels(m, n, 1,
                         A.baseAddress, m, .N,
                         b.baseAddress, b.count,
                         w.baseAddress, w.count)
            assert(0 == s)
            return.init(raw: (
                .init(b.prefix(1 + count.b)),
                .init(arrayLiteral: 1) + b.dropFirst(1 + count.b).prefix(count.a)
            ))
        }
    }
    @inlinable // [0, 2π) complex spectrum → (b, a) direct-form, frequency is normalized angular frequency [0, 2π) → [0, 1.0)
    public static func Fit(frequency: some AccelerateBuffer<Float64>,
                           response: some AccelerateBuffer<Complex128>,
                           confidence: some AccelerateBuffer<Float64>, // weight
                           count: (b: Int, a: Int)) -> Direct {
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * response.count) {
            let r = $0.extracting(0 * response.count ..< 1 * response.count)
            let i = $0.extracting(1 * response.count ..< 2 * response.count)
            response.withUnsafeBufferPointer {
                vDSP_ctoz($0.baseAddress.unsafelyUnwrapped.rawPointer, 1,
                          r.baseAddress.unsafelyUnwrapped, i.baseAddress.unsafelyUnwrapped, 1,
                          $0.count)
            }
            return Fit(frequency: frequency,
                       response: (r, i),
                       confidence: confidence,
                       count: count)
        }
    }
}
extension Linear {
    @inlinable // [0, π] power spectrum → (p, q) direct-form-power spectrum, the frequency should be normalized angular frequency [0, π] → [0, 0.5]
    static func Fit(frequency: some AccelerateBuffer<Float64>,
                    response: some AccelerateBuffer<Float64>, // power domain
                    confidence: some AccelerateBuffer<Float64>,
                    count: (p: Int, q: Int)) -> Direct.ChebyshevPowerRational {
        let m = frequency.count
        precondition(m == response.count)
        precondition(m == confidence.count)
        let n = 1 + count.p + count.q
        let l = gels(m, n, 1,
                     .none, m, .N,
                     .none, max(m, n),
                     .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        assert(2 * n <= l) // for wiener, it will be satisfied for n <= m standard gels, LWORK [min(m, n) + max(min(m, n), nrhs)]
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + max(m, n) + l) {
            let A = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let b = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(max(m, n)))
            let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + max(m, n)).prefix(l))
            // Basis
            for j in 0..<max(count.p, count.q) {
                vDSP.multiply(.init(-2*j-2), frequency, result: &A[0..<m])
                vForce.cosPi(A[0..<m], result: &A[0..<m])
                if j < count.p {
                    let v = (1+j+0*count.p) * m ..< (1+j+0*count.p) * m + m
                    switch A[v].update(fromContentsOf: A[0..<m]) {
                    case let eof:
                        assert(eof == A[v].endIndex)
                    }
                }
                if j < count.q {
                    let v = (1+j+1*count.p) * m ..< (1+j+1*count.p) * m + m
                    switch A[v].update(fromContentsOf: A[0..<m]) {
                    case let eof:
                        assert(eof == A[v].endIndex)
                    }
                }
            }
            // precondition by solving Yule-Walker
            switch response.withUnsafeBufferPointer(A.update(fromContentsOf:)) {
            case let eof:
                assert(A.startIndex.advanced(by: response.count) == eof)
            }
            b[0] = 1
            gemv(m, count.q,
                 1 / vDSP.sum(A[0..<m]),
                 A.baseAddress.unsafelyUnwrapped.advanced(by: m * count.p + m), m, .T,
                 A.baseAddress.unsafelyUnwrapped, 1,
                 0,
                 b.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1) // IDFT
            vDSP.negative(b[1..<1+count.q], result: &A[0..<0+count.q]) // RHS
            w[0] = 1
            wiener(b.baseAddress.unsafelyUnwrapped,
                   A.baseAddress.unsafelyUnwrapped,
                   w.baseAddress.unsafelyUnwrapped.advanced(by: 1),
                   w.baseAddress.unsafelyUnwrapped.advanced(by: n), // ignore performance score
                   count.q) // solve Yule-Walker
            // AR→Chebyshev Polynomial
            vDSP.clear(&w[1 + count.q ..< w.count])
            vDSP.correlate(w.prefix(count.q + 1 + count.q), withKernel: w.prefix(count.q + 1), result: &b[0..<count.q + 1])
            vDSP.fill(&A[0..<m], with: b[0])
            gemv(m, count.q,
                 2,
                 A.baseAddress.unsafelyUnwrapped.advanced(by: m * count.p + m), m, .N,
                 b.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1,
                 1,
                 A.baseAddress.unsafelyUnwrapped, 1) // DFT
            vForce.sqrt(confidence, result: &b[0..<m])
            vDSP.divide(b[0..<m], A[0..<m], result: &A[0..<m])
            //
            for k in 0..<count.p {
                let r = (1+k+0*count.p) * m + 0 ..< (1+k+0*count.p) * m + m
                vDSP.multiply(A[0..<m], A[r], result: &A[r])
            }
            for k in 0..<count.q {
                let r = (1+k+1*count.p) * m + 0 ..< (1+k+1*count.p) * m + m
                vDSP.multiply(A[0..<m], A[r], result: &A[r])
                vDSP.multiply(response, A[r], result: &A[r])
                vDSP.negative(A[r], result: &A[r])
            }
            vDSP.multiply(response, A[0..<m], result: &b[0..<m])
            let s = gels(m, n, 1,
                         A.baseAddress, m, .N,
                         b.baseAddress, b.count,
                         w.baseAddress, w.count)
            assert(0 == s)
            return.init(raw:(
                .init(b.prefix(1 + count.p)),
                .init(arrayLiteral: 1) + b.dropFirst(1 + count.p).prefix(count.q)
            ))
        }
    }
}
