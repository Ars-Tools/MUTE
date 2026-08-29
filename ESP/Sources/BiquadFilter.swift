//
//  BiquadFilter.swift
//  MUTE
//
//  Created by Kota on 8/29/26.
//
import func simd.__sincospi_stret
import func simd.__cospi
import func simd.__sinpi
import func simd.fma
import func simd.recip
import func simd.exp10
import func simd.sinh
import let simd.M_LN2
public enum BiquadFilter {
    @inlinable@inline(__always)@_transparent
    static func BPF(ω₀: Float64, Q⁻¹: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        let e = __sincospi_stret(2.0 * ω₀)
        let α = e.__sinval * Q⁻¹
        let λ = SIMD3(-2 * e.__cosval, fma(-0.5, α, 1), 0.5 * α) / fma( 0.5, α, 1)
        return (λ.z, 0, -λ.z, λ.x, λ.y)
    }
    @inlinable@inline(__always)@_transparent
    static func LPF(ω₀: Float64, Q⁻¹: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        let e = __sincospi_stret(2.0 * ω₀)
        let α = e.__sinval * Q⁻¹
        let λ = SIMD3(-2 * e.__cosval, fma(-0.5, α, 1), 1 - e.__cosval) / fma( 0.5, α, 1)
        return (0.5 * λ.z,  λ.z, 0.5 * λ.z, λ.x, λ.y)
    }
    @inlinable@inline(__always)@_transparent
    static func HPF(ω₀: Float64, Q⁻¹: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        let e = __sincospi_stret(2.0 * ω₀)
        let α = e.__sinval * Q⁻¹
        let λ = SIMD3(-2 * e.__cosval, fma(-0.5, α, 1), 1 + e.__cosval) / fma( 0.5, α, 1)
        return (0.5 * λ.z, -λ.z, 0.5 * λ.z, λ.x, λ.y)
    }
    @inlinable@inline(__always)@_transparent
    static func APF(ω₀: Float64, Q⁻¹: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        let e = __sincospi_stret(2.0 * ω₀)
        let α = e.__sinval * Q⁻¹
        let λ = SIMD2(-2 * e.__cosval, fma(-0.5, α, 1)   ) / fma( 0.5, α, 1)
        return (λ.y, λ.x, 1, λ.x, λ.y)
    }
    @inlinable@inline(__always)@_transparent
    static func BSF(ω₀: Float64, Q⁻¹: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        let e = __sincospi_stret(2.0 * ω₀)
        let α = e.__sinval * Q⁻¹
        let λ = SIMD3(-2 * e.__cosval, fma(-0.5, α, 1), 1) / fma( 0.5, α, 1)
        return (λ.z, λ.x, λ.z, λ.x, λ.y)
    }
}
extension BiquadFilter {
    @inlinable@inline(__always)@_transparent
    static func Q⁻¹(ω₀: Float64, BW: Float64) -> Float64 {
        2.0 * sinh(M_LN2 * .pi * BW * ω₀ / __sinpi(2.0 * ω₀))
    }
}
extension BiquadFilter {
    @inlinable@inline(__always)@_transparent
    public static func BPF(ω₀: Float64, Q: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        BPF(ω₀: ω₀, Q⁻¹: recip(Q))
    }
    @inlinable@inline(__always)@_transparent
    public static func BPF(ω₀: Float64, BW: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        BPF(ω₀: ω₀, Q⁻¹: Q⁻¹(ω₀: ω₀, BW: BW))
    }
}
extension BiquadFilter {
    @inlinable@inline(__always)@_transparent
    public static func LPF(ω₀: Float64, Q: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        LPF(ω₀: ω₀, Q⁻¹: recip(Q))
    }
    @inlinable@inline(__always)@_transparent
    public static func LPF(ω₀: Float64, BW: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        LPF(ω₀: ω₀, Q⁻¹: Q⁻¹(ω₀: ω₀, BW: BW))
    }
}
extension BiquadFilter {
    @inlinable@inline(__always)@_transparent
    public static func HPF(ω₀: Float64, Q: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        HPF(ω₀: ω₀, Q⁻¹: recip(Q))
    }
    @inlinable@inline(__always)@_transparent
    public static func HPF(ω₀: Float64, BW: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        HPF(ω₀: ω₀, Q⁻¹: Q⁻¹(ω₀: ω₀, BW: BW))
    }
}
extension BiquadFilter {
    @inlinable@inline(__always)@_transparent
    public static func APF(ω₀: Float64, Q: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        APF(ω₀: ω₀, Q⁻¹: recip(Q))
    }
    @inlinable@inline(__always)@_transparent
    public static func APF(ω₀: Float64, BW: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        APF(ω₀: ω₀, Q⁻¹: Q⁻¹(ω₀: ω₀, BW: BW))
    }
}
extension BiquadFilter {
    @inlinable@inline(__always)@_transparent
    public static func BSF(ω₀: Float64, Q: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        BPF(ω₀: ω₀, Q⁻¹: recip(Q))
    }
    @inlinable@inline(__always)@_transparent
    public static func BSF(ω₀: Float64, BW: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        BSF(ω₀: ω₀, Q⁻¹: Q⁻¹(ω₀: ω₀, BW: BW))
    }
}
extension BiquadFilter {
    @inlinable@inline(__always)@_transparent
    public static func LSF(ω₀: Float64, Q: Float64, dB: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        let A = exp10(dB * SIMD2<Float64>(0.0125, 0.025))
        let e = __sincospi_stret(2.0 * ω₀)
        let μ = SIMD2(repeating: A.y) + SIMD2(-1, 1)
        let λ = fma(SIMD2(-e.__sinval, e.__sinval), SIMD2(repeating: A.x/Q), SIMD2(repeating: μ.y))
        let α = SIMD3(μ.x, μ.y, μ.x)
        let β = SIMD3(λ.y, μ.x, λ.x)
        let a = fma(SIMD3(repeating:  e.__cosval), α, β)
        let b = fma(SIMD3(repeating: -e.__cosval), α, β) * A.y / a.x
        return (b.x, 2 * b.y, b.z, -2 * a.y / a.x, a.z / a.x)
    }
}
extension BiquadFilter {
    @inlinable@inline(__always)@_transparent
    public static func HSF(ω₀: Float64, Q: Float64, dB: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        let A = exp10(dB * SIMD2<Float64>(0.0125, 0.025))
        let e = __sincospi_stret(2.0 * ω₀)
        let μ = SIMD2(repeating: A.y) + SIMD2(-1, 1)
        let λ = fma(SIMD2(-e.__sinval, e.__sinval), SIMD2(repeating: A.x/Q), SIMD2(repeating: μ.y))
        let α = SIMD3(μ.x, μ.y, μ.x)
        let β = SIMD3(λ.y, μ.x, λ.x)
        let a = fma(SIMD3(repeating: -e.__cosval), α, β)
        let b = fma(SIMD3(repeating:  e.__cosval), α, β) * A.y / a.x
        return (b.x, -2 * b.y, b.z, 2 * a.y / a.x, a.z / a.x)
    }
}
extension BiquadFilter {
    @inlinable@inline(__always)@_transparent
    public static func PEQ(ω₀: Float64, Q: Float64, dB: Float64) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        let A = exp10(dB * SIMD2<Float64>(-0.025, 0.025))
        let e = __sincospi_stret(2.0 * ω₀)
        let α = fma(SIMD2(-e.__sinval, e.__sinval), SIMD2(repeating: A.x/Q), SIMD2(repeating: 2))
        let β = fma(SIMD2(-e.__sinval, e.__sinval), SIMD2(repeating: A.y/Q), SIMD2(repeating: 2))
        let λ = SIMD4(β.y, β.x, -4 * e.__cosval, α.x) / α.y
        return (λ.x, λ.z, λ.y, λ.z, λ.w)
    }
}
