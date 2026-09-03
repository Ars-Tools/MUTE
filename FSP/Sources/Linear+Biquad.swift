//
//  Linear+Biquad.swift
//  MUTE
//
//  Created by Kota on 9/3/26.
//
import func simd.fma
import func simd.dot
import func simd.cross
import func simd.length_squared
import func simd.__sincospi_stret
import func simd.__sinpi
import func simd.__cospi
import func simd.sinpi
import func simd.cospi
import func simd.exp10
import func simd.expm1
import func simd.__exp10
import func simd.copysign
import func simd.sqrt
import func simd.rsqrt
import func simd.recip
import func simd.sinh
import func simd._simd_sinc
import typealias simd.__double2
import let Darwin.M_LN2
import let Darwin.M_LN10
extension Linear {
    public struct Biquad {
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
    @inlinable@inline(__always)@_transparent
    package static func power(_ w: SIMD3<Float64>) -> SIMD3<Float64> {
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
    package static func `stationary-point`(P: SIMD3<Float64>, Q: SIMD3<Float64>) -> Array<Float64> {
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
    @inlinable@inline(__always)@_transparent // return minimum and maximum gain of stationary-point frequency
    package var G: SIMD2<Float64> {
        switch (Self.power(b), Self.power(a)) {
        case(let P, let Q):
            Self.`stationary-point`(P: P, Q: Q).reduce(SIMD2<Float64>(.infinity, -.infinity)) {
                switch fma($1, fma($1, P.z, P.y), P.x) / fma($1, fma($1, Q.z, Q.y), Q.x) {
                case let g:
                        .init(min($0.x, g), max($0.y, g))
                }
            }
        }
    }
    @inlinable
    public var Gₛ: Float64 {
        G.min()
    }
    @inlinable
    public var Gₚ: Float64 {
        G.max()
    }
}
// MARK: BPF
extension Linear.Biquad {
    @inlinable@inline(__always)@_transparent
    static func BPF(ω₀: Float64, Q⁻¹: Float64) -> Self {
        // b₀ =  α
        // b₁ =  0
        // b₂ = -α
        // α = 0.5 * sin(2 * ω₀) / Q = sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        // a₀ = 1 + α = 1 + 0.5 * sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        // a₁ = - 2 * cos(ω₀) = 4 * sin²( 0.5 * ω₀ ) - 2
        // a₂ = 1 - α = 1 - 0.5 * sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        let z = __sincospi_stret(ω₀)
        let q = z.__cosval * Q⁻¹
        let α = z.__sinval * q
        return.init(raw: (
            .init(α, 0, -α),
            .init(fma( z.__sinval, q, 1),
                  fma( z.__sinval * z.__sinval, 4, -2),
                  fma(-z.__sinval, q, 1))
        ))
    }
    @inlinable
    public static func BPF(ω₀: Float64, Q: Float64) -> Self {
        BPF(ω₀: ω₀, Q⁻¹: recip(Q))
    }
    @inlinable
    public static func BPF(ω₀: Float64, BW: Float64) -> Self {
        BPF(ω₀: ω₀, Q⁻¹: 2.0 * sinh(0.5 * M_LN2 * BW / _simd_sinc(2.0 * .pi * ω₀)))
    }
}
// MARK: LPF
extension Linear.Biquad {
    @inlinable@inline(__always)@_transparent
    static func LPF(ω₀: Float64, Q⁻¹: Float64) -> Self {
        // b₀ = 0.5 * ( 1 - cos(ω₀) ) =     sin²( 0.5 * ω₀ )
        // b₁ =         1 - cos(ω₀)   = 2 * sin²( 0.5 * ω₀ )
        // b₂ = 0.5 * ( 1 - cos(ω₀) ) =     sin²( 0.5 * ω₀ )
        // α = 0.5 * sin(2 * ω₀) / Q = sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        // a₀ = 1 + α = 1 + 0.5 * sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        // a₁ = - 2 * cos(ω₀) = 4 * sin²( 0.5 * ω₀ ) - 2
        // a₂ = 1 - α = 1 - 0.5 * sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        let z = __sincospi_stret(ω₀)
        let q = z.__cosval * Q⁻¹
        let b = z.__sinval * z.__sinval
        return.init(raw: (
            .init(b,  2 * b, b),
            .init(fma( z.__sinval, q, 1),
                  fma( z.__sinval * z.__sinval, 4, -2),
                  fma(-z.__sinval, q, 1))
        ))
    }
    @inlinable
    public static func LPF(ω₀: Float64, Q: Float64) -> Self {
        LPF(ω₀: ω₀, Q⁻¹: recip(Q))
    }
    @inlinable
    public static func LPF(ω₀: Float64, BW: Float64) -> Self {
        LPF(ω₀: ω₀, Q⁻¹: 2.0 * sinh(0.5 * M_LN2 * BW / _simd_sinc(2.0 * .pi * ω₀)))
    }
}
// MARK: HPF
extension Linear.Biquad {
    @inlinable@inline(__always)@_transparent
    static func HPF(ω₀: Float64, Q⁻¹: Float64) -> Self {
        // b₀ = 0.5 * ( 1 + cos(ω₀) ) =     cos²( 0.5 * ω₀ )
        // b₁ =         1 + cos(ω₀)   = 2 * cos²( 0.5 * ω₀ )
        // b₂ = 0.5 * ( 1 + cos(ω₀) ) =     cos²( 0.5 * ω₀ )
        // α = 0.5 * sin(2 * ω₀) / Q = sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        // a₀ = 1 + α = 1 + 0.5 * sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        // a₁ = - 2 * cos(ω₀) = 4 * sin²( 0.5 * ω₀ ) - 2
        // a₂ = 1 - α = 1 - 0.5 * sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        let z = __sincospi_stret(ω₀)
        let q = z.__cosval * Q⁻¹
        let b = z.__cosval * z.__cosval
        return.init(raw: (
            .init(b, -2 * b, b),
            .init(fma( z.__sinval, q, 1),
                  fma( z.__sinval * z.__sinval, 4, -2),
                  fma(-z.__sinval, q, 1))
        ))
    }
    @inlinable
    public static func HPF(ω₀: Float64, Q: Float64) -> Self {
        HPF(ω₀: ω₀, Q⁻¹: recip(Q))
    }
    @inlinable
    public static func HPF(ω₀: Float64, BW: Float64) -> Self {
        HPF(ω₀: ω₀, Q⁻¹: 2.0 * sinh(0.5 * M_LN2 * BW / _simd_sinc(2.0 * .pi * ω₀)))
    }
}
// MARK: APF
extension Linear.Biquad {
    @inlinable@inline(__always)@_transparent
    static func APF(ω₀: Float64, Q⁻¹: Float64) -> Self {
        // b₀ = 1 - α = a₂
        // b₁ = -2 * cos(ω) = a₁
        // b₂ = 1 + α = a₀
        // α = 0.5 * sin(2 * ω₀) / Q = sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        // a₀ = 1 + α = 1 + 0.5 * sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        // a₁ = - 2 * cos(ω₀) = 4 * sin²( 0.5 * ω₀ ) - 2
        // a₂ = 1 - α = 1 - 0.5 * sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        let z = __sincospi_stret(ω₀)
        let cq = z.__cosval * Q⁻¹
        let a₀ = fma( z.__sinval, cq, 1)
        let a₁ = fma( 4, z.__sinval * z.__sinval, -2)
        let a₂ = fma(-z.__sinval, cq, 1)
        return.init(raw: (
            .init(a₂, a₁, a₀),
            .init(a₀, a₁, a₂)
        ))
    }
    @inlinable
    public static func APF(ω₀: Float64, Q: Float64) -> Self {
        APF(ω₀: ω₀, Q⁻¹: recip(Q))
    }
    @inlinable
    public static func APF(ω₀: Float64, BW: Float64) -> Self {
        APF(ω₀: ω₀, Q⁻¹: 2.0 * sinh(0.5 * M_LN2 * BW / _simd_sinc(2.0 * .pi * ω₀)))
    }
}
// MARK: BSF
extension Linear.Biquad {
    @inlinable@inline(__always)@_transparent
    static func BSF(ω₀: Float64, Q⁻¹: Float64) -> Self {
        // b₀ = 1
        // b₁ = -2 * cos(ω) = a₁
        // b₂ = 1
        // α = 0.5 * sin(2 * ω₀) / Q = sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        // a₀ = 1 + α = 1 + 0.5 * sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        // a₁ = - 2 * cos(ω₀) = 4 * sin²( 0.5 * ω₀ ) - 2
        // a₂ = 1 - α = 1 - 0.5 * sin ( 0.5 * ω₀ ) * cos( 0.5 * ω₀ ) / Q
        let z = __sincospi_stret(ω₀)
        let cq = z.__cosval * Q⁻¹
        let a₁ = fma( 4, z.__sinval * z.__sinval, -2)
        return.init(raw: (
            .init(1, a₁, 1),
            .init(fma( z.__sinval, cq, 1),
                  a₁,
                  fma(-z.__sinval, cq, 1))
        ))
    }
    @inlinable
    public static func BSF(ω₀: Float64, Q: Float64) -> Self {
        BSF(ω₀: ω₀, Q⁻¹: recip(Q))
    }
    @inlinable
    public static func BSF(ω₀: Float64, BW: Float64) -> Self {
        BSF(ω₀: ω₀, Q⁻¹: 2.0 * sinh(0.5 * M_LN2 * BW / _simd_sinc(2.0 * .pi * ω₀)))
    }
}
// MARK: LSF
extension Linear.Biquad {
    @inlinable @inline(__always) @_transparent
    static func LSF(
        ω₀: Float64,
        A: Float64,
        A₋1: Float64,
        κ: Float64
    ) -> Self {
        
        let z = __sincospi_stret(ω₀)

        let s = z.__sinval
        let c = z.__cosval
        let x = s * s

        let A₊1 = A + 1

        let u = fma( A₋1, x, 1)
        let v = fma(-A₋1, x, A)

        let p = fma( A₊1, x, -1)
        let q = fma(-A₊1, x,  A)

        // Keep r = s * (cκ) unrounded until the final ± operation.
        let cκ = c * κ
        
        return.init(raw: (
            .init(fma( s, cκ, u),  2 * p, fma(-s, cκ, u)) * A,
            .init(fma( s, cκ, v), -2 * q, fma(-s, cκ, v))
        ))
    }
    @inlinable
    public static func LSF(
        ω₀: Float64,
        Q: Float64,
        dB: Float64
    ) -> Self {
        let A₋1 = expm1(0.025 * M_LN10 * dB)
        let A = A₋1 + 1
        return LSF(
            ω₀: ω₀,
            A: A,
            A₋1: A₋1,
            κ: sqrt(A) / Q
        )
    }
    @inlinable
    public static func LSF(
        ω₀: Float64,
        BW: Float64,
        dB: Float64
    ) -> Self {
        let A₋1 = expm1(0.025 * M_LN10 * dB)
        let A = A₋1 + 1
        return LSF(
            ω₀: ω₀,
            A: A,
            A₋1: A₋1,
            κ: sqrt(A) * 2.0 * sinh(0.5 * M_LN2 * BW / _simd_sinc(2.0 * .pi * ω₀))
        )
    }
    @inlinable
    public static func LSF(
        ω₀: Float64,
        S: Float64,
        dB: Float64
    ) -> Self {
        let A₋1 = expm1(0.025 * M_LN10 * dB)
        let A = A₋1 + 1
        return LSF(
            ω₀: ω₀,
            A: A,
            A₋1: A₋1,
            κ: sqrt(fma(fma(A, A, 1), recip(S) - 1, 2 * A))
        )
    }
}
// MARK: HSF
extension Linear.Biquad {
    @inlinable @inline(__always) @_transparent
    static func HSF(
        ω₀: Float64,
        A: Float64,
        A₋1: Float64,
        κ: Float64
    ) -> Self {
        let z = __sincospi_stret(ω₀)

        let s = z.__sinval
        let c = z.__cosval
        let x = s * s

        let A₊1 = A + 1

        let u = fma( A₋1, x,  1)
        let v = fma(-A₋1, x,  A)

        let p = fma( A₊1, x, -1)
        let q = fma(-A₊1, x,  A)

        let cκ = c * κ
        
        return.init(raw: (
            .init(fma( s, cκ, v), -2 * q, fma(-s, cκ, v)) * A,
            .init(fma( s, cκ, u),  2 * p, fma(-s, cκ, u))
        ))
    }
    @inlinable
    public static func HSF(
        ω₀: Float64,
        Q: Float64,
        dB: Float64
    ) -> Self {
        let A₋1 = expm1(0.025 * M_LN10 * dB)
        let A = A₋1 + 1
        return HSF(
            ω₀: ω₀,
            A: A,
            A₋1: A₋1,
            κ: sqrt(A) / Q
        )
    }
    @inlinable
    public static func HSF(
        ω₀: Float64,
        BW: Float64,
        dB: Float64
    ) -> Self {
        let A₋1 = expm1(0.025 * M_LN10 * dB)
        let A = A₋1 + 1
        return HSF(
            ω₀: ω₀,
            A: A,
            A₋1: A₋1,
            κ: sqrt(A) * 2.0 * sinh(0.5 * M_LN2 * BW / _simd_sinc(2.0 * .pi * ω₀))
        )
    }
    @inlinable
    public static func HSF(
        ω₀: Float64,
        S: Float64,
        dB: Float64
    ) -> Self {
        let A₋1 = expm1(0.025 * M_LN10 * dB)
        let A = A₋1 + 1
        return HSF(
            ω₀: ω₀,
            A: A,
            A₋1: A₋1,
            κ: sqrt(fma(fma(A, A, 1), recip(S) - 1, 2 * A))
        )
    }
}
// MARK: PEQ
extension Linear.Biquad {
    @inlinable @inline(__always) @_transparent
    static func PEQ(
        z: __double2,
        α: Float64,
        A: SIMD2<Float64>
    ) -> Self {
        let ₀ = fma(
            .init(repeating:  α),
            A,
            .one
        )
        let ₁ = -2 * z.__cosval
        let ₂ = fma(A, .init(repeating: -α), .one)
        return.init(raw: (
            .init(₀.y, ₁, ₂.y),
            .init(₀.x, ₁, ₂.x)
        ))
    }
    @inlinable
    public static func PEQ(
        ω₀: Float64,
        Q: Float64,
        dB: Float64
    ) -> Self {
        let A = exp10(dB * SIMD2<Float64>(-0.025, 0.025))
        let z = __sincospi_stret(2 * ω₀)
        let α = 0.5 * z.__sinval * recip(Q)
        return PEQ(
            z: z,
            α: α,
            A: A
        )
    }
    @inlinable
    public static func PEQ(
        ω₀: Float64,
        BW: Float64,
        dB: Float64
    ) -> Self {
        let A = exp10(dB * SIMD2<Float64>(-0.025, 0.025))
        let z = __sincospi_stret(2 * ω₀)
        let α = z.__sinval * sinh(0.5 * M_LN2 * BW / _simd_sinc(2.0 * .pi * ω₀))
        return PEQ(
            z: z,
            α: α,
            A: A
        )
    }
    @inlinable
    public static func PEQ(
        ω₀: Float64,
        S: Float64,
        dB: Float64
    ) -> Self {
        let A = exp10(dB * SIMD2<Float64>(-0.025, 0.025))
        let z = __sincospi_stret(2 * ω₀)
        let α = 0.5 * z.__sinval * sqrt(fma(A.sum(), recip(S) - 1, 2))
        return PEQ(
            z: z,
            α: α,
            A: A
        )
    }
}
