//
//  Linear+Fit+Positive.swift
//  MUTE
//
import func BLAS.copy
import func BLAS.dot
import func BLAS.gemv
import func Darwin.memmove
import func LAPACK.gels
import func LAPACK.gglse
import typealias Accelerate.vDSP

extension Linear {
    /// Outer exchange method for the semi-infinite positive Power Fit problem.
    ///
    /// It minimizes `‖Mθ‖²` subject to `p[0] + q[0] = 2` and
    /// `P(t), Q(t) ≥ minimum` for every `t ∈ [-1, 1]`. Each iteration solves the
    /// currently finite constraint set, locates the global minima of `P` and `Q`,
    /// and appends a violated evaluation constraint. Adapters only have to construct
    /// the column-major `rowCount × (count.b + count.a + 2)` matrix `design = M`.
    /// `duplicateTolerance` only identifies numerically coincident cutting planes;
    /// it does not relax the requested lower bound `minimum`.
    @inlinable
    static func fit(design: UnsafeBufferPointer<Float64>,
                    rowCount: Int,
                    minimum: Float64,
                    duplicateTolerance: Float64 = 16384 * Float64.ulpOfOne,
                    feasibilityTolerance: Float64 = 4096 * Float64.ulpOfOne,
                    multiplierTolerance: Float64 = 4096 * Float64.ulpOfOne,
                    count: (b: Int, a: Int)) -> Direct.ChebyshevPowerRational {
        assert(0 <= count.b)
        assert(0 <= count.a)
        assert(minimum.isFinite && 0 < minimum && minimum < 1)
        assert(duplicateTolerance.isFinite && 0 < duplicateTolerance)
        assert(feasibilityTolerance.isFinite && 0 < feasibilityTolerance)
        assert(multiplierTolerance.isFinite && 0 < multiplierTolerance)
        let pCount = count.b + 1
        let qCount = count.a + 1
        let n = pCount + qCount
        assert(n <= rowCount + 1)
        assert(design.count == rowCount * n)
        let exchangeLimit = max(32, 4 * n)
        let constraintCapacity = 2 * exchangeLimit
        return withUnsafeTemporaryAllocation(of: Float64.self,
                                             capacity: constraintCapacity * n + 4 * n) { memory in
            memory.initialize(repeating: 0)
            let constraints = UnsafeMutableBufferPointer(rebasing: memory[0 ..< constraintCapacity * n])
            let vectorStart = constraintCapacity * n
            let current = UnsafeMutableBufferPointer(rebasing: memory[vectorStart + 0 * n ..< vectorStart + 1 * n])
            let candidate = UnsafeMutableBufferPointer(rebasing: memory[vectorStart + 1 * n ..< vectorStart + 2 * n])
            let direction = UnsafeMutableBufferPointer(rebasing: memory[vectorStart + 2 * n ..< vectorStart + 3 * n])
            let multipliers = UnsafeMutableBufferPointer(rebasing: memory[vectorStart + 3 * n ..< vectorStart + 4 * n])
            assert(current.count == pCount + qCount)
            return withUnsafeTemporaryAllocation(of: Int.self, capacity: n) { active in
                active.initialize(repeating: -1)
                var constraintCount = 0
                for () in repeatElement((), count: exchangeLimit) {
                    // Inner active-set solve for the finite constraints collected so far.
                    solveWorkingSet(design: design,
                                    rowCount: rowCount,
                                    pCount: pCount,
                                    minimum: minimum,
                                    constraints: constraints,
                                    constraintCount: constraintCount,
                                    current: current,
                                    candidate: candidate,
                                    direction: direction,
                                    multipliers: multipliers,
                                    active: active,
                                    feasibilityTolerance: feasibilityTolerance,
                                    multiplierTolerance: multiplierTolerance)
                    let p = Direct.ChebyshevPolynomial(Array(current.prefix(pCount)))
                    let q = Direct.ChebyshevPolynomial(Array(current.suffix(qCount)))

                    let pMinimum = p.minimum
                    let qMinimum = q.minimum
                    let pIsFeasible = minimum <= pMinimum.value
                    let qIsFeasible = minimum <= qMinimum.value
                    if pIsFeasible && qIsFeasible {
                        return.init(raw: (p, q))
                    }
                    // Separation step: turn each violated interval minimum into a row
                    // constraint for the next finite QP.
                    let pConstraintStart = constraintCount * n
                    let pAppended = !pIsFeasible && appendConstraint(
                        at: pMinimum.location,
                        row: .init(rebasing: constraints[pConstraintStart ..< pConstraintStart + n]),
                        coefficients: 0..<pCount,
                        existing: .init(rebasing: constraints[0..<pConstraintStart]),
                        tolerance: duplicateTolerance
                    )
                    constraintCount += pAppended ? 1 : 0
                    let qConstraintStart = constraintCount * n
                    let qAppended = !qIsFeasible && appendConstraint(
                        at: qMinimum.location,
                        row: .init(rebasing: constraints[qConstraintStart ..< qConstraintStart + n]),
                        coefficients: pCount..<n,
                        existing: .init(rebasing: constraints[0..<qConstraintStart]),
                        tolerance: duplicateTolerance
                    )
                    constraintCount += qAppended ? 1 : 0
                    precondition(pAppended || qAppended, "positive Power Fit exchange stalled")
                }
                preconditionFailure("positive Power Fit exchange did not converge")
            }
        }
    }

