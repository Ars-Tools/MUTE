//
//  Linear+Fit.swift
//  MUTE
//
//  Created by Kota on 9/7/26.
//
import typealias Numerics.Complex128
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func Accelerate.vDSP_mmovD
import func MKL.vDSP_fill
import func MKL.vDSP_copy
import func MKL.vDSP_add
import func BLAS.dot
import func BLAS.ger
import func BLAS.axpy
import func BLAS.copy
import func BLAS.trmv
import func BLAS.trmm
import func BLAS.gemv
import func BLAS.gemm
import func BLAS.syrk
import func LAPACK.potrf
import func LAPACK.potrs
import func LAPACK.potri
import func LAPACK.gels
import func LAPACK.geqrf
import func LAPACK.gesvd
import func LAPACK.gesvj
import func LAPACK.gglse
import func LAPACK.larf
import func LAPACK.larfg
import func Layout.concat
import typealias Dispatch.DispatchQueue
import simd
// MARK: Non-Linear Fit
extension Linear {
    public struct FitOption {
        let maxIteration: Int
        let tolerance: Float64
    }
    @inlinable@_transparent
    static func logsum(roots: Array<Complex128>,
                       frequency: some AccelerateBuffer<Float64>,
                       r: inout some AccelerateMutableBuffer<Float64>,
                       i: inout some AccelerateMutableBuffer<Float64>,
                       w: UnsafeMutableBufferPointer<Float64>/*workspace*/) {
        let N = frequency.count
        assert(8 * N <= w.count)
        let ηₛr = UnsafeMutableBufferPointer(rebasing: w[0*N..<1*N])
        let ηₛi = UnsafeMutableBufferPointer(rebasing: w[1*N..<2*N])
        let ηₜr = UnsafeMutableBufferPointer(rebasing: w[2*N..<3*N])
        let ηₜi = UnsafeMutableBufferPointer(rebasing: w[3*N..<4*N])
        let η₁r = UnsafeMutableBufferPointer(rebasing: w[4*N..<5*N])
        let η₁i = UnsafeMutableBufferPointer(rebasing: w[5*N..<6*N])
        let η₂r = UnsafeMutableBufferPointer(rebasing: w[6*N..<7*N])
        let η₂i = UnsafeMutableBufferPointer(rebasing: w[7*N..<8*N])
        vDSP.multiply(-2, frequency, result: &η₁i[0..<N])
        vForce.cosPi(η₁i, result: &η₁r[0..<N])
        vForce.sinPi(η₁i, result: &η₁i[0..<N])
        vDSP.multiply(-4, frequency, result: &η₂i[0..<N])
        vForce.cosPi(η₂i, result: &η₂r[0..<N])
        vForce.sinPi(η₂i, result: &η₂i[0..<N])
        for root in roots {
            let r₁ = -2 * root.real
            let r₂ = root.magnitudeSquared
            vDSP.add(multiplication: (η₁r, r₁),
                     multiplication: (η₂r, r₂),
                     result: &ηₜr[0..<N])
            vDSP.add(1, ηₜr[0..<N], result: &ηₜr[0..<N])
            vDSP.add(multiplication: (η₁i, r₁),
                     multiplication: (η₂i, r₂),
                     result: &ηₜi[0..<N])
            vDSP.add(multiplication: (ηₜr, ηₜr), multiplication: (ηₜi, ηₜi), result: &ηₛr[0..<N])
            vForce.log(ηₛr, result: &ηₛr[0..<N])
            vDSP.multiply(0.5, ηₛr, result: &ηₛr[0..<N])
            vDSP.add(r, ηₛr, result: &r)
            vForce.atan2(x: ηₜr, y: ηₜi, result: &ηₛi[0..<N])
            vDSP.add(i, ηₛi, result: &i)
        }
    }
    @inlinable@_transparent
    static func logsum(roots: Array<Float64>,
                       frequency: some AccelerateBuffer<Float64>,
                       r: inout some AccelerateMutableBuffer<Float64>,
                       i: inout some AccelerateMutableBuffer<Float64>,
                       w: UnsafeMutableBufferPointer<Float64>/*workspace*/) {
        let N = frequency.count
        assert(6 * N <= w.count)
        let ηₛr = UnsafeMutableBufferPointer(rebasing: w[0*N..<1*N])
        let ηₛi = UnsafeMutableBufferPointer(rebasing: w[1*N..<2*N])
        let ηₜr = UnsafeMutableBufferPointer(rebasing: w[2*N..<3*N])
        let ηₜi = UnsafeMutableBufferPointer(rebasing: w[3*N..<4*N])
        let η₁r = UnsafeMutableBufferPointer(rebasing: w[4*N..<5*N])
        let η₁i = UnsafeMutableBufferPointer(rebasing: w[5*N..<6*N])
        vDSP.multiply(-2, frequency, result: &η₁i[0..<N])
        vForce.cosPi(η₁i, result: &η₁r[0..<N])
        vForce.sinPi(η₁i, result: &η₁i[0..<N])
        for root in roots {
            let r₁ = -root
            vDSP.add(multiplication: (η₁r, r₁), 1, result: &ηₛr[0..<N])
            vDSP.multiply(r₁, η₁i, result: &ηₛi[0..<N])
            vDSP.add(multiplication: (ηₛr, ηₛr), multiplication: (ηₛi, ηₛi), result: &ηₜr[0..<N])
            vForce.log(ηₜr, result: &ηₜr[0..<N])
            vDSP.multiply(0.5, ηₜr, result: &ηₜr[0..<N])
            vDSP.add(r, ηₜr, result: &r)
            vForce.atan2(x: ηₛr, y: ηₛi, result: &ηₜi[0..<N])
            vDSP.add(i, ηₜi, result: &i)
        }
    }
    @inlinable
    public static func fit(x: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
                           y: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
                           frequency: some AccelerateBuffer<Float64>,
                           initial: Linear.ZPK,
                           regularization: borrowing (Linear.ZPK) -> some AccelerateBuffer<Float64>) {
        let N = frequency.count
        var result = initial
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: 12 * N) {
            let Xr = UnsafeMutableBufferPointer(rebasing: $0[0*N..<1*N]) // accum
            let Xi = UnsafeMutableBufferPointer(rebasing: $0[1*N..<2*N])
            let Yr = UnsafeMutableBufferPointer(rebasing: $0[2*N..<3*N])
            let Yi = UnsafeMutableBufferPointer(rebasing: $0[3*N..<4*N])
            let Zr = UnsafeMutableBufferPointer(rebasing: $0[4*N..<5*N]) // table
            let Zi = UnsafeMutableBufferPointer(rebasing: $0[5*N..<6*N])
            let Wr = UnsafeMutableBufferPointer(rebasing: $0[6*N..<7*N]) // workspace
            let Wi = UnsafeMutableBufferPointer(rebasing: $0[7*N..<8*N])
            vDSP.clear(&Xr[0..<N])
            vDSP.clear(&Xi[0..<N])
            vDSP.clear(&Yr[0..<N])
            vDSP.clear(&Yi[0..<N])
            logsum(roots: result.z.0, frequency: frequency, r: &Xr[0..<N], i: &Xi[0..<N], w: .init(rebasing: $0.dropFirst(4 * N)))
            logsum(roots: result.z.1, frequency: frequency, r: &Xr[0..<N], i: &Xi[0..<N], w: .init(rebasing: $0.dropFirst(4 * N)))
            logsum(roots: result.p.0, frequency: frequency, r: &Yr[0..<N], i: &Yi[0..<N], w: .init(rebasing: $0.dropFirst(4 * N)))
            logsum(roots: result.p.1, frequency: frequency, r: &Yr[0..<N], i: &Yi[0..<N], w: .init(rebasing: $0.dropFirst(4 * N)))
            vForce.exp(Xr, result: &Wr[0..<N])
            vForce.sincos(Xi, sinResult: &Xi[0..<N], cosResult: &Xr[0..<N])
            vDSP.multiply(Wr, Xr, result: &Xr[0..<N])
            vDSP.multiply(Wr, Xi, result: &Xi[0..<N])
            vForce.exp(Yr, result: &Wr[0..<N])
            vForce.sincos(Yi, sinResult: &Yi[0..<N], cosResult: &Yr[0..<N])
            vDSP.multiply(Wr, Yr, result: &Yr[0..<N])
            vDSP.multiply(Wr, Yi, result: &Yi[0..<N])
        }
        assertionFailure("WIP")
    }
}
// MARK: Complex Fit
extension Linear {
    @inlinable // J = Σ w[l] / (|X[l]|² + |Y[l]|²) * |A[l]Y[l] - B[l]X[l]|²
    public static func fit(x: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
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
        precondition(n <= m)
        let r = geqrf(m, n,
                      .none, m,
                      .none,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < r)
        let l = gesvj(n, n,
                      .none, m, .U,
                      .none,
                      0,
                      .init(bitPattern: ~0), n,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + n * n + min(m, n) + max(m, l, r)) {
            let M = $0.extracting(0..<m*n)
            let v = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(n * n))
            let s = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n).prefix(min(m, n)))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n + min(m, n)).prefix(max(m, l, r)))
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
            switch geqrf(m, n, M.baseAddress, m, s.baseAddress, z.baseAddress, z.count) {
            case 0:
                for (col, len) in repeatElement(min(m, n), count: n).enumerated() {
                    M[col*m+col+1..<col*m+len].update(repeating: .zero)
                }
            case let info:
                assertionFailure("geqrf ends with \(info)")
            }
            switch gesvj(n, n,
                         M.baseAddress, m, .U,
                         s.baseAddress,
                         0,
                         v.baseAddress, n,
                         z.baseAddress, z.count) {
            case 0:
                break
            case let info:
                assertionFailure("gesvj ends with \(info)")
            }
            return .init(raw: (
                .init(v.dropFirst(n * n - n + 0 + 0 * count.b).prefix(1 + count.b)),
                .init(v.dropFirst(n * n - n + 1 + 1 * count.b).prefix(1 + count.a))
            ))
        }
    }
    @inlinable // J = Σ_l w[l] * E[|A[l]Y[l] - B[l]X[l]|²] / (E[|X[l]|²] + E[|Y[l]|²])
    public static func fit(x: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
                           y: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
                           σxy: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>), /* c(ω) = E[(X-E[X])*(Y-E[Y])^H] */
                           frequency: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                           weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                           count: (b: Int, a: Int)) -> Direct {
        let ω = frequency.count
        precondition(ω == x.r.count)
        precondition(ω == x.i.count)
        precondition(ω == y.r.count)
        precondition(ω == y.i.count)
        precondition(ω == σxy.r.count)
        precondition(ω == σxy.i.count)
        precondition(ω == x.σ².count)
        precondition(ω == y.σ².count)
        precondition(ω == w.count)
        precondition(0 <= count.b)
        precondition(0 <= count.a)
        let m = 4 * ω
        let n = 2 + count.b + count.a
        precondition(n <= m)
        let r = geqrf(m, n,
                      .none, m,
                      .none,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < r)
        let l = gesvj(n, n,
                      .none, m, .U,
                      .none,
                      0,
                      .init(bitPattern: ~0), n,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + n * n + max(m, n) + max(m, l, r)) {
            let M = $0.extracting(0..<m*n)
            let v = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(n * n))
            let s = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n).prefix(max(m, n)))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n + max(m, n)).prefix(max(m, l, r)))
            let B = M.extracting((0 + 0 * count.b + 0 * count.a) * m ..< (1 + 1 * count.b + 0 * count.a) * m)
            let A = M.extracting((1 + 1 * count.b + 0 * count.a) * m ..< (2 + 1 * count.b + 1 * count.a) * m)
            // R
            vDSP.add(multiplication: (x.r, x.r), multiplication: (x.i, x.i), result: &s[0*ω..<1*ω])
            vDSP.add(x.σ², s[0*ω..<1*ω], result: &s[0*ω..<1*ω]) // E[XX]
            vDSP.add(multiplication: (y.r, y.r), multiplication: (y.i, y.i), result: &s[1*ω..<2*ω])
            vDSP.add(y.σ², s[1*ω..<2*ω], result: &s[1*ω..<2*ω]) // E[YY]
            vDSP.add(multiplication: (x.r, y.r), multiplication: (x.i, y.i), result: &s[2*ω..<3*ω])
            vDSP.add(σxy.r, s[2*ω..<3*ω], result: &s[2*ω..<3*ω]) // Re[E[XY^H]]
            vDSP.subtract(multiplication: (y.r, x.i), multiplication: (y.i, x.r), result: &s[3*ω..<4*ω])
            vDSP.add(σxy.i, s[3*ω..<4*ω], result: &s[3*ω..<4*ω]) // Im[E[XY^H]]
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
            switch geqrf(m, n, M.baseAddress, m, s.baseAddress, z.baseAddress, z.count) {
            case 0:
                for (col, len) in repeatElement(min(m, n), count: n).enumerated() {
                    M[col*m+col+1..<col*m+len].update(repeating: .zero)
                }
            case let info:
                assertionFailure("geqrf ends with \(info)")
            }
            switch gesvj(n, n,
                         M.baseAddress, m, .U,
                         s.baseAddress,
                         0,
                         v.baseAddress, n,
                         z.baseAddress, z.count) {
            case 0:
                break
            case let info:
                assertionFailure("gesvj ends with \(info)")
            }
            return .init(raw: (
                .init(v.dropFirst(n * n - n + 0 + 0 * count.b).prefix(1 + count.b)),
                .init(v.dropFirst(n * n - n + 1 + 1 * count.b).prefix(1 + count.a))
            ))
        }
    }
}
// MARK: Power Fit
extension Linear { // GGLSE
    @inlinable//@inline(__always)@_transparent // LS with constrains (internal sub-routine)
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
                    assert(Q.forced.count + Q.active.count <= p) // B/D capacity and dgglse rank precondition
                    a.withUnsafeBufferPointer {
                        vDSP_mmovD($0.baseAddress.unsafelyUnwrapped, A.baseAddress.unsafelyUnwrapped,
                                   .init(m), .init(n), .init(lda), .init(m))
                    }
                    switch c.withUnsafeBufferPointer(C.update(fromContentsOf:)) {
                    case let eof:
                        assert(eof == C.endIndex)
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
                        // wᵟ = 0 would poison the minimum with NaN/±∞
                        return χᵟ < $1.1 && wᵟ != 0 ?
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
                    switch c.withUnsafeBufferPointer(C.update(fromContentsOf:)) {
                    case let eof:
                        assert(eof == C.endIndex)
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
                    // near-parallel duplicates (minima pinned at the same location
                    // across iterations) make B rank-deficient for dgglse
                    let v = P(.init(χ)).filter { candidate in
                        let cc = dot(n, candidate.0, 1, candidate.0, 1)
                        return concat(Q.forced, concat(Q.active, Q.pended)).allSatisfy { existing in
                            let ce = dot(n, candidate.0, 1, existing.0, 1)
                            let ee = dot(n, existing.0, 1, existing.0, 1)
                            return ce * ce < (1 - 1e-9) * cc * ee
                        }
                    }
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
    @inlinable//@inline(__always)@_transparent // Power-LS, ε<P,Q constraint
    static func fit(rows m: Int, cols: (p: Int, q: Int),
                    A: some AccelerateBuffer<Float64>, ld ldA: Int,
                    iteration: Int,
                    minimum ε: Float64) -> Direct.Power {
        let (p, q) = cols
        assert(0 < m)
        assert(0 < p && 0 < q)
        assert(m <= ldA)
        let n = p + q
        assert(m + ldA * n - ldA <= A.count)
        let h = Array<Float64>(unsafeUninitializedCapacity: n + m) {
            $1 = $0.count
            vDSP.clear(&$0[0..<$1])
            $0[0] = 1
            $0[p] = 1
        }
        let s = fit(m: m, n: n,
                    a: A, lda: ldA,
                    c: h.suffix(m),
                    iteration: iteration,
                    initial: h.dropLast(m),
                    subject: Array(arrayLiteral: (h.dropLast(m), 2))) {
            [
                (Direct.ChebyshevPolynomial(.init($0.prefix(p))).minimum, 0..<p),
                (Direct.ChebyshevPolynomial(.init($0.suffix(q))).minimum, p..<n)
            ].compactMap { minimum, coefficients in
                minimum.value < ε ?
                    .some((.init(unsafeUninitializedCapacity: n) {
                        $1 = $0.count
                        vDSP.clear(&$0[0..<$1])
                        switch $0[coefficients].update(from: Direct.ChebyshevPolynomial.basis(at: minimum.location)).index {
                        case let eof:
                            assert(eof == $0[coefficients].endIndex)
                        }
                    }, ε)) : .none
            }
        }
        return.init(raw: (
            s.dropLast(q),
            .init(s.dropFirst(p))
        ))
    }
}
extension Linear {
    @usableFromInline
    static let sqrt2: Float64 = 2.squareRoot()
    @inlinable@inline(__always)@_transparent
    static func coefficients(_ K: UnsafeMutableBufferPointer<Float64>,
                             _ ε: Float64,
                             _ θ: UnsafeMutableBufferPointer<Float64>) {
        let n = θ.count
        assert(n * n <= K.count)
        vDSP.clear(&θ[0..<n])
        θ[0] = ε
        for col in 0..<n {
            θ[0] += K[col * n + col]
            for row in 0..<col {
                θ[0 + col - row] += 2 * K[col * n + row]
            }
        }
    }
    @inlinable@inline(__always)@_transparent
    static func adjoint(_ g: UnsafeMutableBufferPointer<Float64>,
                        _ C: UnsafeMutableBufferPointer<Float64>) {
        let n = g.count
        assert(n * n <= C.count)
        for col in 0..<n {
            for row in 0..<n {
                C[col * n + row] = g[abs(col - row)]
            }
        }
    }
    @inlinable@inline(__always)@_transparent
    static func logdet(n: Int,
                       a: UnsafeMutableBufferPointer<Float64>, ld lda: Int,
                       w: UnsafeMutableBufferPointer<Float64>, ld ldw: Int) -> Optional<Float64> {
        assert(0..<lda ~= n - 1)
        assert(0..<ldw ~= n - 1)
        assert(n * lda <= a.count)
        assert(n * ldw <= w.count)
        vDSP_copy(n, n,
                  a.baseAddress.unsafelyUnwrapped, lda,
                  w.baseAddress.unsafelyUnwrapped, ldw)
        switch potrf(n, w.baseAddress.unsafelyUnwrapped, ldw, .U) {
        case 0:
            let logdet = stride(from: 0, to: n * ldw, by: ldw + 1).reduce(0 as Float64) {
                fma(2, log(w[$1]), $0)
            }
            return logdet.isFinite ? .some(logdet) : .none
        case let info:
            assert(0 < info, "potrf: invalid argument \(info)")
            return.none
        }
    }
    @inlinable@inline(__always)@_transparent
    static func svec(n: Int,
                     a: UnsafeMutableBufferPointer<Float64>, lda: Int,
                     v: UnsafeMutableBufferPointer<Float64>) {
        assert(0..<lda ~= n - 1)
        assert(n * lda + n - lda <= a.count)
        assert(( n * n + n ) / 2 <= v.count)
//        DispatchQueue.concurrentPerform(iterations: n) { col in
        for col in 0..<n {
            if 0 < col {
                vDSP.multiply(sqrt2,
                              a[col*lda..<col*lda+col],
                              result: &v[col*(col+1)/2..<col*(col+1)/2+col])
            }
            v[col*(col+1)/2+col] = a[col*lda+col]
        }
    }
    @inlinable@inline(__always)@_transparent
    static func smat(n: Int, v: UnsafeMutableBufferPointer<Float64>,
                     a: UnsafeMutableBufferPointer<Float64>, lda: Int) {
        assert(0..<lda ~= n - 1)
        assert(( n * n + n ) / 2 <= v.count)
        assert(n * lda + n - lda <= a.count)
//        DispatchQueue.concurrentPerform(iterations: n) { col in
        for col in 0..<n {
            if 0 < col {
                vDSP.divide(v[col*(col+1)/2..<col*(col+1)/2+col],
                            sqrt2,
                            result: &a[col*lda..<col*lda+col])
                copy(col,
                     a.baseAddress.unsafelyUnwrapped.advanced(by: col * lda), 1,
                     a.baseAddress.unsafelyUnwrapped.advanced(by: col), lda)
            }
            a[col*lda+col] = v[col*(col+1)/2+col]
        }
    }
    @inlinable@inline(__always)@_transparent
    static func jacobian(m: Int, n: Int,
                         a: UnsafeMutableBufferPointer<Float64>, ld lda: Int,
                         j: UnsafeMutableBufferPointer<Float64>, ld ldj: Int) {
//        DispatchQueue.concurrentPerform(iterations: n) { col in
        for col in 0..<n {
            let idx = col * (col + 1) / 2
            for row in 0...col {
                let index = (idx + row) * ldj
                vDSP.multiply(row != col ? sqrt2 : 1,
                              a.dropFirst((col - row) * lda).prefix(m),
                              result: &j[index..<index + m])
            }
        }
    }
    @inlinable@inline(__always)@_transparent
    static func addBarrierHessian(n: Int, μ: Float64,
                                  K: UnsafeMutableBufferPointer<Float64>, ld ldK: Int,
                                  Β: UnsafeMutableBufferPointer<Float64>, ld ldΒ: Int) {
//        var a = 0
//        for j in 0..<n {
//            for i in 0...j {
//                let sa = i == j ? 1 : sqrt2
//                var b = 0
//                for l in 0..<n {
//                    for k in 0...l {
//                        if a <= b {
//                            let sb = l == k ? 1 : sqrt2
//                            let weight = dot(
//                                SIMD2<Float64>(K[k * ldK + i], K[l * ldK + i]),
//                                SIMD2<Float64>(K[l * ldK + j], K[k * ldK + j])
//                            )
//                            Β[b * ldΒ + a] += 0.5 * μ * sa * sb * weight
//                        }
//                        b += 1
//                    }
//                }
//                a += 1
//            }
//        }
        nonisolated(unsafe) let kp = K.baseAddress.unsafelyUnwrapped
        nonisolated(unsafe) let bp = Β.baseAddress.unsafelyUnwrapped
        DispatchQueue.concurrentPerform(iterations: n) { l in
            let firstB = l * (l + 1) / 2
            for k in 0...l {
                let b = firstB + k
                let sb = l == k ? 1 : sqrt2
                let factor = 0.5 * μ * sb * sqrt2
                for j in 0...l {
                    let end = j == l ? k + 1 : j + 1
                    let count = min(j, end)
                    let dest = bp.advanced(by: b * ldΒ + j * (j + 1) / 2)
                    // i < j：sa = √2
                    if 0 < count {
                        axpy(count,
                             factor * kp[l * ldK + j],
                             kp.advanced(by: k * ldK), 1,
                             dest, 1)
                        axpy(count,
                             factor * kp[k * ldK + j],
                             kp.advanced(by: l * ldK), 1,
                             dest, 1)
                    }
                    // i == j：sa = 1、weight = 2 K[j,k] K[j,l]
                    if j < end {
                        dest[j] += μ * sb * kp[k * ldK + j] * kp[l * ldK + j]
                    }
                }
            }
        }
    }
    @inlinable // SPD
    static func fit(m: Int, n count: (p: Int, q: Int),
                    a: UnsafeMutableBufferPointer<Float64>, lda: Int,
                    armijo: Float64 = 0.01,
                    iteration: Int = 42, // newton iteration
                    torelance: Float64 = 1e-8,
                    centering: Float64 = 0.01,
                    reduction: Float64 = 0.2,
                    minimum ε: Float64) ->  (coefficients: Array<Float64>, converged: Bool) {
        let (p, q) = count
        let n = p + q
        let dp = (p * p + p) / 2
        let dq = (q * q + q) / 2
        let d = dp + dq
        precondition(m > 0)
        precondition(p > 0 && q > 0)
        precondition(lda >= m)
        precondition(a.count >= (n - 1) * lda + m)
        precondition(ε.isFinite && 0 < ε && ε < 1)
        precondition(iteration >= 0)
        let p² = switch p.multipliedReportingOverflow(by: p) {
        case (let square, false):
            square
        default:
            preconditionFailure()
        }
        let q² = switch q.multipliedReportingOverflow(by: q) {
        case (let square, false):
            square
        default:
            preconditionFailure()
        }
        let M² = p² + q²
        let k = d - 1
        let rank = min(m, k)
        let l = gesvd(m, k,
                      .none, m,
                      .none,
                      .init(bitPattern: ~0), m,
                      .init(bitPattern: ~0), rank,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: 4 * M² + 2 * n + 4 * d + m * d + m * rank + rank * k + rank + l + 2 * m) {
            let (Gₘ, Hₘ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(0 * M²).prefix(M²)) {
            case let M: (
                UnsafeMutableBufferPointer(rebasing: M.prefix(p²)),
                UnsafeMutableBufferPointer(rebasing: M.suffix(q²))
            )}
            let (Gᵧ, Hᵧ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(1 * M²).prefix(M²)) {
            case let C: (
                UnsafeMutableBufferPointer(rebasing: C.prefix(p²)),
                UnsafeMutableBufferPointer(rebasing: C.suffix(q²))
            )}
            let (Gₗ, Hₗ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(2 * M²).prefix(M²)) {
            case let L: (
                UnsafeMutableBufferPointer(rebasing: L.prefix(p²)),
                UnsafeMutableBufferPointer(rebasing: L.suffix(q²))
            )}
            let (Gᵢ, Hᵢ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(3 * M²).prefix(M²)) {
            case let L: (
                UnsafeMutableBufferPointer(rebasing: L.prefix(p²)),
                UnsafeMutableBufferPointer(rebasing: L.suffix(q²))
            )}
            let (θ, g) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M²).prefix(2 * n)) {
            case let W: (
                UnsafeMutableBufferPointer(rebasing: W.prefix(n)),
                UnsafeMutableBufferPointer(rebasing: W.suffix(n))
            )}
            let (v, e, u, w) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M² + 2 * n).prefix(4 * d)) {
            case let D: (
                UnsafeMutableBufferPointer(rebasing: D[0*d..<1*d]),
                UnsafeMutableBufferPointer(rebasing: D[1*d..<2*d]),
                UnsafeMutableBufferPointer(rebasing: D[2*d..<3*d]),
                UnsafeMutableBufferPointer(rebasing: D[3*d..<4*d])
            )}
            let j = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M² + 2 * n + 4 * d).prefix(m * d))
            let (S, U, V, ρ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M² + 2 * n + 4 * d + m * d).prefix(m * rank + rank * k + rank + l)) {
            case let SVD: (
                UnsafeMutableBufferPointer(rebasing: SVD.prefix(rank)),
                UnsafeMutableBufferPointer(rebasing: SVD.dropFirst(rank).prefix(m * rank)),
                UnsafeMutableBufferPointer(rebasing: SVD.dropFirst(rank).dropFirst(m * rank).prefix(rank * k)),
                UnsafeMutableBufferPointer(rebasing: SVD.suffix(l)),
            )}
            let (r, τ) = switch UnsafeMutableBufferPointer(rebasing: $0.suffix(2 * m)) {
            case let R: (
                UnsafeMutableBufferPointer(rebasing: R.prefix(m)),
                UnsafeMutableBufferPointer(rebasing: R.suffix(m))
            )}
            vDSP.clear(&Gₘ[0..<p²])
            vDSP_fill((1 - ε) / .init(p), Gₘ.baseAddress.unsafelyUnwrapped, p + 1, p)
            vDSP.clear(&Hₘ[0..<q²])
            vDSP_fill((1 - ε) / .init(q), Hₘ.baseAddress.unsafelyUnwrapped, q + 1, q)
            var μ = 1 as Float64
            var finished = false
            path: while !finished, (μ * μ).isNormal {
                var centered = false
                newton: for () in repeatElement((), count: iteration) {
                    coefficients(Gₘ, ε, .init(rebasing: θ.prefix(p)))
                    coefficients(Hₘ, ε, .init(rebasing: θ.suffix(q)))
                    gemv(m, n,
                         1,
                         a.baseAddress.unsafelyUnwrapped, lda, .N,
                         θ.baseAddress.unsafelyUnwrapped, 1,
                         0,
                         r.baseAddress.unsafelyUnwrapped, 1)
                    gemv(m, n,
                         1,
                         a.baseAddress.unsafelyUnwrapped, lda, .T,
                         r.baseAddress.unsafelyUnwrapped, 1,
                         0,
                         g.baseAddress.unsafelyUnwrapped, 1)
                    adjoint(.init(rebasing: g.prefix(p)), Gᵧ)
                    adjoint(.init(rebasing: g.suffix(q)), Hᵧ)
                    guard case.some(let logdetG) = logdet(n: p, a: Gₘ, ld: p, w: Gₗ, ld: p),
                          case.some(let logdetH) = logdet(n: q, a: Hₘ, ld: q, w: Hₗ, ld: q) else {
                        assertionFailure("Initial Gram matrices must be positive definite")
                        break path;
                    }
                    let objective = 0.5 * vDSP.sumOfSquares(r)
                    // Gᵧ ← Gₗ Gᵧ Gₗᵀ
                    trmm(p, p, 1,
                         Gₗ.baseAddress.unsafelyUnwrapped, p, .N, .U, .N, .L,
                         Gᵧ.baseAddress.unsafelyUnwrapped, p)
                    trmm(p, p, 1,
                         Gₗ.baseAddress.unsafelyUnwrapped, p, .T, .U, .N, .R,
                         Gᵧ.baseAddress.unsafelyUnwrapped, p)
                    // Hᵧ ← Hₗ Hᵧ Hₗᵀ
                    trmm(q, q, 1,
                         Hₗ.baseAddress.unsafelyUnwrapped, q, .N, .U, .N, .L,
                         Hᵧ.baseAddress.unsafelyUnwrapped, q)
                    trmm(q, q, 1,
                         Hₗ.baseAddress.unsafelyUnwrapped, q, .T, .U, .N, .R,
                         Hᵧ.baseAddress.unsafelyUnwrapped, q)
                    vDSP_add(Gᵧ.baseAddress.unsafelyUnwrapped, p + 1, -μ,
                             Gᵧ.baseAddress.unsafelyUnwrapped, p + 1, p)
                    vDSP_add(Hᵧ.baseAddress.unsafelyUnwrapped, q + 1, -μ,
                             Hᵧ.baseAddress.unsafelyUnwrapped, q + 1, q)
                    let barrierObjective = fma(-μ, logdetG + logdetH, objective)
                    svec(n: p, a: Gᵧ, lda: p, v: .init(rebasing: v.prefix(dp)))
                    svec(n: q, a: Hᵧ, lda: q, v: .init(rebasing: v.suffix(dq)))
                    // Gᵢ ← I → Gₗ Gₗᵀ
                    vDSP.clear(&Gᵢ[0..<p²])
                    vDSP_fill(1, Gᵢ.baseAddress.unsafelyUnwrapped, p + 1, p)
                    trmm(p, p, 1,
                         Gₗ.baseAddress.unsafelyUnwrapped, p, .N, .U, .N, .L,
                         Gᵢ.baseAddress.unsafelyUnwrapped, p)
                    trmm(p, p, 1,
                         Gₗ.baseAddress.unsafelyUnwrapped, p, .T, .U, .N, .R,
                         Gᵢ.baseAddress.unsafelyUnwrapped, p)
                    
                    // Hᵢ ← I → Hₗ Hₗᵀ
                    vDSP.clear(&Hᵢ[0..<q²])
                    vDSP_fill(1, Hᵢ.baseAddress.unsafelyUnwrapped, q + 1, q)
                    trmm(q, q, 1,
                         Hₗ.baseAddress.unsafelyUnwrapped, q, .N, .U, .N, .L,
                         Hᵢ.baseAddress.unsafelyUnwrapped, q)
                    trmm(q, q, 1,
                         Hₗ.baseAddress.unsafelyUnwrapped, q, .T, .U, .N, .R,
                         Hᵢ.baseAddress.unsafelyUnwrapped, q)
                    
                    svec(n: p, a: Gᵢ, lda: p,
                         v: .init(rebasing: e.prefix(dp)))
                    svec(n: q, a: Hᵢ, lda: q,
                         v: .init(rebasing: e.suffix(dq)))
                    for row in 0..<m {
                        // 縮後の入力行列 a の1行を取り出す
                        copy(n,
                             a.baseAddress.unsafelyUnwrapped.advanced(by: row), lda,
                             g.baseAddress.unsafelyUnwrapped, 1)
                        
                        adjoint(.init(rebasing: g.prefix(p)), Gᵢ)
                        adjoint(.init(rebasing: g.suffix(q)), Hᵢ)
                        
                        // Gᵢ ← Gₗ Gᵢ Gₗᵀ
                        trmm(p, p, 1,
                             Gₗ.baseAddress.unsafelyUnwrapped, p, .N, .U, .N, .L,
                             Gᵢ.baseAddress.unsafelyUnwrapped, p)
                        trmm(p, p, 1,
                             Gₗ.baseAddress.unsafelyUnwrapped, p, .T, .U, .N, .R,
                             Gᵢ.baseAddress.unsafelyUnwrapped, p)
                        
                        // Hᵢ ← Hₗ Hᵢ Hₗᵀ
                        trmm(q, q, 1,
                             Hₗ.baseAddress.unsafelyUnwrapped, q, .N, .U, .N, .L,
                             Hᵢ.baseAddress.unsafelyUnwrapped, q)
                        trmm(q, q, 1,
                             Hₗ.baseAddress.unsafelyUnwrapped, q, .T, .U, .N, .R,
                             Hᵢ.baseAddress.unsafelyUnwrapped, q)
                        
                        svec(n: p, a: Gᵢ, lda: p,
                             v: .init(rebasing: u.prefix(dp)))
                        svec(n: q, a: Hᵢ, lda: q,
                             v: .init(rebasing: u.suffix(dq)))
                        
                        // j の1行へ格納。列優先なので行の stride は m
                        copy(d,
                             u.baseAddress.unsafelyUnwrapped, 1,
                             j.baseAddress.unsafelyUnwrapped.advanced(by: row), m)
                    }
                    switch w.update(fromContentsOf: e) {
                    case let eof:
                        assert(w.startIndex.distance(to: eof) == e.count)
                    }
                    let ψ = larfg(
                        d, w[0], 0,
                        w.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1
                    ).y
                    w[0] = 1
                    
                    // j ← j T
                    larf(m, d,
                         w.baseAddress.unsafelyUnwrapped, 1, .R,
                         ψ,
                         j.baseAddress.unsafelyUnwrapped, m,
                         τ.baseAddress)
                    guard gesvd(m, k,
                                j.baseAddress.unsafelyUnwrapped.advanced(by: m), m,
                                S.baseAddress,
                                U.baseAddress, m,
                                V.baseAddress, rank,
                                ρ.baseAddress, ρ.count
                    ) == 0 else {
                        assertionFailure("gesvd failed")
                        break path
                    }
                    // e ← svec(I, I)
                    vDSP.clear(&Gᵢ[0..<p²])
                    vDSP_fill(1, Gᵢ.baseAddress.unsafelyUnwrapped, p + 1, p)
                    vDSP.clear(&Hᵢ[0..<q²])
                    vDSP_fill(1, Hᵢ.baseAddress.unsafelyUnwrapped, q + 1, q)

                    svec(n: p, a: Gᵢ, lda: p,
                         v: .init(rebasing: e.prefix(dp)))
                    svec(n: q, a: Hᵢ, lda: q,
                         v: .init(rebasing: e.suffix(dq)))

                    // e ← T e
                    larf(d, 1,
                         w.baseAddress.unsafelyUnwrapped, 1, .L,
                         ψ,
                         e.baseAddress.unsafelyUnwrapped, d,
                         τ.baseAddress)

                    // ρ の先頭 rank 要素 ← Uᵀr
                    gemv(m, rank, 1,
                         U.baseAddress.unsafelyUnwrapped, m, .T,
                         r.baseAddress.unsafelyUnwrapped, 1,
                         0, ρ.baseAddress.unsafelyUnwrapped, 1)

                    // τ の先頭 rank 要素 ← VT e[1...]
                    gemv(rank, k, 1,
                         V.baseAddress.unsafelyUnwrapped, rank, .N,
                         e.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1,
                         0, τ.baseAddress.unsafelyUnwrapped, 1)
                    // τ ← −S * (ρ + S * τ) / (μ + S²)
                    vDSP.add(multiplication: (S, τ[0..<rank]), ρ[0..<rank],
                             result: &τ[0..<rank])
                    vDSP.multiply(S, τ[0..<rank], result: &τ[0..<rank])
                    vDSP.negative(τ[0..<rank], result: &τ[0..<rank])

                    vDSP.multiply(S, S, result: &ρ[0..<rank])
                    vDSP.add(μ, ρ[0..<rank], result: &ρ[0..<rank])
                    vDSP.divide(τ[0..<rank], ρ[0..<rank],
                                result: &τ[0..<rank])

                    // u ← [0; e[1...] + V a]
                    u[0] = 0
                    switch u.dropFirst().update(fromContentsOf: e.dropFirst()) {
                    case let eof:
                        assert(eof == u.endIndex)
                    }

                    gemv(rank, k, 1,
                         V.baseAddress.unsafelyUnwrapped, rank, .T,
                         τ.baseAddress.unsafelyUnwrapped, 1,
                         1, u.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1)
                    
                    // τ ← VT u[1...]
                    gemv(rank, k, 1,
                         V.baseAddress.unsafelyUnwrapped, rank, .N,
                         u.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1,
                         0, τ.baseAddress.unsafelyUnwrapped, 1)

                    // ||C u[1...]||² = ||Σ VT u[1...]||²
                    vDSP.multiply(S, τ[0..<rank], result: &τ[0..<rank])

                    let decrementSquared = fma(μ, vDSP.sumOfSquares(u), vDSP.sumOfSquares(τ[0..<rank]))
                    guard decrementSquared.isFinite else {
                        break path
                    }
                    
                    // u ← T u：反射前の whitened 座標へ戻す
                    larf(d, 1,
                         w.baseAddress.unsafelyUnwrapped, 1, .L,
                         ψ,
                         u.baseAddress.unsafelyUnwrapped, d,
                         ρ.baseAddress)
                    
                    let slope = vDSP.dot(u, v)
                    assert(slope.isFinite)

                    // whitened 方向を対称行列へ
                    smat(n: p, v: .init(rebasing: u.prefix(dp)), a: Gᵧ, lda: p)
                    smat(n: q, v: .init(rebasing: u.suffix(dq)), a: Hᵧ, lda: q)

                    // ΔG ← Gₗᵀ S_G Gₗ
                    trmm(p, p, 1,
                         Gₗ.baseAddress.unsafelyUnwrapped, p, .N, .U, .N, .R,
                         Gᵧ.baseAddress.unsafelyUnwrapped, p)
                    trmm(p, p, 1,
                         Gₗ.baseAddress.unsafelyUnwrapped, p, .T, .U, .N, .L,
                         Gᵧ.baseAddress.unsafelyUnwrapped, p)

                    // ΔH ← Hₗᵀ S_H Hₗ
                    trmm(q, q, 1,
                         Hₗ.baseAddress.unsafelyUnwrapped, q, .N, .U, .N, .R,
                         Hᵧ.baseAddress.unsafelyUnwrapped, q)
                    trmm(q, q, 1,
                         Hₗ.baseAddress.unsafelyUnwrapped, q, .T, .U, .N, .L,
                         Hᵧ.baseAddress.unsafelyUnwrapped, q)
                    
                    if 0.5 * decrementSquared <= min(μ * centering, torelance * max(1, objective, μ * .init(n))) {
                        centered = true
                        break newton
                    }
                    assert(slope < 0)
                    var α = 1 as Float64
                    var accepted = slope == 0
                    linesearch: while !accepted, (α * α).isNormal {
                        vDSP.add(multiplication: (Gᵧ, α), Gₘ,
                                 result: &Gᵢ[0..<p²])
                        vDSP.add(multiplication: (Hᵧ, α), Hₘ,
                                 result: &Hᵢ[0..<q²])
                        guard case.some(let testLogdetG) = logdet(n: p, a: Gᵢ, ld: p, w: Gₗ, ld: p),
                              case.some(let testLogdetH) = logdet(n: q, a: Hᵢ, ld: q, w: Hₗ, ld: q) else {
                            α *= 0.5
                            continue linesearch
                        }
                        coefficients(Gᵢ, ε, .init(rebasing: θ.prefix(p)))
                        coefficients(Hᵢ, ε, .init(rebasing: θ.suffix(q)))
                        gemv(m, n,
                             1,
                             a.baseAddress.unsafelyUnwrapped, lda, .N,
                             θ.baseAddress.unsafelyUnwrapped, 1,
                             0,
                             r.baseAddress.unsafelyUnwrapped, 1)
                        let testObjective = fma(-μ, testLogdetG + testLogdetH, 0.5 * vDSP.sumOfSquares(r))
                        if testObjective.isFinite, testObjective <= fma(α * armijo, slope, barrierObjective) {
                            switch Gₘ.update(fromContentsOf: Gᵢ) {
                            case let eof:
                                assert(Gₘ.startIndex.distance(to: eof) == Gᵢ.count)
                            }
                            switch Hₘ.update(fromContentsOf: Hᵢ) {
                            case let eof:
                                assert(Hₘ.startIndex.distance(to: eof) == Hᵢ.count)
                            }
                            accepted = true
                            break linesearch
                        }
                        α *= 0.5
                    } // end of line-search
                    assert(accepted, "Line search failed")
                }
                guard centered else { break path }
                if μ * .init(n) <= torelance * max(1, 0.5 * vDSP.sumOfSquares(r)) {
                    finished = true
                    break path
                } // end of newton
                μ *= reduction
            } // end of path
            coefficients(Gₘ, ε, .init(rebasing: θ.prefix(p)))
            coefficients(Hₘ, ε, .init(rebasing: θ.suffix(q)))
            return (coefficients: .init(θ), converged: finished)
        }
    }
    @inlinable // SPD v1
    static func fit_v1(m: Int, n count: (p: Int, q: Int),
                    a: UnsafeMutableBufferPointer<Float64>, lda: Int,
                    armijo: Float64 = 0.01,
                    iteration: Int = 42, // newton iteration
                    torelance: Float64 = 1e-8,
                    centering: Float64 = 0.01,
                    reduction: Float64 = 0.2,
                    minimum ε: Float64) ->  (coefficients: Array<Float64>, converged: Bool) {
        let (p, q) = count
        let n = p + q
        let dp = (p * p + p) / 2
        let dq = (q * q + q) / 2
        let d = dp + dq
        precondition(m > 0)
        precondition(p > 0 && q > 0)
        precondition(lda >= m)
        precondition(a.count >= (n - 1) * lda + m)
        precondition(ε.isFinite && 0 < ε && ε < 1)
        precondition(iteration >= 0)
        let p² = switch p.multipliedReportingOverflow(by: p) {
        case (let square, false):
            square
        default:
            preconditionFailure()
        }
        let q² = switch q.multipliedReportingOverflow(by: q) {
        case (let square, false):
            square
        default:
            preconditionFailure()
        }
        let M² = p² + q²
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: 4 * M² + 2 * n + 4 * d + m * d + d * d + m) {
            let (Gₘ, Hₘ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(0 * M²).prefix(M²)) {
            case let M: (
                UnsafeMutableBufferPointer(rebasing: M.prefix(p²)),
                UnsafeMutableBufferPointer(rebasing: M.suffix(q²))
            )}
            let (Gᵧ, Hᵧ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(1 * M²).prefix(M²)) {
            case let C: (
                UnsafeMutableBufferPointer(rebasing: C.prefix(p²)),
                UnsafeMutableBufferPointer(rebasing: C.suffix(q²))
            )}
            let (Gₗ, Hₗ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(2 * M²).prefix(M²)) {
            case let L: (
                UnsafeMutableBufferPointer(rebasing: L.prefix(p²)),
                UnsafeMutableBufferPointer(rebasing: L.suffix(q²))
            )}
            let (Gᵢ, Hᵢ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(3 * M²).prefix(M²)) {
            case let L: (
                UnsafeMutableBufferPointer(rebasing: L.prefix(p²)),
                UnsafeMutableBufferPointer(rebasing: L.suffix(q²))
            )}
            let (θ, g) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M²).prefix(2 * n)) {
            case let W: (
                UnsafeMutableBufferPointer(rebasing: W.prefix(n)),
                UnsafeMutableBufferPointer(rebasing: W.suffix(n))
            )}
            let (v, e, u, w) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M² + 2 * n).prefix(4 * d)) {
            case let D: (
                UnsafeMutableBufferPointer(rebasing: D[0*d..<1*d]),
                UnsafeMutableBufferPointer(rebasing: D[1*d..<2*d]),
                UnsafeMutableBufferPointer(rebasing: D[2*d..<3*d]),
                UnsafeMutableBufferPointer(rebasing: D[3*d..<4*d])
            )}
            let j = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M² + 2 * n + 4 * d).prefix(m * d))
            let β = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M² + 2 * n + 4 * d + m * d).prefix(d * d))
            let r = UnsafeMutableBufferPointer(rebasing: $0.suffix(m))
            vDSP.clear(&Gₘ[0..<p²])
            vDSP_fill((1 - ε) / .init(p), Gₘ.baseAddress.unsafelyUnwrapped, p + 1, p)
            vDSP.clear(&Hₘ[0..<q²])
            vDSP_fill((1 - ε) / .init(q), Hₘ.baseAddress.unsafelyUnwrapped, q + 1, q)
            vDSP.clear(&e[0..<d])
            switch (
                UnsafeMutableBufferPointer(rebasing: e.prefix(dp)),
                UnsafeMutableBufferPointer(rebasing: e.suffix(dq))
            ) {
            case (let ep, let eq):
                for col in 0..<p {
                    ep[col * (col + 1) / 2 + col] = 1
                }
                for col in 0..<q {
                    eq[col * (col + 1) / 2 + col] = 1
                }
            }
            jacobian(m: m, n: p,
                     a: .init(rebasing: a.dropFirst(0 * lda)), ld: lda,
                     j: .init(rebasing: j.dropFirst( 0 * m)), ld: m)
            jacobian(m: m, n: q,
                     a: .init(rebasing: a.dropFirst(p * lda)), ld: lda,
                     j: .init(rebasing: j.dropFirst(dp * m)), ld: m)
            var μ = 1 as Float64
            var finished = false
            path: while !finished, (μ * μ).isNormal {
                var centered = false
                newton: for () in repeatElement((), count: iteration) {
                    coefficients(Gₘ, ε, .init(rebasing: θ.prefix(p)))
                    coefficients(Hₘ, ε, .init(rebasing: θ.suffix(q)))
                    gemv(m, n,
                         1,
                         a.baseAddress.unsafelyUnwrapped, lda, .N,
                         θ.baseAddress.unsafelyUnwrapped, 1,
                         0,
                         r.baseAddress.unsafelyUnwrapped, 1)
                    let objective = 0.5 * vDSP.sumOfSquares(r)
                    gemv(m, n,
                         1,
                         a.baseAddress.unsafelyUnwrapped, lda, .T,
                         r.baseAddress.unsafelyUnwrapped, 1,
                         0,
                         g.baseAddress.unsafelyUnwrapped, 1)
                    adjoint(.init(rebasing: g.prefix(p)), Gᵧ)
                    adjoint(.init(rebasing: g.suffix(q)), Hᵧ)
                    guard case.some(let logdetG) = logdet(n: p, a: Gₘ, ld: p, w: Gₗ, ld: p),
                          case.some(let logdetH) = logdet(n: q, a: Hₘ, ld: q, w: Hₗ, ld: q) else {
                        assertionFailure("Initial Gram matrices must be positive definite")
                        break path;
                    }
                    vDSP_copy(p, p,
                              Gₗ.baseAddress.unsafelyUnwrapped, p,
                              Gᵢ.baseAddress.unsafelyUnwrapped, p)
                    switch potri(p, Gᵢ.baseAddress.unsafelyUnwrapped, p, .U) {
                    case let info:
                        assert(info == 0, "potri failed \(info) for G")
                    }
                    for col in 1..<p {
                        copy(col,
                             Gᵢ.baseAddress.unsafelyUnwrapped.advanced(by: col * p), 1,
                             Gᵢ.baseAddress.unsafelyUnwrapped.advanced(by: col), p)
                    }
                    vDSP_copy(q, q,
                              Hₗ.baseAddress.unsafelyUnwrapped, q,
                              Hᵢ.baseAddress.unsafelyUnwrapped, q)
                    switch potri(q, Hᵢ.baseAddress.unsafelyUnwrapped, q, .U) {
                    case let info:
                        assert(info == 0, "potri failed \(info) for H")
                    }
                    for col in 1..<q {
                        copy(col,
                             Hᵢ.baseAddress.unsafelyUnwrapped.advanced(by: col * q), 1,
                             Hᵢ.baseAddress.unsafelyUnwrapped.advanced(by: col), q)
                    }
                    let barrierObjective = fma(-μ, logdetG + logdetH, objective)
                    vDSP.add(multiplication: (Gᵢ, -μ), Gᵧ, result: &Gᵧ[0..<p²])
                    vDSP.add(multiplication: (Hᵢ, -μ), Hᵧ, result: &Hᵧ[0..<q²])
                    svec(n: p, a: Gᵧ, lda: p, v: .init(rebasing: v.prefix(dp)))
                    svec(n: q, a: Hᵧ, lda: q, v: .init(rebasing: v.suffix(dq)))
                    switch u.update(fromContentsOf: v) {
                    case let eof:
                        assert(u.startIndex.distance(to: eof) == v.count)
                    }
                    switch w.update(fromContentsOf: e) {
                    case let eof:
                        assert(w.startIndex.distance(to: eof) == e.count)
                    }
                    syrk(d, m,
                         1,
                         j.baseAddress.unsafelyUnwrapped, m, .T,
                         0,
                         β.baseAddress.unsafelyUnwrapped, d, .U)
                    addBarrierHessian(n: p, μ: μ, K: Gᵢ, ld: p, Β: β, ld: d)
                    addBarrierHessian(n: q, μ: μ, K: Hᵢ, ld: q, Β: .init(rebasing: β.dropFirst(dp * d + dp)), ld: d)
                    switch potrf(d, β.baseAddress.unsafelyUnwrapped, d, .U) {
                    case let info:
                        assert(info == 0, "potrf failed \(info) for β")
                    }
                    switch potrs(d, 2, β.baseAddress.unsafelyUnwrapped, d, .U, u.baseAddress.unsafelyUnwrapped, d) {
                    case let info:
                        assert(info == 0, "potrs failed \(info) for β and rhs")
                    }
                    let eu = dot(d,
                                 e.baseAddress.unsafelyUnwrapped, 1,
                                 u.baseAddress.unsafelyUnwrapped, 1)
                    let ew = dot(d,
                                 e.baseAddress.unsafelyUnwrapped, 1,
                                 w.baseAddress.unsafelyUnwrapped, 1)
                    assert(eu.isFinite)
                    assert(ew.isFinite && 0 < ew)
                    vDSP.add(multiplication: (w, eu / ew), multiplication: (u, -1), result: &u[0..<d])
                    smat(n: p, v: .init(rebasing: u.prefix(dp)), a: Gᵧ, lda: p)
                    smat(n: q, v: .init(rebasing: u.suffix(dq)), a: Hᵧ, lda: q)
                    let slope = dot(d,
                                    v.baseAddress.unsafelyUnwrapped, 1,
                                    u.baseAddress.unsafelyUnwrapped, 1)
                    assert(slope.isFinite)
                    switch w.update(fromContentsOf: u) {
                    case let eof:
                        assert(w.startIndex.distance(to: eof) == u.count)
                    }
                    trmv(d,
                         β.baseAddress.unsafelyUnwrapped, d, .N, .U, .N,
                         w.baseAddress.unsafelyUnwrapped, 1)
                    let decrementSquared = vDSP.sumOfSquares(w)
                    assert(decrementSquared.isFinite)
                    let scale = max(1, objective, μ * .init(n))
                    let threshold = min(torelance * scale, μ * centering)
                    if 0.5 * decrementSquared <= threshold {
                        centered = true
                        break newton
                    }
                    assert(slope < 0)
                    var α = 1.0
                    var accepted = slope == 0
                    linesearch: while !accepted, (α * α).isNormal {
                        vDSP.add(multiplication: (Gᵧ, α), Gₘ,
                                 result: &Gᵢ[0..<p²])
                        vDSP.add(multiplication: (Hᵧ, α), Hₘ,
                                 result: &Hᵢ[0..<q²])
                        guard case.some(let testLogdetG) = logdet(n: p, a: Gᵢ, ld: p, w: Gₗ, ld: p),
                              case.some(let testLogdetH) = logdet(n: q, a: Hᵢ, ld: q, w: Hₗ, ld: q) else {
                            α *= 0.5
                            continue linesearch
                        }
                        coefficients(Gᵢ, ε, .init(rebasing: θ.prefix(p)))
                        coefficients(Hᵢ, ε, .init(rebasing: θ.suffix(q)))
                        gemv(m, n,
                             1,
                             a.baseAddress.unsafelyUnwrapped, lda, .N,
                             θ.baseAddress.unsafelyUnwrapped, 1,
                             0,
                             r.baseAddress.unsafelyUnwrapped, 1)
                        let testObjective = fma(-μ, testLogdetG + testLogdetH, 0.5 * vDSP.sumOfSquares(r))
                        if testObjective.isFinite, testObjective <= fma(α * armijo, slope, barrierObjective) {
                            switch Gₘ.update(fromContentsOf: Gᵢ) {
                            case let eof:
                                assert(Gₘ.startIndex.distance(to: eof) == Gᵢ.count)
                            }
                            switch Hₘ.update(fromContentsOf: Hᵢ) {
                            case let eof:
                                assert(Hₘ.startIndex.distance(to: eof) == Hᵢ.count)
                            }
                            accepted = true
                            break linesearch
                        }
                        α *= 0.5
                    } // end of line-search
                    assert(accepted, "Line search failed")
                }
                guard centered else { break path }
                let objective = 0.5 * vDSP.sumOfSquares(r)
                let scale = max(1, objective)
                if μ * .init(n) <= torelance * scale {
                    finished = true
                    break path
                } // end of newton
                μ *= reduction
            } // end of path
            coefficients(Gₘ, ε, .init(rebasing: θ.prefix(p)))
            coefficients(Hₘ, ε, .init(rebasing: θ.suffix(q)))
            return (coefficients: .init(θ), converged: finished)
        }
    }
}
extension Linear {
//    @inlinable // Power LS (SVD)
//    static func fit(X x: some AccelerateBuffer<Float64>, /* XX */
//                    Y y: some AccelerateBuffer<Float64>, /* YY */
//                    frequency ω: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
//                    weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
//                    count: (b: Int, a: Int)) -> Direct.ChebyshevPowerRational {
//        let m = ω.count
//        precondition(m == x.count)
//        precondition(m == y.count)
//        precondition(m == w.count)
//        precondition(0 <= count.b)
//        precondition(0 <= count.a)
//        let n = 2 + count.b + count.a
//        let l = gesvd(m, n,
//                      .none, m,
//                      .none,
//                      .none, m,
//                      .init(bitPattern: ~0), n,
//                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
//        assert(0 < l)
//        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + n * n + max(m, n) + max(m, l)) {
//            let M = $0.extracting(0..<m*n)
//            let B = UnsafeMutableBufferPointer(rebasing: M.prefix(m * (1 + count.b)))
//            let A = UnsafeMutableBufferPointer(rebasing: M.suffix(m * (1 + count.a)))
//            let v = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(n * n))
//            let s = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n).prefix(max(m, n)))
//            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n * n + max(m, n)).prefix(max(m, l)))
//            // weight
//            vForce.sqrt(w, result: &z[0..<m])
//            // b0
//            vDSP.multiply(z[0..<m], x, result: &B[0..<m])
//            // a0
//            vDSP.multiply(z[0..<m], y, result: &A[0..<m])
//            vDSP.negative(A[0..<m], result: &A[0..<m])
//            // basis
//            for k in 0..<max(count.b, count.a) {
//                let col = m * k + m
//                vDSP.multiply(.init(2*k+2), ω, result: &z[0..<m])
//                vForce.cosPi(z[0..<m], result: &z[0..<m])
//                vDSP.multiply(2.0.squareRoot(), z[0..<m], result: &z[0..<m])
//                if k < count.b { // b
//                    vDSP.multiply(z[0..<m], B[0..<m], result: &B[col..<col+m])
//                }
//                if k < count.a { //a
//                    vDSP.multiply(z[0..<m], A[0..<m], result: &A[col..<col+m])
//                }
//            }
//            let ε = gesvd(m, n,
//                          M.baseAddress, m,
//                          s.baseAddress,
//                          .none, m,
//                          v.baseAddress, n,
//                          z.baseAddress, z.count)
//            assert(ε == 0)
//            let pₛ = ( count.b * 0 + 1 ) * n - 1
//            let qₛ = ( count.b * 1 + 2 ) * n - 1
//            s[0] = v[pₛ].sign != v[qₛ].sign ? -1 : 1
//            s.dropFirst().update(repeating: s[0] * 2.0.squareRoot())
//            return.init(raw: (
//                .init(unsafeUninitializedCapacity: 1 + count.b) {
//                    $1 = $0.count
//                    copy($1,
//                         v.baseAddress.unsafelyUnwrapped.advanced(by: pₛ), n,
//                         $0.baseAddress.unsafelyUnwrapped, 1)
//                    vDSP.multiply(s[0..<$1], $0, result: &$0)
//                },
//                .init(unsafeUninitializedCapacity: 1 + count.a) {
//                    $1 = $0.count
//                    copy($1,
//                         v.baseAddress.unsafelyUnwrapped.advanced(by: qₛ), n,
//                         $0.baseAddress.unsafelyUnwrapped, 1)
//                    vDSP.multiply(s[0..<$1], $0, result: &$0)
//                }
//            ))
//        }
//    }
    // Power LS with P(t), Q(t) >= ε for every t in [-1, 1].
    @inlinable
    public static func fit(xx x: some AccelerateBuffer<Float64>,
                           yy y: some AccelerateBuffer<Float64>,
                           frequency ω: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                           weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                           minimum ε: Float64,
                           count: (p: Int, q: Int)) -> (coefficients: Direct.Power, converged: Bool) {
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
        precondition(n <= m)
        precondition(x.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(y.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(ω.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(w.withUnsafeBufferPointer { $0.allSatisfy { $0.isFinite && 0 <= $0 } })
        let l = geqrf(m, n,
                      .none, m,
                      .none,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + min(m, n) + max(m, n, l)) {
            let M = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let s = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(min(m, n)))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + min(m, n)).prefix(max(m, n, l)))
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
            switch geqrf(m, n, M.baseAddress, m, s.baseAddress, z.baseAddress, z.count) {
            case let info:
                assert(info == 0, "geqrf ends with \(info)")
                for (col, len) in repeatElement(min(m, n), count: n).enumerated() {
                    M[col*m+col+1..<col*m+len].update(repeating: .zero)
                }
            }
            return switch fit(m: n, n: (p, q),
                              a: M, lda: m,
                              minimum: ε) {
            case (let θ, let coveraged):
                (
                    Direct.Power(raw: (
                        .init(θ.prefix(p)),
                        .init(θ.suffix(q))
                    )),
                    coveraged
                )
            }
        }
    }
    
