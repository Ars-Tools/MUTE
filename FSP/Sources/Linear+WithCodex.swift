// Positive power-spectrum least squares, with independent QR compression.
import Accelerate
import BLAS
import LAPACK
import func Darwin.log

extension Linear { public enum WithCodex {} }

extension Linear.WithCodex {
    public enum FitStatus { case optimal, iterationLimit, numericalFailure }

    /// Neither method drops singular directions or changes the least-squares norm.
    public enum Compression: Sendable {
        case qr
        /// Sequential TSQR reduction. The block size affects resources only.
        case tsqr(blockRows: Int)
    }

    public enum CompressionError: Swift.Error {
        case factorizationFailed(Int)
    }

    /// Column-major residual factor in the cosine coefficient basis [p, q].
    /// The original residual norm is `residualScale * ||matrix * coefficients||`.
    /// The explicit scale avoids overflow for extreme finite weights. No weight
    /// or singular direction is discarded. Zero-power rows contribute zero.
    public struct CompressedModel: Sendable {
        public let matrix: [Float64]
        public let rows: Int
        public let count: (p: Int, q: Int)
        public let residualScale: Float64
        public var columns: Int { count.p + count.q + 2 }

        public init(matrix: [Float64], rows: Int, count: (p: Int, q: Int),
                    residualScale: Float64 = 1) {
            precondition(count.p >= 0 && count.q >= 0)
            precondition(rows > 0 && rows <= count.p + count.q + 2)
            precondition(matrix.count == rows * (count.p + count.q + 2))
            precondition(matrix.allSatisfy(\.isFinite))
            precondition(residualScale.isFinite && residualScale >= 0)
            self.matrix = matrix; self.rows = rows; self.count = count
            self.residualScale = residualScale
        }

        /// Reuse a maximum-degree compression for a lower-degree fit without
        /// revisiting the spectrum. Select columns, then QR the small factor.
        public func reduced(to lower: (p: Int, q: Int)) throws -> CompressedModel {
            precondition(lower.p >= 0 && lower.q >= 0 && lower.p <= count.p && lower.q <= count.q)
            let selected = Array(0...lower.p) + Array((count.p+1)...(count.p+1+lower.q))
            var a = [Double](repeating: 0, count: rows*selected.count)
            for (j, column) in selected.enumerated() {
                for i in 0..<rows { a[i+j*rows] = matrix[i+column*rows] }
            }
            let r = try Linear.WithCodex.qrFactor(&a, rows: rows, columns: selected.count)
            return CompressedModel(matrix: r, rows: min(rows, selected.count), count: lower,
                                   residualScale: residualScale)
        }

        public func residualNorm(coefficients: [Float64]) -> Float64 {
            precondition(coefficients.count == columns)
            var r = [Float64](repeating: 0, count: rows)
            gemv(rows, columns, 1, matrix, rows, .N, coefficients, 1, 0, &r, 1)
            // Stable Euclidean norm; reconstruct the original scale explicitly.
            return residualScale * r.reduce(0) { hypot($0, $1) }
        }
    }