    /// Primal solve for one active set in the inner working-set algorithm.
    ///
    /// GGLSE minimizes `‖Mθ‖²` while enforcing the scale normalization and every
    /// currently active positivity constraint as an equality. The resulting
    /// unconstrained candidate is then passed to `recoverMultipliers` for the dual
    /// feasibility test used by `solveWorkingSet`.
    @inlinable
    static func equalitySolution(design: UnsafeBufferPointer<Float64>,
                                 rowCount: Int,
                                 pCount: Int,
                                 minimum: Float64,
                                 constraints: UnsafeMutableBufferPointer<Float64>,
                                 candidate: UnsafeMutableBufferPointer<Float64>,
                                 multipliers: UnsafeMutableBufferPointer<Float64>,
                                 active: UnsafeMutableBufferPointer<Int>,
                                 activeCount: Int) {
        let n = candidate.count
        let equalityCount = 1 + activeCount
        assert(equalityCount <= n)
        let workspaceCount = gglse(rowCount, n, equalityCount,
                                   .none as Optional<UnsafeMutablePointer<Float64>>, rowCount,
                                   .none, equalityCount,
                                   .none, .none, .none,
                                   .none, 0)
        precondition(0 < workspaceCount)
        withUnsafeTemporaryAllocation(of: Float64.self,
                                      capacity: rowCount * n + equalityCount * n + rowCount + equalityCount + workspaceCount) { storage in
            storage.initialize(repeating: 0)
            let matrix = UnsafeMutableBufferPointer(rebasing: storage[0 ..< rowCount * n])
            let equalityStart = rowCount * n
            let equality = UnsafeMutableBufferPointer(rebasing: storage[equalityStart ..< equalityStart + equalityCount * n])
            let observationStart = equalityStart + equalityCount * n
            let observation = UnsafeMutableBufferPointer(rebasing: storage[observationStart ..< observationStart + rowCount])
            let targetStart = observationStart + rowCount
            let target = UnsafeMutableBufferPointer(rebasing: storage[targetStart ..< targetStart + equalityCount])
            let workspace = UnsafeMutableBufferPointer(rebasing: storage.suffix(workspaceCount))
            copy(rowCount * n, design.baseAddress.unsafelyUnwrapped, 1,
                 matrix.baseAddress.unsafelyUnwrapped, 1)
            equality[0] = 1
            equality[pCount * equalityCount] = 1
            for row in 0..<activeCount {
                copy(n,
                     constraints.baseAddress.unsafelyUnwrapped.advanced(by: active[row] * n), 1,
                     equality.baseAddress.unsafelyUnwrapped.advanced(by: row + 1), equalityCount)
            }
            target.update(repeating: minimum)
            target[0] = 2
            let info = gglse(rowCount, n, equalityCount,
                             matrix.baseAddress, rowCount,
                             equality.baseAddress, equalityCount,
                             observation.baseAddress, target.baseAddress, candidate.baseAddress,
                             workspace.baseAddress, workspace.count)
            precondition(info == 0, "positive Power Fit equality-constrained solve failed")
        }

        recoverMultipliers(design: design,
                           rowCount: rowCount,
                           pCount: pCount,
                           constraints: constraints,
                           candidate: candidate,
                           multipliers: multipliers,
                           active: active,
                           activeCount: activeCount)
    }

