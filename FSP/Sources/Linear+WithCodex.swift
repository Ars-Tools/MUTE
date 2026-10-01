// Positive power-spectrum least squares via a Riesz–Fejér SDP.
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import BLAS
import LAPACK
import func Darwin.log

extension Linear { public enum WithCodex {} }

extension Linear.WithCodex {
    public enum FitStatus { case optimal, iterationLimit, numericalFailure }

    /// All objectives and certificates use weights divided by their maximum.
    /// `power` is the last feasible candidate, including on unsuccessful solves.
    /// A floating-point certificate is subject to rounding, not interval arithmetic.
    public struct FitResult {
        public let power: Linear.Direct.Power
        public let status: FitStatus
        public let iterations: Int
        public let objective: Float64
        public let dualLowerBound: Float64
        public let dualityGap: Float64
        public let equalityResidual: Float64
        public let stationarityResidual: Float64
        public let barrierWeight: Float64
    }

    /// Source-compatible convenience API. Returns identity if the solve cannot
    /// establish approximate optimality. Use `fitResult` to inspect failures.
    /// `iteration` is now a TOTAL Newton-step budget (default 2048).
    public static func fit(xx x: some AccelerateBuffer<Float64>,
                           yy y: some AccelerateBuffer<Float64>,
                           frequency omega: some AccelerateBuffer<Float64>,
                           weight: some AccelerateBuffer<Float64>,
                           iteration: Optional<Int> = .none,
                           barrierFloor: Float64 = 1e-14,
                           minimum epsilon: Float64,
                           count: (p: Int, q: Int)) -> Linear.Direct.Power {
        let result = fitResult(xx: x, yy: y, frequency: omega, weight: weight,
                               iteration: iteration, barrierFloor: barrierFloor,
                               minimum: epsilon, count: count)
        if result.status == .optimal { return result.power }
        var p = Array<Float64>(repeating: 0, count: count.p + 1)
        var q = Array<Float64>(repeating: 0, count: count.q + 1)
        p[0] = 1; q[0] = 1
        return .init(raw: (p, q))
    }