    /// Objectives and dual bounds refer to 0.5 ||R c||², before applying
    /// residualScale². Multiplying by this positive scale preserves the optimizer.
    /// Certificates are floating-point estimates, not interval proofs.
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
        public let residualScale: Float64
        public var residualNorm: Float64 { residualScale * (2 * objective).squareRoot() }
    }

    /// Preserve ||(P X - Q Y) * weight / hypot(X,Y)|| for every coefficient
    /// vector. `weight` multiplies the residual (not the squared residual).
    /// Compression depends on the specified degrees; positivity is not involved.
    public static func compress(xx x: some AccelerateBuffer<Float64>,
                                yy y: some AccelerateBuffer<Float64>,
                                frequency omega: some AccelerateBuffer<Float64>,
                                weight: some AccelerateBuffer<Float64>,
                                count: (p: Int, q: Int),
                                compression: Compression = .tsqr(blockRows: 1024)) throws -> CompressedModel {
        let xx = x.withUnsafeBufferPointer(Array.init)
        let yy = y.withUnsafeBufferPointer(Array.init)
        let ff = omega.withUnsafeBufferPointer(Array.init)
        let ww = weight.withUnsafeBufferPointer(Array.init)
        let m = ff.count, p = count.p + 1, q = count.q + 1, d = p + q
        precondition(m > 0 && xx.count == m && yy.count == m && ww.count == m)
        precondition(count.p >= 0 && count.q >= 0)
        precondition(xx.allSatisfy { $0.isFinite && $0 >= 0 })
        precondition(yy.allSatisfy { $0.isFinite && $0 >= 0 })
        precondition(ff.allSatisfy(\.isFinite))
        precondition(ww.allSatisfy { $0.isFinite && $0 >= 0 })
        let block: Int
        switch compression {
        case .qr: block = m
        case .tsqr(let n): precondition(n > 0); block = n
        }
        let scale = ww.max()!
        var R = [Float64](), rrows = 0
        var start = 0
        while start < m {
            let size = min(block, m - start), rows = rrows + size
            var C = [Float64](repeating: 0, count: rows * d)
            for j in 0..<d {
                for i in 0..<rrows { C[i + j * rows] = R[i + j * rrows] }
            }
            for l in 0..<size {
                let i = start + l, s = max(xx[i], yy[i])
                if s == 0 || scale == 0 || ww[i] == 0 { continue }
                let a = xx[i] / s, b = yy[i] / s
                let h = hypot(a, b), w = ww[i] / scale
                let θ = 2 * Double.pi * ff[i].truncatingRemainder(dividingBy: 1)
                for k in 0..<max(p, q) {
                    let t = cos(Double(k) * θ)
                    if k < p { C[rrows + l + k * rows] = w * a / h * t }
                    if k < q { C[rrows + l + (p + k) * rows] = -w * b / h * t }
                }
            }
            R = try qrFactor(&C, rows: rows, columns: d)
            rrows = min(rows, d)
            start += size
        }
        return CompressedModel(matrix: R, rows: rrows, count: count, residualScale: scale)
    }

    // GEQRF does not require full rank, unlike a least-squares solve via GELS.
    // Keep all rows of R, including zero/tiny diagonals. Q is never generated.
    private static func qrFactor(_ a: inout [Double], rows: Int, columns: Int) throws -> [Double] {
        var m = __LAPACK_int(rows), n = __LAPACK_int(columns), lda = m
        var tau = [Double](repeating: 0, count: min(rows, columns))
        var query = 0.0, lwork = __LAPACK_int(-1), info = __LAPACK_int(0)
        dgeqrf_(&m, &n, &a, &lda, &tau, &query, &lwork, &info)
        guard info == 0 && query.isFinite && query >= 1 else {
            throw CompressionError.factorizationFailed(Int(info))
        }
        lwork = __LAPACK_int(query)
        var work = [Double](repeating: 0, count: Int(lwork))
        dgeqrf_(&m, &n, &a, &lda, &tau, &work, &lwork, &info)
        guard info == 0 else { throw CompressionError.factorizationFailed(Int(info)) }
        let r = min(rows, columns)
        var result = [Double](repeating: 0, count: r * columns)
        for j in 0..<columns {
            for i in 0..<min(r, j + 1) { result[i + j * r] = a[i + j * rows] }
        }
        return result
    }

    /// Legacy-shaped adapter. Weight now follows the stated residual-weight
    /// convention exactly; the old implementation used sqrt(weight).
    /// Returns identity on an unsuccessful solve; use fitResult/solve for status.
    public static func fit(xx x: some AccelerateBuffer<Double>, yy y: some AccelerateBuffer<Double>,
                           frequency omega: some AccelerateBuffer<Double>, weight: some AccelerateBuffer<Double>,
                           iteration: Int? = nil, barrierFloor: Double = 1e-14,
                           minimum: Double, count: (p: Int, q: Int)) -> Linear.Direct.Power {
        fit(xx: x, yy: y, frequency: omega, weight: weight,
            compression: .tsqr(blockRows: 1024), iteration: iteration,
            barrierFloor: barrierFloor, minimum: minimum, count: count)
    }

    /// Adapter with an explicit compression policy.
    public static func fit(xx x: some AccelerateBuffer<Double>, yy y: some AccelerateBuffer<Double>,
                           frequency omega: some AccelerateBuffer<Double>, weight: some AccelerateBuffer<Double>,
                           compression: Compression, iteration: Int? = nil, barrierFloor: Double = 1e-14,
                           minimum: Double, count: (p: Int, q: Int)) -> Linear.Direct.Power {
        let r = fitResult(xx: x, yy: y, frequency: omega, weight: weight,
                          compression: compression, iteration: iteration, barrierFloor: barrierFloor,
                          minimum: minimum, count: count)
        return r.status == .optimal ? r.power : identity(count)
    }

    public static func fitResult(xx x: some AccelerateBuffer<Double>, yy y: some AccelerateBuffer<Double>,
                                 frequency omega: some AccelerateBuffer<Double>, weight: some AccelerateBuffer<Double>,
                                 iteration: Int? = nil, barrierFloor: Double = 1e-14,
                                 optimalityTolerance: Double = 1e-8,
                                 minimum: Double, count: (p: Int, q: Int)) -> FitResult {
        fitResult(xx: x, yy: y, frequency: omega, weight: weight,
                  compression: .tsqr(blockRows: 1024), iteration: iteration, barrierFloor: barrierFloor,
                  optimalityTolerance: optimalityTolerance, minimum: minimum, count: count)
    }

    public static func fitResult(xx x: some AccelerateBuffer<Double>, yy y: some AccelerateBuffer<Double>,
                                 frequency omega: some AccelerateBuffer<Double>, weight: some AccelerateBuffer<Double>,
                                 compression: Compression, iteration: Int? = nil, barrierFloor: Double = 1e-14,
                                 optimalityTolerance: Double = 1e-8,
                                 minimum: Double, count: (p: Int, q: Int)) -> FitResult {
        do {
            let model = try compress(xx: x, yy: y, frequency: omega, weight: weight,
                                     count: count, compression: compression)
            return solve(model, iteration: iteration, barrierFloor: barrierFloor,
                         optimalityTolerance: optimalityTolerance, minimum: minimum)
        } catch {
            return FitResult(power: identity(count), status: .numericalFailure, iterations: 0,
                             objective: .infinity, dualLowerBound: 0, dualityGap: .infinity,
                             equalityResidual: 0, stationarityResidual: .infinity,
                             barrierWeight: 0, residualScale: 1)
        }
    }

    private static func identity(_ count: (p: Int, q: Int)) -> Linear.Direct.Power {
        var p = [Double](repeating: 0, count: count.p + 1)
        var q = [Double](repeating: 0, count: count.q + 1)
        p[0] = 1; q[0] = 1
        return .init(raw: (p, q))
    }

    /// Solve only the normalized residual factor, independent of compression.
    /// Exact Riesz–Fejér cones, p₀+q₀=2, P,Q >= minimum; no ridge.
    /// Newton steps use Cholesky whitening, exact equality elimination, and a
    /// thin SVD of the residual operator. No lifted N×N Hessian is formed and
    /// no singular values are truncated. The SVD avoids squaring its condition
    /// number in a Woodbury Schur matrix. All loops have finite budgets.
    public static func solve(_ model: CompressedModel, iteration: Int? = nil,
                             barrierFloor: Double = 1e-14, optimalityTolerance: Double = 1e-8,
                             minimum ε: Double) -> FitResult {
        precondition(ε.isFinite && ε > 0 && ε < 1)
        precondition(barrierFloor.isFinite && barrierFloor > 0 && barrierFloor <= 1)
        precondition(optimalityTolerance.isFinite && optimalityTolerance > 0)
        precondition(iteration == nil || iteration! >= 0)
        let p = model.count.p + 1, q = model.count.q + 1, d = p + q
        let R = model.matrix, m = model.rows
        let sizes = [p, q], bases = [0, p]
        let ns = [p * (p + 1) / 2, q * (q + 1) / 2]
        let offsets = [0, ns[0]], N = ns[0] + ns[1], k = N - 1
        let β = 2 - 2 * ε, root2 = Double(2).squareRoot()
        var G = sizes.map { n -> [Double] in
            var g = [Double](repeating: 0, count: n*n)
            for i in 0..<n { g[i + i*n] = (1-ε)/Double(n) }
            return g
        }
        func coefficients(_ g: [[Double]]) -> [Double] {
            var c = [Double](repeating: 0, count: d)
            for b in 0..<2 {
                let n = sizes[b], base = bases[b]
                c[base] = ε
                for j in 0..<n {
                    c[base] += g[b][j+j*n]
                    for i in 0..<j { c[base+j-i] += 2*g[b][i+j*n] }
                }
            }
            return c
        }
        func adjoint(_ v: [Double], _ b: Int) -> [Double] {
            let n = sizes[b], base = bases[b]
            return (0..<n*n).map { v[base + abs($0 % n - $0 / n)] }
        }
        func data(_ g: [[Double]]) -> (Double, [Double], [Double]) {
            let c = coefficients(g)
            var r = [Double](repeating: 0, count: m)
            var v = [Double](repeating: 0, count: d)
            gemv(m, d, 1, R, m, .N, c, 1, 0, &r, 1)
            gemv(m, d, 1, R, m, .T, r, 1, 0, &v, 1)
            return (0.5*dot(m, r, 1, r, 1), r, v)
        }
        func factors(_ g: [[Double]]) -> ([[Double]], Double)? {
            var l = g, ld = 0.0
            for b in 0..<2 {
                let n = sizes[b]
                guard potrf(n, &l[b], n, .L) == 0 else { return nil }
                for j in 0..<n {
                    ld += 2*log(l[b][j+j*n])
                    for i in 0..<j { l[b][i+j*n] = 0 }
                }
            }
            return ld.isFinite ? (l, ld) : nil
        }
        func trace(_ g: [[Double]]) -> Double {
            (0..<2).reduce(0) { total, b in
                total + (0..<sizes[b]).reduce(0) { $0 + g[b][$1+$1*sizes[b]] }
            }
        }
        func whiten(_ c: [Double], _ l: [[Double]]) -> [Double] {
            var v = [Double](repeating: 0, count: N)
            for b in 0..<2 {
                let n = sizes[b], C = adjoint(c, b)
                var temp = [Double](repeating: 0, count: n*n)
                var F = temp
                gemm(n, n, n, 1, C, n, .N, l[b], n, .N, 0, &temp, n)
                gemm(n, n, n, 1, l[b], n, .T, temp, n, .N, 0, &F, n)
                var t = offsets[b]
                for j in 0..<n {
                    for i in 0...j { v[t] = F[i+j*n] * (i == j ? 1 : root2); t += 1 }
                }
            }
            return v
        }
        func unwhiten(_ v: [Double], _ l: [[Double]]) -> [[Double]] {
            (0..<2).map { b in
                let n = sizes[b]
                var S = [Double](repeating: 0, count: n*n), t = offsets[b]
                for j in 0..<n {
                    for i in 0...j {
                        let x = v[t] / (i == j ? 1 : root2)
                        S[i+j*n] = x; S[j+i*n] = x; t += 1
                    }
                }
                var temp = S, out = S
                gemm(n, n, n, 1, l[b], n, .N, S, n, .N, 0, &temp, n)
                gemm(n, n, n, 1, temp, n, .N, l[b], n, .T, 0, &out, n)
                // Restore symmetry after floating-point products.
                for j in 0..<n { for i in 0..<j {
                    let x = 0.5*(out[i+j*n]+out[j+i*n])
                    out[i+j*n] = x; out[j+i*n] = x
                }}
                return out
            }
        }
        var e = [Double](repeating: 0, count: N)
        for b in 0..<2 {
            var t = offsets[b]
            for j in 0..<sizes[b] { t += j; e[t] = 1; t += 1 }
        }
        let scale = R.reduce(0) { $0 + $1*$1 } / Double(d)
        if scale == 0 {
            return FitResult(power: identity(model.count), status: .optimal, iterations: 0,
                             objective: 0, dualLowerBound: 0, dualityGap: 0, equalityResidual: 0,
                             stationarityResidual: 0, barrierWeight: 0, residualScale: model.residualScale)
        }
        let floor = max(Double.leastNormalMagnitude, barrierFloor*scale)
        var μ = scale, steps = 0, reachedFloor = false, exhausted = false
        var stationarity = Double.infinity
        let budget = iteration ?? 2048
        path: for _ in 0..<256 {
            for _ in 0..<64 {
                if steps >= budget { exhausted = true; break path }
                steps += 1
                guard let (l, ld) = factors(G) else { break path }
                let (f, residual, _) = data(G)
                let current = f - μ*ld
                // Whiten ΔG=L S Lᵀ: barrier Hessian becomes μ I.
                var acoeff = [Double](repeating: 0, count: d)
                acoeff[0] = 1; acoeff[p] = 1
                let a = whiten(acoeff, l)
                let anorm = a.reduce(0) { hypot($0, $1) }
                guard anorm > 0 && anorm.isFinite else { break path }
                // Householder eliminates the trace equality exactly before SVD.
                var house = a
                let alpha = a[0] >= 0 ? -anorm : anorm
                house[0] -= alpha
                let hn = house.reduce(0) { hypot($0, $1) }
                for i in 0..<N { house[i] /= hn }
                func reflect(_ v: [Double]) -> [Double] {
                    let h = 2*dot(N, house, 1, v, 1)
                    return (0..<N).map { v[$0] - h*house[$0] }
                }
                let er = reflect(e)
                var V = [Double](repeating: 0, count: m*k)
                var first = [Double](repeating: 0, count: m)
                for i in 0..<m {
                    let row = (0..<d).map { R[i+$0*m] }
                    let v = reflect(whiten(row, l))
                    first[i] = v[0]
                    for j in 0..<k { V[i+j*m] = v[j+1] }
                }
                let fixed = (β-trace(G))/alpha
                let r = (0..<m).map { residual[$0] + fixed*first[$0] }
                let rank = min(m, k)
                var singular = [Double](repeating: 0, count: rank)
                var U = [Double](repeating: 0, count: m*rank)
                var VT = [Double](repeating: 0, count: rank*k)
                let workspace = gesvd(m, k, &V, m, &singular, &U, m, &VT, rank,
                                      nil as UnsafeMutablePointer<Double>?, 0)
                guard workspace > 0 else { break path }
                var work = [Double](repeating: 0, count: workspace)
                guard gesvd(m, k, &V, m, &singular, &U, m, &VT, rank, &work, work.count) == 0 else {
                    break path
                }
                // In the orthogonal complement the Newton step equals e.
                // In each retained singular direction solve (μ+σ²)s=μe-σr.
                // All singular values, including zeros, are retained.
                let ered = Array(er.dropFirst())
                var ep = [Double](repeating: 0, count: rank)
                var rp = ep
                gemv(rank, k, 1, VT, rank, .N, ered, 1, 0, &ep, 1)
                gemv(m, rank, 1, U, m, .T, r, 1, 0, &rp, 1)
                var adjustment = ep
                for j in 0..<rank {
                    let s = singular[j]
                    adjustment[j] = (μ*ep[j]-s*rp[j])/(μ+s*s)-ep[j]
                }
                var reduced = ered
                gemv(rank, k, 1, VT, rank, .T, adjustment, 1, 1, &reduced, 1)
                let stepWhite = reflect([fixed] + reduced)
                let direction = unwhiten(stepWhite, l)
                var dc = coefficients(direction)
                dc[0] -= ε; dc[p] -= ε
                var dr = [Double](repeating: 0, count: m)
                gemv(m, d, 1, R, m, .N, dc, 1, 0, &dr, 1)
                let slope = dot(m, residual, 1, dr, 1) - μ*dot(N, e, 1, stepWhite, 1)
                let decrement = -slope
                stationarity = max(0, decrement).squareRoot()
                guard decrement.isFinite else { break path }
                if decrement <= max(1e-28*scale, 1e-6*μ) { break }
                var step = 1.0, accepted = false
                for _ in 0..<53 {
                    var candidate = G
                    for b in 0..<2 {
                        for i in candidate[b].indices { candidate[b][i] += step*direction[b][i] }
                    }
                    let tr = trace(candidate)
                    if tr > 0 && tr.isFinite {
                        for b in 0..<2 { for i in candidate[b].indices { candidate[b][i] *= β/tr } }
                        if let (_, logdet) = factors(candidate) {
                            let (value, _, _) = data(candidate)
                            if value-μ*logdet <= current+0.01*step*slope {
                                G = candidate; accepted = true; break
                            }
                        }
                    }
                    step *= 0.5
                }
                if !accepted { break }
            }
            if μ <= floor { reachedFloor = true; break }
            μ = max(0.05*μ, floor)
        }
        let (value, _, gradient) = data(G)
        var minEigen = Double.infinity, margin = 0.0, eigenOK = true
        var supporting = 0.0
        for b in 0..<2 {
            let n = sizes[b]
            var C = adjoint(gradient, b)
            supporting += dot(n*n, C, 1, G[b], 1)
            margin = max(margin, 128*Double.ulpOfOne*Double(n)*(C.map(abs).max() ?? 0))
            var eig = [Double](repeating: 0, count: n)
            var work = [Double](repeating: 0, count: max(1, 3*n))
            if syev(n, &C, n, .L, false, &eig, &work, work.count) != 0 || !eig.allSatisfy(\.isFinite) {
                eigenOK = false; break
            }
            minEigen = min(minEigen, eig[0])
        }
        let lower = eigenOK ? max(0, value-supporting-(-minEigen+margin)*β) : 0
        let gap = max(0, value-lower), equality = abs(trace(G)-β)
        // Report central KKT stationarity at the returned iterate, not a
        // Newton decrement from an earlier iterate.
        if var (l, _) = factors(G) {
            var central = [[Double]]()
            var diagonalSum = 0.0
            var valid = true
            for b in 0..<2 {
                let n = sizes[b]
                var inverse = [Double](repeating: 0, count: n*n)
                for i in 0..<n { inverse[i+i*n] = 1 }
                if potrs(n, n, &l[b], n, .L, &inverse, n) != 0 { valid = false; break }
                let C = adjoint(gradient, b)
                let z = (0..<n*n).map { C[$0]-μ*inverse[$0] }
                diagonalSum += (0..<n).reduce(0) { $0+z[$1+$1*n] }
                central.append(z)
            }
            if valid {
                let multiplier = -diagonalSum/Double(d)
                stationarity = 0
                for b in 0..<2 {
                    let n = sizes[b]
                    for j in 0..<n { for i in 0..<n {
                        stationarity = max(stationarity, abs(central[b][i+j*n]+(i == j ? multiplier : 0)))
                    }}
                }
            }
        }
        let feasible = factors(G) != nil && equality <= 1e-10 && value.isFinite
        let status: FitStatus
        if reachedFloor && feasible && eigenOK && gap <= optimalityTolerance*max(1, value) {
            status = .optimal
        } else if exhausted { status = .iterationLimit }
        else { status = .numericalFailure }
        let c = coefficients(G)
        return FitResult(power: .init(raw: (Array(c.prefix(p)), Array(c.suffix(q)))),
                         status: status, iterations: steps, objective: value,
                         dualLowerBound: lower, dualityGap: gap, equalityResidual: equality,
                         stationarityResidual: stationarity, barrierWeight: μ,
                         residualScale: model.residualScale)
    }
}