    /// Recovers the KKT multipliers after `equalitySolution` computes a candidate.
    ///
    /// It forms `-MᵀMθ` and solves `C_Wᵀλ = -MᵀMθ`, where `C_W` contains the
    /// normalization row followed by active constraint rows. With the sign convention
    /// used here, an active inequality requires a non-positive multiplier; a positive
    /// multiplier tells `solveWorkingSet` which constraint should leave the active set.
    @inlinable
    static func recoverMultipliers(design: UnsafeBufferPointer<Float64>,
                                   rowCount: Int,
                                   pCount: Int,
                                   constraints: UnsafeMutableBufferPointer<Float64>,
                                   candidate: UnsafeMutableBufferPointer<Float64>,
                                   multipliers: UnsafeMutableBufferPointer<Float64>,
                                   active: UnsafeMutableBufferPointer<Int>,
                                   activeCount: Int) {
        let n = candidate.count
        let equalityCount = 1 + activeCount
        let rhsCount = max(n, equalityCount)
        let workspaceCount = gels(n, equalityCount, 1,
                                  .none, n, .N,
                                  .none, rhsCount,
                                  .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        precondition(0 < workspaceCount)
        withUnsafeTemporaryAllocation(of: Float64.self,
                                      capacity: rowCount + n * equalityCount + rhsCount + workspaceCount) { storage in
            storage.initialize(repeating: 0)
            let residual = UnsafeMutableBufferPointer(rebasing: storage[0..<rowCount])
            let matrixStart = rowCount
            let matrix = UnsafeMutableBufferPointer(rebasing: storage[matrixStart ..< matrixStart + n * equalityCount])
            let rhsStart = matrixStart + n * equalityCount
            let rhs = UnsafeMutableBufferPointer(rebasing: storage[rhsStart ..< rhsStart + rhsCount])
            let workspace = UnsafeMutableBufferPointer(rebasing: storage.suffix(workspaceCount))
            gemv(rowCount, n, 1,
                 design.baseAddress.unsafelyUnwrapped, rowCount, .N,
                 candidate.baseAddress.unsafelyUnwrapped, 1,
                 0,
                 residual.baseAddress.unsafelyUnwrapped, 1)
            gemv(rowCount, n, -1,
                 design.baseAddress.unsafelyUnwrapped, rowCount, .T,
                 residual.baseAddress.unsafelyUnwrapped, 1,
                 0,
                 rhs.baseAddress.unsafelyUnwrapped, 1)
            matrix[0] = 1
            matrix[pCount] = 1
            for column in 0..<activeCount {
                copy(n,
                     constraints.baseAddress.unsafelyUnwrapped.advanced(by: active[column] * n), 1,
                     matrix.baseAddress.unsafelyUnwrapped.advanced(by: (column + 1) * n), 1)
            }
            let info = gels(n, equalityCount, 1,
                            matrix.baseAddress, n, .N,
                            rhs.baseAddress, rhsCount,
                            workspace.baseAddress, workspace.count)
            precondition(info == 0, "positive Power Fit multiplier solve failed")
            copy(equalityCount, rhs.baseAddress.unsafelyUnwrapped, 1,
                 multipliers.baseAddress.unsafelyUnwrapped, 1)
        }
    }

    /// Inner primal active-set method for the finite QP produced by the exchange method.
    ///
    /// It starts from the feasible normalized point `p[0] = q[0] = 1`. If the
    /// equality-constrained candidate crosses an inactive constraint, a line search
    /// stops at the first blocking constraint and activates it. Once the full step is
    /// feasible, the recovered KKT multipliers either remove a dual-infeasible active
    /// constraint or certify the solution of the current finite QP.
    @inlinable
    static func solveWorkingSet(design: UnsafeBufferPointer<Float64>,
                                rowCount: Int,
                                pCount: Int,
                                minimum: Float64,
                                constraints: UnsafeMutableBufferPointer<Float64>,
                                constraintCount: Int,
                                current: UnsafeMutableBufferPointer<Float64>,
                                candidate: UnsafeMutableBufferPointer<Float64>,
                                direction: UnsafeMutableBufferPointer<Float64>,
                                multipliers: UnsafeMutableBufferPointer<Float64>,
                                active: UnsafeMutableBufferPointer<Int>,
                                feasibilityTolerance: Float64,
                                multiplierTolerance: Float64) {
        let n = current.count
        current.update(repeating: 0)
        current[0] = 1
        current[pCount] = 1
        var activeCount = 0
        let limit = max(64, 8 * (n + constraintCount))
        for () in repeatElement((), count: limit) {
            equalitySolution(design: design,
                             rowCount: rowCount,
                             pCount: pCount,
                             minimum: minimum,
                             constraints: constraints,
                             candidate: candidate,
                             multipliers: multipliers,
                             active: active,
                             activeCount: activeCount)
            vDSP.subtract(candidate, current, result: &direction[0..<n])
            // Primal feasibility: find the first inactive boundary hit along the step.
            let blocking = (0..<constraintCount).lazy.compactMap { index -> Optional<(index: Int, step: Float64)> in
                guard !active[0..<activeCount].contains(index) else { return nil }
                let row = constraints.baseAddress.unsafelyUnwrapped.advanced(by: index * n)
                let slope = dot(n, row, 1, direction.baseAddress.unsafelyUnwrapped, 1)
                guard slope < -feasibilityTolerance else { return nil }
                let slack = dot(n, row, 1, current.baseAddress.unsafelyUnwrapped, 1) - minimum
                let step = max(0, slack) / -slope
                guard step < 1 else { return nil }
                return.some((index, step))
            }.min {
                $0.step < $1.step
            }
            if let blocking, blocking.step + feasibilityTolerance < 1 {
                vDSP.add(multiplication: (direction, blocking.step),
                         current,
                         result: &current[0..<n])
                assert(activeCount < n - 1)
                active[activeCount] = blocking.index
                activeCount += 1
                continue
            }
            copy(n, candidate.baseAddress.unsafelyUnwrapped, 1,
                 current.baseAddress.unsafelyUnwrapped, 1)
            // Dual feasibility: positive multipliers violate the sign convention.
            let removal = (0..<activeCount).lazy.filter {
                multiplierTolerance < multipliers[$0 + 1]
            }.max {
                multipliers[$0 + 1] < multipliers[$1 + 1]
            }
            if let removal {
                let remainingCount = activeCount - removal - 1
                _ = memmove(active.baseAddress.unsafelyUnwrapped.advanced(by: removal),
                            active.baseAddress.unsafelyUnwrapped.advanced(by: removal + 1),
                            remainingCount * MemoryLayout<Int>.stride)
                activeCount -= 1
                continue
            }
            return
        }
        preconditionFailure("positive Power Fit working set did not converge")
    }

    /// Adds the cutting plane produced by the outer exchange method's separation step.
    ///
    /// At a violating location `t`, `P(t) ≥ minimum` or `Q(t) ≥ minimum` is linear
    /// in the coefficient vector. This routine materializes its Chebyshev evaluation
    /// row `[T₀(t), …, Tₙ(t)]` in the caller-selected coefficient block and
    /// returns whether the caller should commit it by incrementing `constraintCount`.
    /// A numerically duplicate row is left uncommitted to detect a stalled exchange.
    @inlinable
    static func appendConstraint(at t: Float64,
                                 row: UnsafeMutableBufferPointer<Float64>,
                                 coefficients: Range<Int>,
                                 existing: UnsafeBufferPointer<Float64>,
                                 tolerance: Float64) -> Bool {
        assert(!row.isEmpty)
        assert(!coefficients.isEmpty)
        assert(row.indices.contains(coefficients.lowerBound))
        assert(coefficients.upperBound <= row.count)
        assert(existing.count.isMultiple(of: row.count))
        vDSP.clear(&row[0..<row.count])
        Direct.ChebyshevPolynomial.basis(
            degree: coefficients.count - 1,
            at: t,
            result: .init(rebasing: row[coefficients])
        )

        let isDuplicate = stride(from: 0, to: existing.count, by: row.count).contains {
            existing[$0..<$0 + row.count].elementsEqual(row) {
                ($0 - $1).magnitude <= tolerance
            }
        }
        guard !isDuplicate else { return false }
        return true
    }
}