    // Power LS with P(t), Q(t) >= ε for every t in [-1, 1].
    // The otherwise homogeneous scale is fixed symmetrically by p[0] + q[0] = 2.
    @inlinable
    public static func fit(xx x: some AccelerateBuffer<Float64>,
                           yy y: some AccelerateBuffer<Float64>,
                           frequency ω: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                           weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                           iteration: Optional<Int> = .none,
                           minimum ε: Float64,
                           count: (p: Int, q: Int)) -> Direct.Power {
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
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + 2 * max(m, n)) {
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
            return fit(rows: m, cols: (p, q),
                       A: M, ld: m,
                       iteration: iteration ?? m,
                       minimum: ε)
        }
    }

    /// Fits the power relation `P(t) U - Q(t) V = 0` from jointly estimated
    /// real power quantities `U` and `V`.
    ///
    /// For each frequency this minimizes
    ///
    ///     w E[(P U - Q V)²] / (E[U²] + E[V²])
    ///
    /// and expands the normalized 2×2 second-moment matrix into two real least-
    /// squares rows. Zero variances and covariance reduce the block to the same
    /// rank-one Gram matrix used by the deterministic Power WNLS overload.
    @inlinable
    static func fit(xx x: (μ: some AccelerateBuffer<Float64>,
                           σ²: some AccelerateBuffer<Float64>),
                    yy y: (μ: some AccelerateBuffer<Float64>,
                           σ²: some AccelerateBuffer<Float64>),
                    cov σxy: some AccelerateBuffer<Float64>,
                    frequency ω: some AccelerateBuffer<Float64>,
                    weight w: some AccelerateBuffer<Float64>,
                    iteration: Optional<Int> = .none,
                    minimum ε: Float64,
                    count: (p: Int, q: Int)) -> Direct.Power {
        let b = ω.count
        precondition(0 < b)
        precondition(b == x.μ.count)
        precondition(b == x.σ².count)
        precondition(b == y.μ.count)
        precondition(b == y.σ².count)
        precondition(b == σxy.count)
        precondition(b == w.count)
        precondition(0 <= count.p)
        precondition(0 <= count.q)
        precondition(0..<1 ~= ε)
        let (p, q) = (count.p + 1, count.q + 1)
        let n = p + q
        precondition(n <= b + 1)
        precondition(x.μ.withUnsafeBufferPointer { $0.allSatisfy((0..<Float64.infinity).contains) })
        precondition(y.μ.withUnsafeBufferPointer { $0.allSatisfy((0..<Float64.infinity).contains) })
        precondition(x.σ².withUnsafeBufferPointer { $0.allSatisfy((0..<Float64.infinity).contains) })
        precondition(y.σ².withUnsafeBufferPointer { $0.allSatisfy((0..<Float64.infinity).contains) })
        precondition(σxy.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(ω.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(w.withUnsafeBufferPointer { $0.allSatisfy((0..<Float64.infinity).contains) })
        let m = 2 * b
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + m) {
            let S = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let workspace = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n))
            let g = UnsafeMutableBufferPointer(rebasing: workspace[0*b..<1*b])
            let δ = UnsafeMutableBufferPointer(rebasing: workspace[1*b..<2*b])

            // The symmetric square root S of
            // w E[[U,V]ᵀ[U,V]] / (E[U²] + E[V²]) gives the two rows
            // [S₀₀ P, -S₀₁ Q] and [S₁₀ P, -S₁₁ Q].
            let s00 = 0..<b
            let s01 = b..<m
            let s10 = p * m + 0..<p * m + b
            let s11 = p * m + b..<p * m + m
            vDSP.add(multiplication: (x.μ, x.μ), x.σ², result: &S[s00])
            vDSP.add(multiplication: (y.μ, y.μ), y.σ², result: &S[s11])
            vDSP.add(multiplication: (x.μ, y.μ), σxy, result: &S[s01])
            vDSP.add(S[s00], S[s11], result: &g[0..<b])
            vDSP.divide(S[s00], g, result: &S[s00])
            vDSP.divide(S[s01], g, result: &S[s01])
            vDSP.divide(S[s11], g, result: &S[s11])
            vDSP.subtract(multiplication: (S[s00], S[s11]),
                          multiplication: (S[s01], S[s01]),
                          result: &δ[0..<b])
            vDSP.clip(δ, to: 0 ... .infinity, result: &δ[0..<b])
            vForce.sqrt(δ, result: &δ[0..<b])
            vDSP.add(multiplication: (δ, 2), 1, result: &g[0..<b])
            vDSP.divide(w, g, result: &g[0..<b])
            vForce.sqrt(g, result: &g[0..<b])
            vDSP.add(S[s00], δ, result: &S[s00])
            vDSP.add(S[s11], δ, result: &S[s11])
            vDSP.multiply(g, S[s00], result: &S[s00])
            vDSP.multiply(g, S[s01], result: &S[s01])
            vDSP.multiply(g, S[s11], result: &S[s11])
            vDSP.negative(S[s01], result: &S[s10])
            vDSP.negative(S[s11], result: &S[s11])

            for k in 1..<max(p, q) {
                vDSP.multiply(.init(2 * k), ω, result: &δ[0..<b])
                vForce.cosPi(δ[0..<b], result: &δ[0..<b])
                if k < p {
                    let col = (0 + k) * m
                    vDSP.multiply(δ,
                                  S[0..<b],
                                  result: &S[col+0..<col+b])
                    vDSP.multiply(δ,
                                  S[b..<m],
                                  result: &S[col+b..<col+m])
                }
                if k < q {
                    let col = (p + k) * m
                    vDSP.multiply(δ,
                                  S[p * m + 0 ..< p * m + b],
                                  result: &S[col+0..<col+b])
                    vDSP.multiply(δ,
                                  S[p * m + b ..< p * m + m],
                                  result: &S[col+b..<col+m])
                }
            }
            return fit(rows: m, cols: (p, q),
                       A: S, ld: m,
                       iteration: iteration ?? m,
                       minimum: ε)
        }
    }
}
// MARK: Power Fit Adapter
extension Linear {
    @inlinable
    static func fit(x: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
                    y: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
                    frequency: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                    weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                    iteration: Optional<Int> = .none,
                    minimum ε: Float64,
                    count: (b: Int, a: Int)) -> Direct {
        let ω = frequency.count
        precondition(ω == x.r.count)
        precondition(ω == x.i.count)
        precondition(ω == y.r.count)
        precondition(ω == y.i.count)
        precondition(ω == w.count)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * ω) {
            let xx = UnsafeMutableBufferPointer(rebasing: $0[0*ω..<1*ω])
            let yy = UnsafeMutableBufferPointer(rebasing: $0[1*ω..<2*ω])
            vDSP.add(multiplication: (x.r, x.r), multiplication: (x.i, x.i), result: &xx[0..<ω])
            vDSP.add(multiplication: (y.r, y.r), multiplication: (y.i, y.i), result: &yy[0..<ω])
            return.init(zpk: fit(xx: xx,
                                 yy: yy,
                                 frequency: frequency,
                                 weight: w,
                                 iteration: iteration,
                                 minimum: ε,
                                 count: (count.b, count.a)).zpkMinimumPhase)
        }
    }
    /// Adapts jointly proper complex-Gaussian amplitude estimates to Power Fit.
    ///
    /// `σ²` denotes `E[|X - E[X]|²]`, and `σxy` denotes
    /// `E[(X - E[X]) (Y - E[Y])ᴴ]`. The fitted power means are debiased to
    /// `|E[X]|²` and `|E[Y]|²`; estimation uncertainty enters through their
    /// induced power variances and covariance.
    @inlinable
    static func fit(x: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
                    y: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
                    σxy: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>), /* c(ω) = E[(X-E[X])*(Y-E[Y])^H] */
                    frequency: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
                    weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
                    iteration: Optional<Int> = .none,
                    minimum ε: Float64,
                    count: (b: Int, a: Int)) -> Direct {
        let ω = frequency.count
        precondition(ω == x.r.count)
        precondition(ω == x.i.count)
        precondition(ω == x.σ².count)
        precondition(ω == y.r.count)
        precondition(ω == y.i.count)
        precondition(ω == y.σ².count)
        precondition(ω == σxy.r.count)
        precondition(ω == σxy.i.count)
        precondition(ω == w.count)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * ω) {
            let μxx = UnsafeMutableBufferPointer(rebasing: $0[0*ω..<1*ω])
            let σ²xx = UnsafeMutableBufferPointer(rebasing: $0[1*ω..<2*ω])
            let μyy = UnsafeMutableBufferPointer(rebasing: $0[2*ω..<3*ω])
            let σ²yy = UnsafeMutableBufferPointer(rebasing: $0[3*ω..<4*ω])
            let σxx_yy = UnsafeMutableBufferPointer(rebasing: $0[4*ω..<5*ω])
            let z = UnsafeMutableBufferPointer(rebasing: $0[5*ω..<6*ω])

            // Debiased power means: E[|X̂|² - Var(X̂)] = |μX|².
            vDSP.add(multiplication: (x.r, x.r), multiplication: (x.i, x.i), result: &μxx[0..<ω])
            vDSP.add(multiplication: (y.r, y.r), multiplication: (y.i, y.i), result: &μyy[0..<ω])

            // For proper complex Gaussian errors:
            // Var(|X̂|²) = vX² + 2 vX |μX|².
            vDSP.add(multiplication: (μxx, 2), x.σ², result: &σ²xx[0..<ω])
            vDSP.multiply(x.σ², σ²xx, result: &σ²xx[0..<ω])
            vDSP.add(multiplication: (μyy, 2), y.σ², result: &σ²yy[0..<ω])
            vDSP.multiply(y.σ², σ²yy, result: &σ²yy[0..<ω])

            // Cov(|X̂|², |Ŷ|²) = |c|² + 2 Re(μX̅ c μY).
            vDSP.add(multiplication: (x.r, y.r),
                     multiplication: (x.i, y.i),
                     result: &σxx_yy[0..<ω])
            vDSP.subtract(multiplication: (x.r, y.i),
                          multiplication: (x.i, y.r),
                          result: &z[0..<ω])
            vDSP.subtract(multiplication: (σxy.r, σxx_yy),
                          multiplication: (σxy.i, z),
                          result: &σxx_yy[0..<ω])
            vDSP.add(multiplication: (σxy.r, σxy.r),
                     multiplication: (σxy.i, σxy.i),
                     result: &z[0..<ω])
            vDSP.add(multiplication: (σxx_yy, 2), z, result: &σxx_yy[0..<ω])

            return.init(zpk: fit(xx: (μ: μxx, σ²: σ²xx),
                                 yy: (μ: μyy, σ²: σ²yy),
                                 cov: σxx_yy,
                                 frequency: frequency,
                                 weight: w,
                                 iteration: iteration,
                                 minimum: ε,
                                 count: (count.b, count.a)).zpkMinimumPhase)
        }
    }
}
// MARK: Fit Group delay fit with Allpass
extension Linear {
    @inlinable
    static func fit(group delay: some AccelerateBuffer<Float64>,
                    frequency: some AccelerateBuffer<Float64>,
                    weight: some AccelerateBuffer<Float64>,
                    maximum iteration: Int,
                    tolerance: Float64,
                    initial poles: some AccelerateBuffer<Complex128>/* conjugate will be automatically computed, the lower half plane pole will be ignored */) -> Linear.ZPK {
        // direct controle poles to fit with group delay, zeros will be used to construct allpass gain
        fatalError()
    }
}
