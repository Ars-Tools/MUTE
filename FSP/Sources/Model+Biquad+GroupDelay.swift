//
//  Model+Biquad+GroupDelay.swift
//  MUTE
//
//  Created by Kota on 10/8/26.
//
import func Darwin.cos
import func simd.fma

extension Model.Biquad {
    /// Group delay in samples. Isolated unit-circle singularities are evaluated
    /// by their continuous limits (the phase itself is undefined there).
    public struct GroupDelay {
        @usableFromInline let numerator: Section
        @usableFromInline let denominator: Section
    }

    @inlinable
    public var groupDelay: GroupDelay {
        .init(b: b, a: a)
    }
}

extension Model.Biquad.GroupDelay {
    @inlinable
    init(b: SIMD3<Float64>, a: SIMD3<Float64>) {
        numerator = .init(b)
        denominator = .init(a)
    }

    /// Evaluate at angular frequency ω in radians/sample.
    @inlinable
    public func callAsFunction(_ ω: Float64) -> Float64 {
        self[cos(ω)]
    }

    /// Evaluate at x = cos(ω), with -1 ≤ x ≤ 1.
    @inlinable
    public subscript(x: Float64) -> Float64 {
        guard (-1...1).contains(x) else { return .nan }
        return numerator(x) - denominator(x)
    }

    /// Uniform-frequency mean: (1 / 2π) ∫[-π, π] τ(ω) dω.
    /// Each zero outside the unit circle contributes one sample; each zero
    /// on it contributes half a sample under the continuous-limit convention.
    @inlinable
    public var μ: Float64 {
        numerator.mean - denominator.mean
    }

    /// Isolated stationary points in x = cos(ω). A constant response returns [].
    public var `stationary-points`: Array<Float64> {
        guard μ.isFinite else { return [] }
        // d(N/Q)/dx = (N'Q - NQ') / Q².
        // Cross-multiplying the two sections gives a polynomial of degree ≤ 6.
        let b = numerator, a = denominator
        let db = Self.derivativeNumerator(b.p, b.q)
        let da = Self.derivativeNumerator(a.p, a.q)
        let lhs = Self.product(db, Self.product(a.q, a.q))
        let rhs = Self.product(da, Self.product(b.q, b.q))
        return Self.roots(zip(lhs, rhs).map { $0 - $1 })
            .filter { -1 < $0 && $0 < 1 }
    }

    /// Endpoints and stationary points, matching Power's extrema candidates.
    public var `extrema?`: Array<Float64> {
        [-1, 1] + `stationary-points`
    }

    /// Nil for an identically zero or nonfinite numerator/denominator.
    public var range: ClosedRange<Float64>? {
        guard μ.isFinite else { return nil }
        var lower = Float64.infinity, upper = -Float64.infinity
        for x in `extrema?` {
            let value = self[x]
            guard value.isFinite else { return nil }
            lower = Swift.min(lower, value)
            upper = Swift.max(upper, value)
        }
        return lower...upper
    }

    public var min: Float64 { range?.lowerBound ?? .nan }
    public var max: Float64 { range?.upperBound ?? .nan }
}

extension Model.Biquad.GroupDelay {
    @usableFromInline
    struct Section {
        @usableFromInline let w: SIMD3<Float64>
        @usableFromInline let p: SIMD3<Float64>
        @usableFromInline let q: SIMD3<Float64>
        @usableFromInline let offset: Float64
        @usableFromInline let mean: Float64

        @inlinable
        init(_ coefficients: SIMD3<Float64>) {
            let scale = Swift.max(coefficients.x.magnitude,
                                  Swift.max(coefficients.y.magnitude, coefficients.z.magnitude))
            guard scale > 0, scale.isFinite,
                  coefficients.x.isFinite, coefficients.y.isFinite, coefficients.z.isFinite else {
                w = .init(repeating: .nan)
                p = .init(repeating: .nan)
                q = .init(repeating: .nan)
                offset = .nan
                mean = .nan
                return
            }
            var w = coefficients / scale
            var delay = 0.0
            // Explicit z⁻¹ factors are pure delays.
            while w.x.isZero {
                w = .init(w.y, w.z, 0)
                delay += 1
            }
            // Remove real unit-circle factors. Their regular group delay is 1/2.
            while (w.x + w.y + w.z).isZero || (w.x - w.y + w.z).isZero {
                let positive = (w.x + w.y + w.z).isZero
                w = .init(w.x, positive ? -w.z : w.z, 0)
                delay += 0.5
            }
            // Symmetric second-order FIRs have constant delay, including their
            // conjugate unit-circle zeros; avoid a removable 0/0 in N/Q.
            if w.x == w.z {
                self.w = .init(1, 0, 0)
                p = .zero
                q = .init(1, 0, 0)
                offset = delay + 1
                mean = delay + 1
                return
            }
            self.w = w
            // For W = w₀ + w₁z⁻¹ + w₂z⁻² and x = cos(ω):
            // τW = Re((w₁z⁻¹ + 2w₂z⁻²)/W) = N(x)/Q(x).
            let t = w.x * w.z
            p = .init(fma(-2, t, fma(2, w.z * w.z, w.y * w.y)),
                      w.y * (w.x + 3 * w.z), 4 * t)
            q = .init(fma(-2, t, fma(w.x, w.x, fma(w.y, w.y, w.z * w.z))),
                      2 * w.y * (w.x + w.z), 4 * t)
            offset = delay
            // The frequency integral counts zeros of w₀z² + w₁z + w₂
            // outside |z| = 1. The z = 0 padding root contributes nothing.
            let discriminant = fma(-4 * w.x, w.z, w.y * w.y)
            if discriminant < 0 {
                let radiusSquared = w.z / w.x
                mean = delay + (radiusSquared < 1 ? 0 : radiusSquared > 1 ? 2 : 1)
            } else {
                let r = -0.5 * (w.y + (w.y < 0 ? -1 : 1) * discriminant.squareRoot())
                let z₁ = r / w.x
                let z₂ = r.isZero ? 0 : w.z / r
                mean = delay + Self.contribution(z₁) + Self.contribution(z₂)
            }
        }