    /// Minimize 0.5 Σ w (P Sxx - Q Syy)²/(Sxx² + Syy²), subject to
    /// P,Q >= ε on [-1,1] and p₀+q₀=2. Zero-power rows carry no information.
    ///
    /// Riesz–Fejér: P-ε = ψᴴGψ, G >= 0, ψ=(1,eⁱθ,...,eⁱⁿθ).
    /// For a real symmetric Gram, p₀=ε+tr(G), pₖ=2ΣᵢG[i,i+k].
    /// This is an exact cone representation, not a sampled positivity relaxation.
    /// With u=(svec(G),svec(H)), c=cε+Lu, and aᵀu=β=2-2ε,
    /// the objective remains a convex quadratic f(u).
    ///
    /// Primal-dual central equations:
    ///   ∇f(u)+νa-z=0, aᵀu=β, G Zp=μI, H Zq=μI.
    /// Eliminate Zp=μG⁻¹, Zq=μH⁻¹. Newton then solves the SPD
    /// log-det Hessian with one equality Schur complement. This is feasible
    /// central-path following with eliminated dual matrices, not an HSD solver.
    /// Each step checks feasibility and Armijo descent. Emergency Newton damping
    /// changes only the search direction, never the data objective.
    ///
    /// A dual lower bound is built from the supporting plane of f and PSD
    /// dual slacks, so reaching a small μ alone does not imply success.
    /// `barrierFloor` is relative to the mean lifted Hessian diagonal; smaller
    /// values can be necessary for weak LF directions. It is not a noise model.
    /// No coefficient regularization is added. `optimalityTolerance` bounds the gap.
    public static func fitResult(xx x: some AccelerateBuffer<Float64>,
                                 yy y: some AccelerateBuffer<Float64>,
                                 frequency ω: some AccelerateBuffer<Float64>,
                                 weight w: some AccelerateBuffer<Float64>,
                                 iteration: Optional<Int> = .none,
                                       barrierFloor: Float64 = 1e-14,
                                 optimalityTolerance: Float64 = 1e-8,
                                 minimum ε: Float64,
                                 count: (p: Int, q: Int)) -> FitResult {
        precondition(barrierFloor.isFinite && 0 < barrierFloor && barrierFloor <= 1)
        precondition(iteration == nil || iteration! >= 0)
        precondition(optimalityTolerance.isFinite && optimalityTolerance > 0)
        let m = ω.count
        precondition(0 < m)
        precondition(m == x.count)
        precondition(m == y.count)
        precondition(m == w.count)
        precondition(0 <= count.p)
        precondition(0 <= count.q)
        precondition(ε.isFinite && 0 < ε && ε < 1)
        precondition(x.withUnsafeBufferPointer { $0.allSatisfy { $0.isFinite && 0 <= $0 } })
        precondition(y.withUnsafeBufferPointer { $0.allSatisfy { $0.isFinite && 0 <= $0 } })
        precondition(ω.withUnsafeBufferPointer { $0.allSatisfy(\.isFinite) })
        precondition(w.withUnsafeBufferPointer { $0.allSatisfy { $0.isFinite && 0 <= $0 } })
        let p = count.p + 1
        let q = count.q + 1
        let small = p + q
        let root2 = 2.0.squareRoot()
        let xx = x.withUnsafeBufferPointer(Array.init)
        let yy = y.withUnsafeBufferPointer(Array.init)
        let rawWeights = w.withUnsafeBufferPointer(Array.init)
        let weightScale = rawWeights.max()!
        let ww = rawWeights.map { weightScale > 0 ? $0 / weightScale : 0 }
        let ff = ω.withUnsafeBufferPointer { $0.map { $0.truncatingRemainder(dividingBy: 1) } }
        // Weighted data columns: base[l] = sqrt(w/(x² + y²)) (x, -y).
        var xcol = Array<Float64>(repeating: 0, count: m)
        var ycol = Array<Float64>(repeating: 0, count: m)
        for l in 0..<m {
            // Normalize powers before hypot: even finite inputs near DBL_MAX
            // must not overflow and silently drop a measurement row.
            let scale = max(xx[l], yy[l])
            if scale > 0 && ww[l] > 0 {
                let x = xx[l] / scale, y = yy[l] / scale
                let h = (x*x + y*y).squareRoot()
                let weight = ww[l].squareRoot()
                xcol[l] = weight * x / h
                ycol[l] = -weight * y / h
            }
        }
        // M[:, k] = xcol T_k, M[:, p + k] = ycol T_k; T_k(cos 2πω) = cos 2πkω.
        var M = Array<Float64>(repeating: 0, count: m * small)
        M.replaceSubrange(0..<m, with: xcol)
        M.replaceSubrange(p * m ..< p * m + m, with: ycol)
        if 1 < max(p, q) {
            var t = Array<Float64>(repeating: 0, count: m)
            for k in 1..<max(p, q) {
                vDSP.multiply(2 * Float64(k), ff, result: &t)
                vForce.cosPi(t, result: &t)
                if k < p {
                    vDSP.multiply(t, xcol, result: &M[k * m ..< k * m + m])
                }
                if k < q {
                    vDSP.multiply(t, ycol, result: &M[(p + k) * m ..< (p + k) * m + m])
                }
            }
        }
        // Small data Gram; every lifted column is a scaled copy of a column
        // of M, so the big quadratic expands from Γ without materializing it.
        var Γ = Array<Float64>(repeating: 0, count: small * small)
        gemm(small, small, m, 1, M, m, .T, M, m, .N, 0, &Γ, small)
        // Scaled svec layout (‖svec‖₂ = ‖G‖_F): per block, columns j, rows
        // i <= j; the entry feeds Chebyshev coefficient k = j - i of its
        // polynomial with factor 1 on the diagonal and √2 off it.
        let nP = p * (p + 1) / 2
        let nQ = q * (q + 1) / 2
        let N = nP + nQ
        var κ = Array<Int>()     // column of M the svec entry couples to
        var factor = Array<Float64>()
        var diagonal = Array<Bool>()
        var row = Array<Int>()
        var col = Array<Int>()
        κ.reserveCapacity(N)
        factor.reserveCapacity(N)
        diagonal.reserveCapacity(N)
        row.reserveCapacity(N)
        col.reserveCapacity(N)
        for (base, d) in [(0, p), (p, q)] {
            for j in 0..<d {
                for i in 0...j {
                    κ.append(base + j - i)
                    factor.append(i == j ? 1 : root2)
                    diagonal.append(i == j)
                    row.append(i)
                    col.append(j)
                }
            }
        }
        // K = LᵀMᵀML is the constant data Hessian in svec coordinates.
        var K = Array<Float64>(repeating: 0, count: N * N)
        for c2 in 0..<N {
            for c1 in 0..<N {
                K[c1 + c2 * N] = factor[c1] * factor[c2] * Γ[κ[c1] + κ[c2] * small]
            }
        }
        // Equality p₀ + q₀ = 2 ⟺ tr G + tr H = 2 - 2ε.
        let β = 2 - 2 * ε
        var a = Array<Float64>(repeating: 0, count: N)
        for c in 0..<N where diagonal[c] {
            a[c] = 1
        }
        // svec ↔ dense block helpers
        let dmax = max(p, q)
        var S = Array<Float64>(repeating: 0, count: dmax * dmax)
        var Wp = Array<Float64>(repeating: 0, count: p * p)
        var Wq = Array<Float64>(repeating: 0, count: q * q)
        func dense(_ u: borrowing Array<Float64>, _ offset: Int, _ d: Int) {
            var c = offset
            for j in 0..<d {
                for i in 0...j {
                    let value = i == j ? u[c] : u[c] / root2
                    S[i + j * d] = value
                    S[j + i * d] = value
                    c += 1
                }
            }
        }
        var trialCoefficients = Array<Float64>(repeating: 0, count: small)
        var trialResidual = Array<Float64>(repeating: 0, count: m)
        var dataGradient = Array<Float64>(repeating: 0, count: small)
        var dataValue = 0.0
        // Evaluate the data term from residuals rather than a cancellation-prone
        // expanded quadratic, especially near an exactly representable LF fit.
        func objective(_ u: borrowing Array<Float64>, _ μ: Float64) -> Float64? {
            var logDet = 0.0
            for (offset, d) in [(0, p), (nP, q)] {
                dense(u, offset, d)
                guard potrf(d, &S, d, .L) == 0 else { return nil }
                for i in 0..<d { logDet += 2 * log(S[i + i * d]) }
            }
            for i in 0..<small { trialCoefficients[i] = 0 }
            trialCoefficients[0] = ε
            trialCoefficients[p] = ε
            for c in 0..<N { trialCoefficients[κ[c]] += factor[c] * u[c] }
            gemv(m, small, 1, M, m, .N, trialCoefficients, 1, 0, &trialResidual, 1)
            dataValue = 0.5 * dot(m, trialResidual, 1, trialResidual, 1)
            let value = dataValue - μ * logDet
            return value.isFinite ? value : nil
        }
        // W ← block⁻¹ via Cholesky; fail without trapping when not PD.
        func invert(_ u: borrowing Array<Float64>, _ offset: Int, _ d: Int, _ W: inout Array<Float64>) -> Bool {
            dense(u, offset, d)
            guard potrf(d, &S, d, .L) == 0 else { return false }
            W.withUnsafeMutableBufferPointer {
                vDSP.clear(&$0[...])
                for i in 0..<d {
                    $0[i + i * d] = 1
                }
            }
            switch potrs(d, d, &S, d, .L, &W, d) {
            case let info:
                guard info == 0 else { return false }
                return W.allSatisfy(\.isFinite) // marginal factors can overflow the inverse
            }
        }
        // Reduced primal-dual central path; dual cones remain interior through
        // Z=μG⁻¹. Finite-precision conditioning still needs response regressions.
        var u = Array<Float64>(repeating: 0, count: N)
        for c in 0..<N where diagonal[c] { // strictly feasible start: P = Q = 1
            u[c] = (1 - ε) / Float64(c < nP ? p : q)
        }
        var gradient = Array<Float64>(repeating: 0, count: N)
        var H = Array<Float64>(repeating: 0, count: N * N)
        var rhs = Array<Float64>(repeating: 0, count: 2 * N)
        var candidate = u
        let scaleK = (0..<N).reduce(0.0) { $0 + K[$1 + $1 * N] } / Float64(N)
        guard scaleK.isFinite && 0 < scaleK else {
            var cp = Array<Float64>(repeating: 0, count: p)
            var cq = Array<Float64>(repeating: 0, count: q)
            cp[0] = 1; cq[0] = 1
            let noData = scaleK == 0
            let value = zip(xcol, ycol).reduce(0.0) { $0 + 0.5 * ($1.0 + $1.1) * ($1.0 + $1.1) }
            return FitResult(power: .init(raw: (cp, cq)), status: noData ? .optimal : .numericalFailure,
                             iterations: 0, objective: value, dualLowerBound: 0, dualityGap: value,
                             equalityResidual: 0, stationarityResidual: noData ? 0 : .infinity, barrierWeight: 0)
        }
        let μfloor = max(Float64.leastNormalMagnitude, barrierFloor * scaleK)
        var μ = scaleK
        let budget = iteration ?? 2048
        var steps = 0
        var multiplier = 0.0
        var stationarity = Float64.infinity
        var reachedFloor = false
        var exhausted = false
        // At most 256 stages, 64 Newton steps/stage, 16 factorization attempts,
        // and 53 line-search trials/step, plus a total Newton budget.
        path: for _ in 0..<256 {
            newton: for _ in 0..<64 {
                guard steps < budget else { exhausted = true; break path }
                steps += 1
                guard invert(u, 0, p, &Wp), invert(u, nP, q, &Wq) else {
                    break newton // numerically pinned to the cone boundary; keep u
                }
                // Form the gradient from original residuals, avoiding the
                // cancellation of K*u + g along weak LF directions.
                guard let current = objective(u, μ) else { break newton }
                gemv(m, small, 1, M, m, .T, trialResidual, 1, 0, &dataGradient, 1)
                for c in 0..<N { gradient[c] = factor[c] * dataGradient[κ[c]] }
                for c in 0..<N {
                    let W = c < nP ? Wp : Wq
                    let d = c < nP ? p : q
                    gradient[c] -= μ * factor[c] * W[row[c] + col[c] * d]
                }
                for c2 in 0..<N {
                    let W = c2 < nP ? Wp : Wq
                    let d = c2 < nP ? p : q
                    let lower = c2 < nP ? 0 : nP
                    let upper = c2 < nP ? nP : N
                    let (i2, j2) = (row[c2], col[c2])
                    for c1 in 0..<N {
                        H[c1 + c2 * N] = K[c1 + c2 * N]
                    }
                    for c1 in lower..<upper {
                        let (i1, j1) = (row[c1], col[c1])
                        let v = W[i1 + i2 * d] * W[j1 + j2 * d] + W[i1 + j2 * d] * W[j1 + i2 * d]
                        H[c1 + c2 * N] += μ * factor[c1] * factor[c2] * v / 2
                    }
                }
                // K₀ is rank-deficient, so PD rests on the barrier term; near
                // the cone boundary W ~ 1/ε inflates the dynamic range beyond
                // double rounding. Retry with Levenberg damping instead of dying.
                var HF = H
                let scale = (0..<N).map { abs(H[$0 + $0 * N]) }.max()!
                var factorized = false
                var damping = 0.0
                for _ in 0..<16 {
                    HF = H
                    for c in 0..<N { HF[c + c * N] += damping }
                    if potrf(N, &HF, N, .L) == 0 { factorized = true; break }
                    damping = max(16 * damping, 0x1p-44 * scale)
                    if !damping.isFinite || damping >= scale { break }
                }
                guard factorized else { break newton }
                for c in 0..<N { // columns: -∇ and a (for the equality Schur step)
                    rhs[c] = -gradient[c]
                    rhs[N + c] = a[c]
                }
                switch potrs(N, 2, &HF, N, .L, &rhs, N) {
                case let info:
                    guard info == 0 else { break newton }
                }
                let drift = β - dot(N, a, 1, u, 1)
                var ah = 0.0
                var ag = 0.0
                for c in 0..<N {
                    ah += a[c] * rhs[N + c]
                    ag += a[c] * rhs[c]
                }
                guard ah.isFinite && ah > 0 else { break newton }
                let ν = (ag - drift) / ah
                multiplier = ν
                stationarity = (0..<N).map { abs(gradient[$0] + ν * a[$0]) }.max()!
                var decrement = 0.0
                for c in 0..<N {
                    rhs[c] -= ν * rhs[N + c]
                    decrement -= gradient[c] * rhs[c]
                }
                guard decrement.isFinite, decrement >= 0 else { break newton }
                if decrement <= max(1e-28 * scaleK, 1e-6 * μ) { break newton }
                // Armijo descent as well as cone feasibility is required.
                var t = 1.0
                var accepted = false
                for _ in 0..<53 {
                    for c in 0..<N {
                        candidate[c] = u[c] + t * rhs[c]
                    }
                    if let value = objective(candidate, μ),
                       value <= current - 0.01 * t * decrement {
                        accepted = true
                        break
                    }
                    t /= 2
                }
                guard accepted else {
                    break newton // boundary-pinned; keep the last interior iterate
                }
                swap(&u, &candidate)

            }
            if μ <= μfloor {
                reachedFloor = true
                break
            }
            μ = max(0.05 * μ, μfloor)
        }
        // Rescale Grams, not completed coefficients: this preserves P,Q >= ε.
        let trace = dot(N, a, 1, u, 1)
        let gramScale = β / trace
        for i in 0..<N { u[i] *= gramScale }
        _ = objective(u, μ)
        gemv(m, small, 1, M, m, .T, trialResidual, 1, 0, &dataGradient, 1)
        var gf = Array<Float64>(repeating: 0, count: N)
        for c in 0..<N { gf[c] = factor[c] * dataGradient[κ[c]] }

        // Convexity: f(v) >= f(u)+gfᵀ(v-u).
        // If Z=mat(gf)+νI >= 0, gfᵀv >= -νβ on the feasible set.
        // Hence d=f(u)-gfᵀu-νβ is a global dual lower bound.
        var minEigenvalue = Float64.infinity
        var eigenOK = true
        var roundingMargin = 0.0
        for (offset, d) in [(0, p), (nP, q)] {
            dense(gf, offset, d)
            var eig = Array<Float64>(repeating: 0, count: d)
            var work = Array<Float64>(repeating: 0, count: max(1, 3*d))
            let norm = S.prefix(d*d).map(abs).max()!
            roundingMargin = max(roundingMargin, 128 * Float64.ulpOfOne * Float64(d) * norm)
            if syev(d, &S, d, .L, false, &eig, &work, work.count) != 0 || !eig.allSatisfy(\.isFinite) {
                eigenOK = false; break
            }
            minEigenvalue = min(minEigenvalue, eig[0])
        }
        let dualMultiplier = -minEigenvalue + roundingMargin
        let supportingGap = eigenOK ? max(0, dot(N, gf, 1, u, 1) + dualMultiplier * β) : .infinity
        let value = dataValue
        // Zero residual dual variables give the universal lower bound 0 for
        // this sum-of-squares objective. This stronger bound matters on exactly
        // representable, rank-deficient fits where gradient rounding otherwise
        // makes the supporting-plane bound needlessly pessimistic.
        let lowerBound = max(0, value - supportingGap)
        let gap = max(0, value - lowerBound)
        let equality = abs(dot(N, a, 1, u, 1) - β)
        // Recompute the central stationarity at the returned iterate.
        if invert(u, 0, p, &Wp), invert(u, nP, q, &Wq) {
            stationarity = 0
            for c in 0..<N {
                let W = c < nP ? Wp : Wq
                let d = c < nP ? p : q
                stationarity = max(stationarity, abs(gf[c] + multiplier*a[c]
                    - μ * factor[c] * W[row[c] + col[c]*d]))
            }
        }
        let feasible = objective(u, μ) != nil && equality <= 1e-10
        let status: FitStatus
        if reachedFloor && feasible && eigenOK && gap <= optimalityTolerance * max(1, abs(value)) {
            status = .optimal
        } else if exhausted { status = .iterationLimit }
        else { status = .numericalFailure }
        var coefficients = Array<Float64>(repeating: 0, count: small)
        coefficients[0] = ε; coefficients[p] = ε
        for c in 0..<N { coefficients[κ[c]] += factor[c] * u[c] }
        return FitResult(power: .init(raw: (Array(coefficients.prefix(p)), Array(coefficients.suffix(q)))),
                         status: status, iterations: steps, objective: value,
                         dualLowerBound: lowerBound, dualityGap: gap,
                         equalityResidual: equality, stationarityResidual: stationarity, barrierWeight: μ)
    }

}
