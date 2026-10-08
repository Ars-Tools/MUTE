//
//  Model+Fit+Power.swift
//  MUTE
//
//  Created by Kota on 10/7/26.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func simd.fma
import func simd.log
import func MKL.vDSP_copy
import func MKL.vDSP_fill
import func MKL.vDSP_add
import func BLAS.copy
import func BLAS.axpy
import func BLAS.dot
import func BLAS.syrk
import func BLAS.trmv
import func BLAS.trmm
import func BLAS.gemv
import func BLAS.gemm
import func LAPACK.larf
import func LAPACK.larfg
import func LAPACK.potrf
import func LAPACK.potrs
import func LAPACK.potri
import func LAPACK.geqrf
import func LAPACK.gesvd
extension Model {
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
//    @inlinable@inline(__always)@_transparent
//    static func addBarrierHessian(n: Int, μ: Float64,
//                                  K: UnsafeMutableBufferPointer<Float64>, ld ldK: Int,
//                                  Β: UnsafeMutableBufferPointer<Float64>, ld ldΒ: Int) {
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
//        nonisolated(unsafe) let kp = K.baseAddress.unsafelyUnwrapped
//        nonisolated(unsafe) let bp = Β.baseAddress.unsafelyUnwrapped
//        DispatchQueue.concurrentPerform(iterations: n) { l in
//            let firstB = l * (l + 1) / 2
//            for k in 0...l {
//                let b = firstB + k
//                let sb = l == k ? 1 : sqrt2
//                let factor = 0.5 * μ * sb * sqrt2
//                for j in 0...l {
//                    let end = j == l ? k + 1 : j + 1
//                    let count = min(j, end)
//                    let dest = bp.advanced(by: b * ldΒ + j * (j + 1) / 2)
//                    // i < j：sa = √2
//                    if 0 < count {
//                        axpy(count,
//                             factor * kp[l * ldK + j],
//                             kp.advanced(by: k * ldK), 1,
//                             dest, 1)
//                        axpy(count,
//                             factor * kp[k * ldK + j],
//                             kp.advanced(by: l * ldK), 1,
//                             dest, 1)
//                    }
//                    // i == j：sa = 1、weight = 2 K[j,k] K[j,l]
//                    if j < end {
//                        dest[j] += μ * sb * kp[k * ldK + j] * kp[l * ldK + j]
//                    }
//                }
//            }
//        }
//    }
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
//    @inlinable // SPD v1
//    static func fit(m: Int, n count: (p: Int, q: Int),
//                    a: UnsafeMutableBufferPointer<Float64>, lda: Int,
//                    armijo: Float64 = 0.01,
//                    iteration: Int = 42, // newton iteration
//                    torelance: Float64 = 1e-8,
//                    centering: Float64 = 0.01,
//                    reduction: Float64 = 0.2,
//                    minimum ε: Float64) ->  (coefficients: Array<Float64>, converged: Bool) {
//        let (p, q) = count
//        let n = p + q
//        let dp = (p * p + p) / 2
//        let dq = (q * q + q) / 2
//        let d = dp + dq
//        precondition(m > 0)
//        precondition(p > 0 && q > 0)
//        precondition(lda >= m)
//        precondition(a.count >= (n - 1) * lda + m)
//        precondition(ε.isFinite && 0 < ε && ε < 1)
//        precondition(iteration >= 0)
//        let p² = switch p.multipliedReportingOverflow(by: p) {
//        case (let square, false):
//            square
//        default:
//            preconditionFailure()
//        }
//        let q² = switch q.multipliedReportingOverflow(by: q) {
//        case (let square, false):
//            square
//        default:
//            preconditionFailure()
//        }
//        let M² = p² + q²
//        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: 4 * M² + 2 * n + 4 * d + m * d + d * d + m) {
//            let (Gₘ, Hₘ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(0 * M²).prefix(M²)) {
//            case let M: (
//                UnsafeMutableBufferPointer(rebasing: M.prefix(p²)),
//                UnsafeMutableBufferPointer(rebasing: M.suffix(q²))
//            )}
//            let (Gᵧ, Hᵧ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(1 * M²).prefix(M²)) {
//            case let C: (
//                UnsafeMutableBufferPointer(rebasing: C.prefix(p²)),
//                UnsafeMutableBufferPointer(rebasing: C.suffix(q²))
//            )}
//            let (Gₗ, Hₗ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(2 * M²).prefix(M²)) {
//            case let L: (
//                UnsafeMutableBufferPointer(rebasing: L.prefix(p²)),
//                UnsafeMutableBufferPointer(rebasing: L.suffix(q²))
//            )}
//            let (Gᵢ, Hᵢ) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(3 * M²).prefix(M²)) {
//            case let L: (
//                UnsafeMutableBufferPointer(rebasing: L.prefix(p²)),
//                UnsafeMutableBufferPointer(rebasing: L.suffix(q²))
//            )}
//            let (θ, g) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M²).prefix(2 * n)) {
//            case let W: (
//                UnsafeMutableBufferPointer(rebasing: W.prefix(n)),
//                UnsafeMutableBufferPointer(rebasing: W.suffix(n))
//            )}
//            let (v, e, u, w) = switch UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M² + 2 * n).prefix(4 * d)) {
//            case let D: (
//                UnsafeMutableBufferPointer(rebasing: D[0*d..<1*d]),
//                UnsafeMutableBufferPointer(rebasing: D[1*d..<2*d]),
//                UnsafeMutableBufferPointer(rebasing: D[2*d..<3*d]),
//                UnsafeMutableBufferPointer(rebasing: D[3*d..<4*d])
//            )}
//            let j = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M² + 2 * n + 4 * d).prefix(m * d))
//            let β = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(4 * M² + 2 * n + 4 * d + m * d).prefix(d * d))
//            let r = UnsafeMutableBufferPointer(rebasing: $0.suffix(m))
//            vDSP.clear(&Gₘ[0..<p²])
//            vDSP_fill((1 - ε) / .init(p), Gₘ.baseAddress.unsafelyUnwrapped, p + 1, p)
//            vDSP.clear(&Hₘ[0..<q²])
//            vDSP_fill((1 - ε) / .init(q), Hₘ.baseAddress.unsafelyUnwrapped, q + 1, q)
//            vDSP.clear(&e[0..<d])
//            switch (
//                UnsafeMutableBufferPointer(rebasing: e.prefix(dp)),
//                UnsafeMutableBufferPointer(rebasing: e.suffix(dq))
//            ) {
//            case (let ep, let eq):
//                for col in 0..<p {
//                    ep[col * (col + 1) / 2 + col] = 1
//                }
//                for col in 0..<q {
//                    eq[col * (col + 1) / 2 + col] = 1
//                }
//            }
//            jacobian(m: m, n: p,
//                     a: .init(rebasing: a.dropFirst(0 * lda)), ld: lda,
//                     j: .init(rebasing: j.dropFirst( 0 * m)), ld: m)
//            jacobian(m: m, n: q,
//                     a: .init(rebasing: a.dropFirst(p * lda)), ld: lda,
//                     j: .init(rebasing: j.dropFirst(dp * m)), ld: m)
//            var μ = 1 as Float64
//            var finished = false
//            path: while !finished, (μ * μ).isNormal {
//                var centered = false
//                newton: for () in repeatElement((), count: iteration) {
//                    coefficients(Gₘ, ε, .init(rebasing: θ.prefix(p)))
//                    coefficients(Hₘ, ε, .init(rebasing: θ.suffix(q)))
//                    gemv(m, n,
//                         1,
//                         a.baseAddress.unsafelyUnwrapped, lda, .N,
//                         θ.baseAddress.unsafelyUnwrapped, 1,
//                         0,
//                         r.baseAddress.unsafelyUnwrapped, 1)
//                    let objective = 0.5 * vDSP.sumOfSquares(r)
//                    gemv(m, n,
//                         1,
//                         a.baseAddress.unsafelyUnwrapped, lda, .T,
//                         r.baseAddress.unsafelyUnwrapped, 1,
//                         0,
//                         g.baseAddress.unsafelyUnwrapped, 1)
//                    adjoint(.init(rebasing: g.prefix(p)), Gᵧ)
//                    adjoint(.init(rebasing: g.suffix(q)), Hᵧ)
//                    guard case.some(let logdetG) = logdet(n: p, a: Gₘ, ld: p, w: Gₗ, ld: p),
//                          case.some(let logdetH) = logdet(n: q, a: Hₘ, ld: q, w: Hₗ, ld: q) else {
//                        assertionFailure("Initial Gram matrices must be positive definite")
//                        break path;
//                    }
//                    vDSP_copy(p, p,
//                              Gₗ.baseAddress.unsafelyUnwrapped, p,
//                              Gᵢ.baseAddress.unsafelyUnwrapped, p)
//                    switch potri(p, Gᵢ.baseAddress.unsafelyUnwrapped, p, .U) {
//                    case let info:
//                        assert(info == 0, "potri failed \(info) for G")
//                    }
//                    for col in 1..<p {
//                        copy(col,
//                             Gᵢ.baseAddress.unsafelyUnwrapped.advanced(by: col * p), 1,
//                             Gᵢ.baseAddress.unsafelyUnwrapped.advanced(by: col), p)
//                    }
//                    vDSP_copy(q, q,
//                              Hₗ.baseAddress.unsafelyUnwrapped, q,
//                              Hᵢ.baseAddress.unsafelyUnwrapped, q)
//                    switch potri(q, Hᵢ.baseAddress.unsafelyUnwrapped, q, .U) {
//                    case let info:
//                        assert(info == 0, "potri failed \(info) for H")
//                    }
//                    for col in 1..<q {
//                        copy(col,
//                             Hᵢ.baseAddress.unsafelyUnwrapped.advanced(by: col * q), 1,
//                             Hᵢ.baseAddress.unsafelyUnwrapped.advanced(by: col), q)
//                    }
//                    let barrierObjective = fma(-μ, logdetG + logdetH, objective)
//                    vDSP.add(multiplication: (Gᵢ, -μ), Gᵧ, result: &Gᵧ[0..<p²])
//                    vDSP.add(multiplication: (Hᵢ, -μ), Hᵧ, result: &Hᵧ[0..<q²])
//                    svec(n: p, a: Gᵧ, lda: p, v: .init(rebasing: v.prefix(dp)))
//                    svec(n: q, a: Hᵧ, lda: q, v: .init(rebasing: v.suffix(dq)))
//                    switch u.update(fromContentsOf: v) {
//                    case let eof:
//                        assert(u.startIndex.distance(to: eof) == v.count)
//                    }
//                    switch w.update(fromContentsOf: e) {
//                    case let eof:
//                        assert(w.startIndex.distance(to: eof) == e.count)
//                    }
//                    syrk(d, m,
//                         1,
//                         j.baseAddress.unsafelyUnwrapped, m, .T,
//                         0,
//                         β.baseAddress.unsafelyUnwrapped, d, .U)
//                    addBarrierHessian(n: p, μ: μ, K: Gᵢ, ld: p, Β: β, ld: d)
//                    addBarrierHessian(n: q, μ: μ, K: Hᵢ, ld: q, Β: .init(rebasing: β.dropFirst(dp * d + dp)), ld: d)
//                    switch potrf(d, β.baseAddress.unsafelyUnwrapped, d, .U) {
//                    case let info:
//                        assert(info == 0, "potrf failed \(info) for β")
//                    }
//                    switch potrs(d, 2, β.baseAddress.unsafelyUnwrapped, d, .U, u.baseAddress.unsafelyUnwrapped, d) {
//                    case let info:
//                        assert(info == 0, "potrs failed \(info) for β and rhs")
//                    }
//                    let eu = dot(d,
//                                 e.baseAddress.unsafelyUnwrapped, 1,
//                                 u.baseAddress.unsafelyUnwrapped, 1)
//                    let ew = dot(d,
//                                 e.baseAddress.unsafelyUnwrapped, 1,
//                                 w.baseAddress.unsafelyUnwrapped, 1)
//                    assert(eu.isFinite)
//                    assert(ew.isFinite && 0 < ew)
//                    vDSP.add(multiplication: (w, eu / ew), multiplication: (u, -1), result: &u[0..<d])
//                    smat(n: p, v: .init(rebasing: u.prefix(dp)), a: Gᵧ, lda: p)
//                    smat(n: q, v: .init(rebasing: u.suffix(dq)), a: Hᵧ, lda: q)
//                    let slope = dot(d,
//                                    v.baseAddress.unsafelyUnwrapped, 1,
//                                    u.baseAddress.unsafelyUnwrapped, 1)
//                    assert(slope.isFinite)
//                    switch w.update(fromContentsOf: u) {
//                    case let eof:
//                        assert(w.startIndex.distance(to: eof) == u.count)
//                    }
//                    trmv(d,
//                         β.baseAddress.unsafelyUnwrapped, d, .N, .U, .N,
//                         w.baseAddress.unsafelyUnwrapped, 1)
//                    let decrementSquared = vDSP.sumOfSquares(w)
//                    assert(decrementSquared.isFinite)
//                    let scale = max(1, objective, μ * .init(n))
//                    let threshold = min(torelance * scale, μ * centering)
//                    if 0.5 * decrementSquared <= threshold {
//                        centered = true
//                        break newton
//                    }
//                    assert(slope < 0)
//                    var α = 1.0
//                    var accepted = slope == 0
//                    linesearch: while !accepted, (α * α).isNormal {
//                        vDSP.add(multiplication: (Gᵧ, α), Gₘ,
//                                 result: &Gᵢ[0..<p²])
//                        vDSP.add(multiplication: (Hᵧ, α), Hₘ,
//                                 result: &Hᵢ[0..<q²])
//                        guard case.some(let testLogdetG) = logdet(n: p, a: Gᵢ, ld: p, w: Gₗ, ld: p),
//                              case.some(let testLogdetH) = logdet(n: q, a: Hᵢ, ld: q, w: Hₗ, ld: q) else {
//                            α *= 0.5
//                            continue linesearch
//                        }
//                        coefficients(Gᵢ, ε, .init(rebasing: θ.prefix(p)))
//                        coefficients(Hᵢ, ε, .init(rebasing: θ.suffix(q)))
//                        gemv(m, n,
//                             1,
//                             a.baseAddress.unsafelyUnwrapped, lda, .N,
//                             θ.baseAddress.unsafelyUnwrapped, 1,
//                             0,
//                             r.baseAddress.unsafelyUnwrapped, 1)
//                        let testObjective = fma(-μ, testLogdetG + testLogdetH, 0.5 * vDSP.sumOfSquares(r))
//                        if testObjective.isFinite, testObjective <= fma(α * armijo, slope, barrierObjective) {
//                            switch Gₘ.update(fromContentsOf: Gᵢ) {
//                            case let eof:
//                                assert(Gₘ.startIndex.distance(to: eof) == Gᵢ.count)
//                            }
//                            switch Hₘ.update(fromContentsOf: Hᵢ) {
//                            case let eof:
//                                assert(Hₘ.startIndex.distance(to: eof) == Hᵢ.count)
//                            }
//                            accepted = true
//                            break linesearch
//                        }
//                        α *= 0.5
//                    } // end of line-search
//                    assert(accepted, "Line search failed")
//                }
//                guard centered else { break path }
//                let objective = 0.5 * vDSP.sumOfSquares(r)
//                let scale = max(1, objective)
//                if μ * .init(n) <= torelance * scale {
//                    finished = true
//                    break path
//                } // end of newton
//                μ *= reduction
//            } // end of path
//            coefficients(Gₘ, ε, .init(rebasing: θ.prefix(p)))
//            coefficients(Hₘ, ε, .init(rebasing: θ.suffix(q)))
//            return (coefficients: .init(θ), converged: finished)
//        }
//    }
}
extension Model {
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
//    @inlinable
//    public static func fit(xx x: some AccelerateBuffer<Float64>,
//                           yy y: some AccelerateBuffer<Float64>,
//                           frequency ω: some AccelerateBuffer<Float64>, // normalized angular frequency, [0, 0.5] a.k.a. [0, π] or [0, 1) a.k.a. [0, 2π)
//                           weight w: some AccelerateBuffer<Float64>, // weight factor for each frequency ω
//                           iteration: Optional<Int> = .none,
//                           minimum ε: Float64,
//                           count: (p: Int, q: Int)) -> (coefficients: Direct.Power, converged: Bool) {
//        let m = ω.count
//        precondition(m == x.count)
//        precondition(m == y.count)
//        precondition(m == w.count)
//        precondition(0 <= count.p)
//        precondition(0 <= count.q)
//        precondition(ε.isFinite && 0 < ε && ε < 1)
//        let (p, q) = switch count {
//        case (let p, let q):
//            (p + 1, q + 1)
//        }
//        let n = p + q
//        precondition(n <= m + 1)
//        precondition(x.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
//        precondition(y.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
//        precondition(ω.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
//        precondition(w.withUnsafeBufferPointer { $0.allSatisfy { $0.isFinite && 0 <= $0 } })
//        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + 2 * max(m, n)) {
//            let M = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
//            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(max(m, n)))
//            // M[l,:] = sqrt(w[l]/(x^2 + y^2)) [x[l]T_b, -y[l]T_a].
//            vForce.sqrt(w, result: &z[0..<m])
//            vDSP.hypot(x, y, result: &M[p * m ..< p * m + m])
//            vDSP.divide(x, M[p * m ..< p * m + m], result: &M[0 * m ..< 0 * m + m])
//            vDSP.multiply(z[0..<m], M[0 * m ..< 0 * m + m], result: &M[0 * m ..< 0 * m + m])
//            vDSP.invertedClip(M[0 * m ..< 0 * m + m], to: 0...0, result: &M[0 * m ..< 0 * m + m])
//            vDSP.divide(y, M[p * m ..< p * m + m], result: &M[p * m ..< p * m + m])
//            vDSP.multiply(z[0..<m], M[p * m ..< p * m + m], result: &M[p * m ..< p * m + m])
//            vDSP.invertedClip(M[p * m ..< p * m + m], to: 0...0, result: &M[p * m ..< p * m + m])
//            vDSP.negative(M[p * m ..< p * m + m], result: &M[p * m ..< p * m + m])
//            /*
//            vDSP.add(multiplication: (x, x),
//                     multiplication: (y, y),
//                     result: &z[0..<m])
//            vDSP.divide(w, z[0..<m], result: &z[0..<m])
//            vForce.sqrt(z[0..<m], result: &z[0..<m])
//            vDSP.multiply(x, z[0..<m], result: &M[0 * m ..< 0 * m + m])
//            vDSP.multiply(y, z[0..<m], result: &M[p * m ..< p * m + m])
//            vDSP.negative(M[p * m ..< p * m + m], result: &M[p * m ..< p * m + m])
//            */
//            for k in 1..<max(p, q) {
//                vDSP.multiply(.init(2 * k), ω, result: &z[0..<m])
//                vForce.cosPi(z[0..<m], result: &z[0..<m])
//                if k < p {
//                    let r = (0 + k) * m ..< (0 + k) * m + m
//                    vDSP.multiply(z[0..<m], M[0 * m ..< 0 * m + m], result: &M[r])
//                }
//                if k < q {
//                    let r = (p + k) * m ..< (p + k) * m + m
//                    vDSP.multiply(z[0..<m], M[p * m ..< p * m + m], result: &M[r])
//                }
//            }
//            /* chebyshev procedure
//            vDSP.multiply(2, ω, result: &z[0..<m])
//            vForce.cosPi(z[0..<m], result: &z[0..<m])
//            if 1 < p {
//                vDSP.multiply(z[0..<m],
//                              M[0 * m ..< 0 * m + m],
//                              result: &M[0 * m + m ..< 0 * m + m + m])
//            }
//            for col in 2..<p {
//                let r = (0 + col) * m ..< (0 + col) * m + m
//                vDSP.multiply(z[0..<m], M[(0 + col - 1) * m ..< (0 + col) * m], result: &M[r])
//                vDSP.add(multiplication: (M[r], 2),
//                         multiplication: (M[(0 + col - 2) * m ..< (0 + col - 1) * m], -1),
//                         result: &M[r])
//            }
//            if 1 < q {
//                vDSP.multiply(z[0..<m],
//                              M[p * m ..< p * m + m],
//                              result: &M[p * m + m ..< p * m + m + m])
//            }
//            for col in 2..<q {
//                let r = (p + col) * m ..< (p + col) * m + m
//                vDSP.multiply(z[0..<m], M[(p + col - 1) * m ..< (p + col) * m], result: &M[r])
//                vDSP.add(multiplication: (M[r], 2),
//                         multiplication: (M[(p + col - 2) * m ..< (p + col - 1) * m], -1),
//                         result: &M[r])
//            }
//            */
//            return switch fit(m: n, n: (p, q),
//                              a: M, lda: m,
//                              minimum: ε) {
//            case (let θ, let coveraged):
//                (
//                    Direct.Power(raw: (
//                        .init(θ.prefix(p)),
//                        .init(θ.suffix(q))
//                    )),
//                    coveraged
//                )
//            }
//        }
//    }

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
    static func fit(xx x: (μ: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
                    yy y: (μ: some AccelerateBuffer<Float64>, σ²: some AccelerateBuffer<Float64>),
                    cov σxy: some AccelerateBuffer<Float64>,
                    frequency ω: some AccelerateBuffer<Float64>,
                    weight w: some AccelerateBuffer<Float64>,
                    minimum ε: Float64,
                    count: (p: Int, q: Int)) -> (coefficients: Direct.Power, converged: Bool) {
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
        let l = geqrf(m, n,
                      .none, m,
                      .none,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + n + max(m, l)) {
            let S = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let τ = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(n))
            let workspace = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + n))
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
            switch geqrf(m, n, S.baseAddress, m, τ.baseAddress, workspace.baseAddress, workspace.count) {
            case let info:
                assert(info == 0, "geqrf ends with \(info)")
                for col in 0..<n {
                    S[col*m+col+1..<col*m+n].update(repeating: .zero)
                }
            }
            return switch fit(m: n, n: (p, q),
                              a: S, lda: m,
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
}