        @inlinable
        static func contribution(_ root: Float64) -> Float64 {
            root.magnitude < 1 ? 0 : root.magnitude > 1 ? 1 : 0.5
        }

        @inlinable
        func callAsFunction(_ x: Float64) -> Float64 {
            // Rotate W by e^{jω} and form |W|² as a sum of squares.
            // Expanding Q(x) directly loses precision near unit-circle roots.
            let real = fma(w.x + w.z, x, w.y)
            let difference = w.x - w.z
            let sineSquared = (1 - x) * (1 + x)
            let power = fma(difference, difference * sineSquared, real * real)
            let rampReal = fma(2 * w.z, x, w.y)
            let rampProduct = fma(rampReal, real, -2 * w.z * difference * sineSquared)
            return offset + rampProduct / power
        }
    }

    private static func derivativeNumerator(_ p: SIMD3<Float64>, _ q: SIMD3<Float64>) -> [Float64] {
        [fma(p.y, q.x, -p.x * q.y),
         2 * fma(p.z, q.x, -p.x * q.z),
         fma(p.z, q.y, -p.y * q.z)]
    }

    private static func product(_ p: SIMD3<Float64>, _ q: SIMD3<Float64>) -> [Float64] {
        product([p.x, p.y, p.z], [q.x, q.y, q.z])
    }

    private static func product(_ p: [Float64], _ q: [Float64]) -> [Float64] {
        var result = Array(repeating: 0.0, count: p.count + q.count - 1)
        for i in p.indices {
            for j in q.indices {
                result[i + j] = fma(p[i], q[j], result[i + j])
            }
        }
        return result
    }

    /// Isolate real roots on [-1, 1] by recursively finding derivative roots.
    /// Every resulting interval is monotone, so bisection cannot skip a pair
    /// of nearby roots; checking its boundaries also includes repeated roots.
    private static func roots(_ coefficients: [Float64]) -> [Float64] {
        var p = coefficients
        while p.last == 0 { p.removeLast() }
        guard p.count > 1 else { return [] }
        let scale = p.map(\.magnitude).max()!
        guard scale.isFinite else { return [] }
        p = p.map { $0 / scale }
        if p.count == 2 {
            let x = -p[0] / p[1]
            return (-1...1).contains(x) ? [x] : []
        }
        let derivative = (1..<p.count).map { Float64($0) * p[$0] }
        let boundaries = [-1.0] + roots(derivative).filter { -1 < $0 && $0 < 1 } + [1.0]
        func evaluate(_ x: Float64) -> Float64 {
            p.reversed().reduce(0) { fma($0, x, $1) }
        }
        let tolerance = 64 * Float64.ulpOfOne * p.reduce(0) { $0 + $1.magnitude }
        var result = boundaries.filter { evaluate($0).magnitude <= tolerance }
        for (left, right) in zip(boundaries, boundaries.dropFirst()) {
            var lo = left, hi = right
            var flo = evaluate(lo)
            let fhi = evaluate(hi)
            guard !flo.isZero, !fhi.isZero, (flo < 0) != (fhi < 0) else { continue }
            for _ in 0..<64 {
                let mid = (lo + hi) / 2
                if mid == lo || mid == hi { break }
                let fm = evaluate(mid)
                if fm.isZero { lo = mid; hi = mid; break }
                if (flo < 0) != (fm < 0) { hi = mid } else { lo = mid; flo = fm }
            }
            result.append((lo + hi) / 2)
        }
        return result.sorted().reduce(into: []) {
            if let last = $0.last, ($1 - last).magnitude <= 64 * Float64.ulpOfOne { return }
            $0.append($1)
        }
    }
}
