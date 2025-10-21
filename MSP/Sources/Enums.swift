//
//  Enums.swift
//  MUTE
//
//  Created by Kota on 5/15/R7.
//
import func simd.__sincospi_stret
import func simd.fma
import func simd.cos
import func simd.exp10
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Numerics.Rational64
public enum Domain: Sendable & Hashable {
	case time
	case freq
}
public enum Interpolation: Sendable & Hashable {
	case none
	case linear
	case quadratic
}
public enum Operation: Sendable & Hashable {
	case sequential
	case parallel
}
public enum Quantity: Sendable & Hashable {
	case dense
	case sparse
}
public enum BiquadFilterDesign: Sendable {
	case lpf(ω₀: Frequency, quality: Float64) // lo-pass
	case hpf(ω₀: Frequency, quality: Float64) // hi-pass
	case bpf(ω₀: Frequency, quality: Float64) // band-pass
	case bsf(ω₀: Frequency, quality: Float64) // band-stop
	case apf(ω₀: Frequency, quality: Float64) // all-pass
	case lsf(ω₀: Frequency, quality: Float64, gain: Float64) // lo-shelf
	case hsf(ω₀: Frequency, quality: Float64, gain: Float64) // hi-shelf
	case peq(ω₀: Frequency, quality: Float64, gain: Float64) // peaking
	case raw(b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) // raw coefficients
}
extension BiquadFilterDesign {
	@inlinable @inline(__always)
	public func coefficients(for Ts: CMTime) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
		switch self {
		case.lpf(let ω₀, let Q):
			let e = __sincospi_stret(2.0 * ω₀.increment(for: Ts))
			let α = e.__sinval / Q
			let λ = SIMD3(1 - e.__cosval, -2 * e.__cosval, fma(-0.5, α, 1)) / fma( 0.5, α, 1)
			return (0.5 * λ.x, λ.x, 0.5 * λ.x, λ.y, λ.z)
		case.hpf(let ω₀, let Q):
			let e = __sincospi_stret(2.0 * ω₀.increment(for: Ts))
			let α = e.__sinval / Q
			let λ = SIMD3(1 + e.__cosval, -2 * e.__cosval, fma(-0.5, α, 1)) / fma( 0.5, α, 1)
			return (0.5 * λ.x,-λ.x, 0.5 * λ.x, λ.y, λ.z)
		case.bpf(let ω₀, let Q):
			let e = __sincospi_stret(2.0 * ω₀.increment(for: Ts))
			let α = e.__sinval / Q
			let λ = SIMD3(0.5 * α, -2 * e.__cosval, fma(-0.5, α, 1)) / fma( 0.5, α, 1)
			return (λ.x, 0, -λ.x, λ.y, λ.z)
		case.bsf(let ω₀, let Q):
			let e = __sincospi_stret(2.0 * ω₀.increment(for: Ts))
			let α = e.__sinval / Q
			let λ = SIMD3(1, -2 * e.__cosval, fma(-0.5, α, 1)) / fma( 0.5, α, 1)
			return (λ.x, λ.y, λ.x, λ.y, λ.z)
		case.apf(let ω₀, let Q):
			let e = __sincospi_stret(2.0 * ω₀.increment(for: Ts))
			let s = e.__sinval / Q
			let λ = SIMD2(-2 * e.__cosval, fma(-0.5, s, 1)) / fma(0.5, s, 1)
			return (λ.y, λ.x, 1, λ.x, λ.y)
		case.lsf(let ω₀, let Q, let dB):
			let A = exp10(dB * SIMD2<Float64>(0.0125, 0.025))
			let e = __sincospi_stret(2.0 * ω₀.increment(for: Ts))
			let μ = SIMD2(repeating: A.y) + SIMD2(-1, 1)
			let λ = fma(SIMD2(-e.__sinval, e.__sinval), SIMD2(repeating: A.x/Q), SIMD2(repeating: μ.y))
			let α = SIMD3(μ.x, μ.y, μ.x)
			let β = SIMD3(λ.y, μ.x, λ.x)
			let a = fma(SIMD3(repeating:  e.__cosval), α, β)
			let b = fma(SIMD3(repeating: -e.__cosval), α, β) * A.y / a.x
			return (b.x, 2 * b.y, b.z, -2 * a.y / a.x, a.z / a.x)
		case.hsf(let ω₀, let Q, let dB):
			let A = exp10(dB * SIMD2<Float64>(0.0125, 0.025))
			let e = __sincospi_stret(2.0 * ω₀.increment(for: Ts))
			let μ = SIMD2(repeating: A.y) + SIMD2(-1, 1)
			let λ = fma(SIMD2(-e.__sinval, e.__sinval), SIMD2(repeating: A.x/Q), SIMD2(repeating: μ.y))
			let α = SIMD3(μ.x, μ.y, μ.x)
			let β = SIMD3(λ.y, μ.x, λ.x)
			let a = fma(SIMD3(repeating: -e.__cosval), α, β)
			let b = fma(SIMD3(repeating:  e.__cosval), α, β) * A.y / a.x
			return (b.x, -2 * b.y, b.z, 2 * a.y / a.x, a.z / a.x)
		case.peq(let ω₀, let Q, let dB):
			let A = exp10(dB * SIMD2<Float64>(-0.025, 0.025))
			let e = __sincospi_stret(2.0 * ω₀.increment(for: Ts))
			let α = fma(SIMD2(-e.__sinval, e.__sinval), SIMD2(repeating: A.x/Q), SIMD2(repeating: 2))
			let β = fma(SIMD2(-e.__sinval, e.__sinval), SIMD2(repeating: A.y/Q), SIMD2(repeating: 2))
			let λ = SIMD4(β.y, β.x, -4 * e.__cosval, α.x) / α.y
			return (λ.x, λ.z, λ.y, λ.z, λ.w)
		case.raw(let b₀, let b₁, let b₂, let a₁, let a₂):
			return (b₀, b₁, b₂, a₁, a₂)
		}
	}
	@inlinable @inline(__always)
	public init(zero z: (r: Float64, θ: Float64), pole p: (r: Float64, θ: Float64)) {
		let x = SIMD2<Float64>(z.r, p.r)
		let y = 2 * x * cos(SIMD2<Float64>(z.θ, p.θ))
		let z = x * x
		self = .raw(b₀: 1, b₁: y.x, b₂: z.x, a₁: y.y, a₂: z.y)
	}
	@_disfavoredOverload
	@inlinable @inline(__always)
	func coefficients(for Ts: CMTime) -> Array<Float64> {
		withUnsafeBytes(of: coefficients(for: Ts)) {
			$0.withMemoryRebound(to: Float64.self, Array.init)
		}
	}
}
public enum WindowStride: Sendable {
	case absolute(Duration)
	case relative(Rational64)
}
public enum WindowDesign: Sendable {
	case rectangular(Duration)
	case bartlett(Duration)
	case jonathan(Duration)
	case hanning(Duration)
	case hamming(Duration)
	case blackman(Duration)
//	case kaiser(Duration, α: Float64)
	case raw(Array<Float64>)
}
extension WindowDesign {
	@inlinable @inline(__always)
	func coefficients(for T₀: CMTime) -> Array<Float64> {
		switch self {
		case.rectangular(let duration):
			.init(repeating: 1, count: duration.samples(for: T₀))
		case.bartlett(let duration):
			.init(unsafeUninitializedCapacity: duration.samples(for: T₀)) {
				vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0[..<($0.count/2+1)])
				vDSP.formRamp(withInitialValue: .init(($0.count+1)/2-1), increment: -1, result: &$0[($0.count/2+1)...])
				vDSP.divide($0, .init($0.count/2), result: &$0)
				$1 = $0.count
			}
		case.jonathan(let duration):
			.init(unsafeUninitializedCapacity: duration.samples(for: T₀)) {
				vDSP.formWindow(usingSequence: .hanningDenormalized, result: &$0, isHalfWindow: false)
				vForce.sqrt($0, result: &$0)
				$1 = $0.count
			}
		case.hanning(let duration):
			vDSP.window(ofType: Float64.self, usingSequence: .hanningDenormalized, count: duration.samples(for: T₀), isHalfWindow: false)
		case.hamming(let duration):
			vDSP.window(ofType: Float64.self, usingSequence: .hamming, count: duration.samples(for: T₀), isHalfWindow: false)
		case.blackman(let duration):
			vDSP.window(ofType: Float64.self, usingSequence: .blackman, count: duration.samples(for: T₀), isHalfWindow: false)
		case.raw(let coefficients):
			coefficients
		}
	}
}
public enum SmoothWindowDesign: Sendable & Hashable {
	case pulse(Int)
	case rect(Int)
	case gauss(Float64, Int)
	case sinc(Float64, Int)
	case raw(Array<Float64>)
}
extension SmoothWindowDesign {
	@inlinable
	public var coefficients: Array<Float64> {
		switch self {
		case.pulse(let length):
			.init(unsafeUninitializedCapacity: length) {
				vDSP.clear(&$0)
				$0[length/2] = 1
				$1 = $0.count
			}
		case.rect(let length):
			.init(repeating: 1 / .init(length), count: length)
		case.gauss(let factor, let length):
			.init(unsafeUninitializedCapacity: length) {
				vDSP.formRamp(withInitialValue: .init(-length/2), increment: 1, result: &$0)
				vDSP.square($0, result: &$0)
				vDSP.multiply(-.pi * (factor * factor) / .init(length), $0, result: &$0)
				vForce.exp($0, result: &$0)
				vDSP.multiply(factor / .pi / .init(length).squareRoot(), $0, result: &$0)
				$1 = $0.count
			}
		case.sinc(let factor, let length):
			.init(unsafeUninitializedCapacity: 2 * length) {
				vDSP.formRamp(withInitialValue: .init(-length/2) * factor * .pi, increment: factor * .pi, result: &$0[..<length])
				vForce.sin($0[..<length], result: &$0[length...])
				vDSP.divide($0[length...], $0[..<length], result: &$0[..<length])
				$0[length/2] = 1
				$1 = length
			}
		case.raw(let kernel):
			kernel
		}
	}
}
@usableFromInline
enum Error: Swift.Error & Sendable {
	case notImplemented
	case invalidChannel
	case unmatchChannel
	case lackOfResource
	case alreadyReserved
	case noBufferAssigned
}
