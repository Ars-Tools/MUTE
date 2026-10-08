//
//  Model+Fit+Complex.swift
//  MUTE
//
//  Created by Kota on 10/7/26.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func LAPACK.geqrf
import func LAPACK.gesvj
// MARK: Complex Fit
extension Model {
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
            case let info:
                assert(info == 0, "geqrf ends with \(info)")
                for (col, len) in repeatElement(min(m, n), count: n).enumerated() {
                    M[col*m+col+1..<col*m+len].update(repeating: .zero)
                }
            }
            switch gesvj(n, n,
                         M.baseAddress, m, .U,
                         s.baseAddress,
                         0,
                         v.baseAddress, n,
                         z.baseAddress, z.count) {
            case let info:
                assert(info == 0, "gesvj ends with \(info)")
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
            case let info:
                assert(info == 0, "geqrf ends with \(info)")
                for (col, len) in repeatElement(min(m, n), count: n).enumerated() {
                    M[col*m+col+1..<col*m+len].update(repeating: .zero)
                }
            }
            switch gesvj(n, n,
                         M.baseAddress, m, .U,
                         s.baseAddress,
                         0,
                         v.baseAddress, n,
                         z.baseAddress, z.count) {
            case let info:
                assert(info == 0, "gesvj ends with \(info)")
            }
            return.init(raw: (
                .init(v.dropFirst(n * n - n + 0 + 0 * count.b).prefix(1 + count.b)),
                .init(v.dropFirst(n * n - n + 1 + 1 * count.b).prefix(1 + count.a))
            ))
        }
    }
}
