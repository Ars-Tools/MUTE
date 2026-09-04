//
//  Linear+Biquad+Filter.swift
//  MUTE
//
//  Created by Kota on 9/3/26.
//
import func simd.fma
import func simd.dot
import func simd.cross
import func simd.length_squared
import func simd.simd_abs
import func simd.__tg_sqrt
import func simd.copysign
import func simd.sqrt
extension Linear {
    public struct Biquad: Filter {
        public let b: SIMD3<Float64>
        public let a: SIMD3<Float64>
    }
}
extension Linear.Biquad {
    @inlinable
    package init(raw: (b: SIMD3<Float64>, a: SIMD3<Float64>)) {
        (b, a) = raw
    }
}
extension Linear.Biquad {
    @inlinable
    public var ⁻¹: Self {
        .init(raw: (a, b))
    }
}
extension Linear.Biquad {
    public struct Power {
        @usableFromInline let p: SIMD3<Float64>
        @usableFromInline let q: SIMD3<Float64>
    }
}
extension Linear.Biquad.Power {
    @inlinable
    init(b: SIMD3<Float64>, a: SIMD3<Float64>) {
        p = switch (b.x + b.z, b.x * b.z) {
        case let (s, t):
            .init(
                fma(-2, t, length_squared(b)),
                2 * s * b.y,
                4 * t
            )
        }
        q = switch (a.x + a.z, a.x * a.z) {
        case let (s, t):
            .init(
                fma(-2, t, length_squared(a)),
                2 * s * a.y,
                4 * t
            )
        }
    }
}
extension Linear.Biquad.Power {
    @inlinable
    public var μ: Float64 {
        // sqrt(Q(±1))
        let e = SIMD2<Float64>(
            q.x + q.y + q.z,
            q.x - q.y + q.z
        )
        let s = __tg_sqrt(e)
        let r = s.x * s.y
        let d = r * sqrt(2 * (r + q.x - q.z))

        // mₖ = mean(xᵏ / Q(x)), x = cos(ω)
        let t = s.sum()
        let m₀ = t / d
        let m₁ = -2 * q.y / t / d
        let m₂ =
            !q.z.isZero ? fma(-m₀, q.x, fma(-m₁, q.y, 1)) / q.z :
            !q.y.isZero ? -m₁ * q.x / q.y :
            !q.x.isZero ? 0.5 / q.x : .nan
        return dot(p, .init(m₀, m₁, m₂))
    }
}
extension Linear.Biquad.Power {
    @inlinable
    var`extrema?`: Array<Float64> {
        let (α, β, γ) = switch cross(p, q) {
        case let ε:
            (ε.x, ε.y, ε.z)
        }
        if α.isZero {
            if β.isZero {
                return.init(arrayLiteral: -1, 1)
            } else {
                return.init(arrayLiteral: -1, 1, 0.50 * γ / β).filter((-1...1).contains)
            }
        } else {
            let D = fma(-α, γ, β * β)
            if D.isLessThanOrEqualTo(.zero) {
                return.init(arrayLiteral: -1, 1)
            } else {
                let ξ = β + copysign(sqrt(D), β)
                return.init(arrayLiteral: -1, 1, ξ / α, γ / ξ).filter((-1...1).contains)
            }
        }
    }
}
extension Linear.Biquad.Power {
    @inlinable@inline(__always)@_transparent // return minimum and maximum gain of stationary-point frequency
    package var range: ClosedRange<Float64> {
        `extrema?`.reduce(.init(uncheckedBounds: (Float64.infinity, -Float64.infinity))) {
            switch fma($1, fma($1, p.z, p.y), p.x) / fma($1, fma($1, q.z, q.y), q.x) {
            case let g:
                    .init(uncheckedBounds: (Swift.min($0.lowerBound, g), Swift.max($0.upperBound, g)))
            }
        }
    }
    @inlinable
    public var min: Float64 {
        range.lowerBound
    }
    @inlinable
    public var max: Float64 {
        range.upperBound
    }
}
extension Linear.Biquad {
    @inlinable
    public var gain: Power {
        .init(b: b, a: a)
    }
}
extension Linear.Biquad {
    @inlinable@inline(__always)@_transparent
    static func power(_ w: SIMD3<Float64>) -> SIMD3<Float64> {
        switch (w.x + w.z, w.x * w.z) {
        case let (s, t):
            .init(
                fma(-2, t, length_squared(w)),
                2 * s * w.y,
                4 * t
            )
        }
    }
    @inlinable@inline(__always)@_transparent
    static func `stationary-points`(P: SIMD3<Float64>, Q: SIMD3<Float64>) -> Array<Float64> {
        let (α, β, γ) = switch cross(P, Q) {
        case let ε:
            (ε.x, ε.y, ε.z)
        }
        if α.isZero {
            if β.isZero {
                return.init(arrayLiteral: -1, 1)
            } else {
                return.init(arrayLiteral: -1, 1, 0.50 * γ / β).filter((-1...1).contains)
            }
        } else {
            let D = fma(-α, γ, β * β)
            if D.isLess(than: .leastNonzeroMagnitude) {
                return.init(arrayLiteral: -1, 1)
            } else {
                let q = β + copysign(sqrt(D), β)
                return.init(arrayLiteral: -1, 1, q / α, γ / q).filter((-1...1).contains)
            }
        }
    }
}
extension Linear.Biquad {
    @inlinable
    public var 𝒢ₘ: Float64 {
        // H(z) = (b₀ + b₁z⁻¹ + b₂z⁻²)
        //      / (a₀ + a₁z⁻¹ + a₂z⁻²)
        let p = Self.power(b)
        let q = Self.power(a)

        // sqrt(Q(±1)) = |A(±1)|
        let s = simd_abs(.init(a.y, -a.y) + a.x + a.z)

        let r = s.x * s.y
        let d = r * sqrt(2 * (r + q.x - q.z))

        // mₖ = mean(cos(ω)^k / |A(e^{jω})|²)
        let t = s.sum()
        let m₀ = t / d
        let m₁ = -2 * q.y / t / d
        let m₂ =
            !q.z.isZero ? fma(-m₀, q.x, fma(-m₁, q.y, 1)) / q.z :
            !q.y.isZero ? -m₁ * q.x / q.y :
            !q.x.isZero ? 0.5 / q.x : .nan

        return dot(p, .init(m₀, m₁, m₂))
    }
}
extension Linear.Biquad {
    @inlinable@inline(__always)@_transparent // return minimum and maximum gain of stationary-point frequency
    package var 𝒢: SIMD2<Float64> {
        switch (Self.power(b), Self.power(a)) {
        case(let P, let Q):
            Self.`stationary-points`(P: P, Q: Q).reduce(SIMD2<Float64>(.infinity, -.infinity)) {
                switch fma($1, fma($1, P.z, P.y), P.x) / fma($1, fma($1, Q.z, Q.y), Q.x) {
                case let g:
                        .init(min($0.x, g), max($0.y, g))
                }
            }
        }
    }
    @inlinable
    public var 𝒢ₛ: Float64 {
        𝒢.min()
    }
    @inlinable
    public var 𝒢ₚ: Float64 {
        𝒢.max()
    }
}
