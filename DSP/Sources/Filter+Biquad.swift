//
//  Filter+Biquad.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
@preconcurrency import protocol Combine.Publisher
import typealias Synchronization.Mutex
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func Layout.broadcast
import func Accelerate.vecLib.vDSP_biquadm_CreateSetupD
import func Accelerate.vecLib.vDSP_biquadm_DestroySetupD
import func Accelerate.vecLib.vDSP_biquadm_SetTargetsDoubleD
import func Accelerate.vecLib.vDSP_biquadm_SetCoefficientsDoubleD
import func Accelerate.vecLib.vDSP_biquadm_SetActiveFiltersD
import func Accelerate.vecLib.vDSP_biquadmD
import func simd.exp10
import func simd.log2
import func simd.fma
import func simd.cos
import func simd.__sincospi_stret
import func NSP.biquad_filter_create
import func NSP.biquad_filter_destroy
import func NSP.biquad_filter_active
import typealias Auxiliary.Autorelease
public enum BiquadFilter {
	public enum Design: Sendable {
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
}
extension BiquadFilter.Design {
	@inlinable@inline(__always)
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
}
extension BiquadFilter {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, (Int, BiquadFilter.Design)), Never> & Sendable> {
		@usableFromInline let source: Stream
		@usableFromInline let design: Signal
		@usableFromInline let length: Int
	}
}
extension BiquadFilter.Kr: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let stream = source.count
		guard let opaque = vDSP_biquadm_CreateSetupD(repeatElement([1,0,0,0,0], count: stream * length).flatMap(\.self), .init(length), .init(stream)) else {
			throw Error.failedToAllocate(OpaquePointer.self)
		}
		let object = Autorelease.Opaque(pointer: opaque, release: vDSP_biquadm_DestroySetupD)
		let cancel = design.sink { key, value in
			switch (key, value.0) {
			case (0..<stream, 0..<length):
				withUnsafeBytes(of: value.1.coefficients(for: interval)) {
					vDSP_biquadm_SetCoefficientsDoubleD(object.pointer,
														$0.assumingMemoryBound(to: Float64.self).baseAddress.unsafelyUnwrapped,
														.init(value.0), .init(key),
														1, 1)
				}
			default:
				assertionFailure("out of range")
			}
		}
		return {
			kernel($0, $1, $2, $3)
			var x = stride(from: 0, to: stream * $3, by: $3).map(UnsafePointer($2).advanced(by:))
			var y = stride(from: 0, to: stream * $3, by: $3).map($2.advanced(by:))
			vDSP_biquadmD(withExtendedLifetime(cancel) { object }.pointer,
						  &x, 1,
						  &y, 1,
						  .init($1))
		}
	}
}
public func filter(_ source: Stream, sos design: some Publisher<(Int, (Int, BiquadFilter.Design)), Never> & Sendable, length: Int) -> some Stream {
	BiquadFilter.Kr(source: source, design: design, length: length)
}
public func filter(_ source: Stream, sos design: some Publisher<(Int, BiquadFilter.Design), Never>, length: Int) -> some Stream {
	filter(source, sos: design.repeat(count: source.count), length: length)
}
public func filter(_ source: Stream, sos design: some Publisher<(Int, some Collection<BiquadFilter.Design>), Never>, length: Int) -> some Stream {
	filter(source, sos: design.flatMap { (key, value) in value.enumerated().publisher.map { (key, $0) } }, length: length)
}
public func filter(_ source: Stream, sos design: some Publisher<some Collection<BiquadFilter.Design>, Never>, length: Int) -> some Stream {
	filter(source, sos: design.repeat(count: source.count), length: length)
}
public func filter(_ source: Stream, sos design: some Collection<BiquadFilter.Design>) -> some Stream {
	filter(source, sos: `repeat`(design, count: source.count), length: design.count)
}
@_disfavoredOverload
public func filter(_ source: Stream, sos design: BiquadFilter.Design...) -> some Stream {
	filter(source, sos: design)
}
extension BiquadFilter {
	@usableFromInline
	struct Ar {
		@usableFromInline let source: Stream
		@usableFromInline let design: Design
		@usableFromInline
		enum Design: Sendable {
			case lpf(ω₀: Stream, quality: Stream)
			case hpf(ω₀: Stream, quality: Stream)
			case bpf(ω₀: Stream, quality: Stream)
			case bsf(ω₀: Stream, quality: Stream)
			case apf(ω₀: Stream, quality: Stream)
			case peq(ω₀: Stream, quality: Stream, gain: Stream)
			case lsf(ω₀: Stream, quality: Stream, gain: Stream)
			case hsf(ω₀: Stream, quality: Stream, gain: Stream)
			case raw(bₖ: Stream, aₖ: Stream)
		}
	}
}
extension BiquadFilter.Ar: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try source(interval: interval, capacity: capacity, instance: &instance)
		let factor = 2.0 * .pi * interval.seconds
		let object = Autorelease.Object(object: biquad_filter_create(source.count)) {
			biquad_filter_destroy($0)
		}
		switch design {
		case.lpf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &a2)
					vDSP.fill(&a0, with: 1)
					//
					vDSP.subtract(a0, a1, result: &b1) // b1 = 1-cosω
					vDSP.addSubtract(a0, a2, addResult: &a0, subtractResult: &a2)
					//
					vDSP.multiply(0.5, b1, result: &b0)
					vDSP.multiply(0.5, b1, result: &b2)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.hpf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &a2)
					vDSP.fill(&a0, with: 1)
					//
					vDSP.multiply(addition: (a0, a1), -1, result: &b1)
					vDSP.addSubtract(a0, a2, addResult: &a0, subtractResult: &a2)
					//
					vDSP.multiply(-0.5, b1, result: &b0)
					vDSP.multiply(-0.5, b1, result: &b2)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.bpf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &b0)
					vDSP.negative(b0, result: &b2)
					vDSP.clear(&b1)
					//
					vDSP.add(1, b0, result: &a0)
					vDSP.add(1, b2, result: &a2)
					//
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.bsf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &a0)
					//
					vDSP.fill(&b0, with: 1)
					vDSP.fill(&b2, with: 1)
					vDSP.addSubtract(b0, a0, addResult: &a0, subtractResult: &a2)
					//
					vDSP.multiply(-2, a1, result: &b1)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.apf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &a0)
					//
					vDSP.fill(&a2, with: 1)
					vDSP.addSubtract(a2, a0, addResult: &b2, subtractResult: &b0)
					vDSP.addSubtract(a2, a0, addResult: &a0, subtractResult: &a2)
					//
					vDSP.multiply(-2, a1, result: &b1)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.lsf(let ω₀, let quality, let gain):
			guard ω₀.count == 1, quality.count == 1, gain.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			let gk = try gain(interval: interval, capacity: capacity, instance: &instance)
			let dB = SIMD2<Float64>(repeating: log2(10.0)) / SIMD2<Float64>(40, 80)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					var dc = UnsafeMutableBufferPointer(start: target, count: length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.divide(a2, a0, result: &a0)
					gk(moment, length, a2.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(dB.y, a2, result: &dc)
					vForce.exp2(dc, result: &dc)
					vDSP.multiply(a0, dc, result: &dc)
					vDSP.multiply(dB.x, a2, result: &a2)
					vForce.exp2(a2, result: &a2)
					//
					vDSP.fill(&a0, with: 1)
					vDSP.addSubtract(a0, a1, addResult: &a0, subtractResult: &a1)
					vDSP.multiply(a1, a2, result: &b0)
					vDSP.addSubtract(b0, a0, addResult: &b0, subtractResult: &b1)
					vDSP.addSubtract(b0, dc, addResult: &b0, subtractResult: &b2)
					vDSP.multiply(a2, b0, result: &b0)
					vDSP.multiply(a2, b1, result: &b1)
					vDSP.multiply(a2, b2, result: &b2)
					vDSP.multiply( 2, b1, result: &b1)
					//
					vDSP.multiply(a2, a0, result: &a0)
					vDSP.addSubtract(a0, a1, addResult: &a0, subtractResult: &a1)
					vDSP.addSubtract(a0, dc, addResult: &a0, subtractResult: &a2)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.hsf(let ω₀, let quality, let gain):
			guard ω₀.count == 1, quality.count == 1, gain.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			let gk = try gain(interval: interval, capacity: capacity, instance: &instance)
			let dB = SIMD2<Float64>(repeating: log2(10.0)) / SIMD2<Float64>(40, 80)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					var dc = UnsafeMutableBufferPointer(start: target, count: length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.divide(a2, a0, result: &a0)
					gk(moment, length, a2.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(dB.y, a2, result: &dc)
					vForce.exp2(dc, result: &dc)
					vDSP.multiply(a0, dc, result: &dc)
					vDSP.multiply(dB.x, a2, result: &a2)
					vForce.exp2(a2, result: &a2)
					//
					vDSP.fill(&a0, with: 1)
					vDSP.addSubtract(a0, a1, addResult: &a0, subtractResult: &a1)
					vDSP.multiply(a0, a2, result: &b0)
					vDSP.addSubtract(b0, a1, addResult: &b0, subtractResult: &b1)
					vDSP.addSubtract(b0, dc, addResult: &b0, subtractResult: &b2)
					vDSP.multiply(a2, b0, result: &b0)
					vDSP.multiply(a2, b1, result: &b1)
					vDSP.multiply(a2, b2, result: &b2)
					vDSP.multiply(-2, b1, result: &b1)
					//
					vDSP.multiply(a2, a1, result: &a1)
					vDSP.addSubtract(a1, a0, addResult: &a0, subtractResult: &a1)
					vDSP.addSubtract(a0, dc, addResult: &a0, subtractResult: &a2)
					vDSP.multiply( 2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.peq(let ω₀, let quality, let gain):
			guard ω₀.count == 1, quality.count == 1, gain.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			let gk = try gain(interval: interval, capacity: capacity, instance: &instance)
			let dB = log2(10.0) / 40.0
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &a0)
					gk(moment, length, a2.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(dB, a2, result: &a2)
					vForce.exp2(a2, result: &a2)
					//
					vDSP.fill(&b1, with: 1)
					vDSP.multiply(a0, a2, result: &b0)
					vDSP.addSubtract(b1, b0, addResult: &b0, subtractResult: &b2)
					vDSP.divide(a0, a2, result: &a0)
					vDSP.addSubtract(b1, a0, addResult: &a0, subtractResult: &a2)
					vDSP.multiply(-2, a1, result: &b1)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.raw(let bₖ, let aₖ):
			guard bₖ.count == 3, aₖ.count == 3 else {
				throw Error.invalidChannel
			}
			let bk = try bₖ(interval: interval, capacity: capacity, instance: &instance)
			let ak = try aₖ(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					let b = $0.extracting(0*length..<3*length)
					let a = $0.extracting(3*length..<6*length)
					bk(moment, length, b.baseAddress.unsafelyUnwrapped, length)
					ak(moment, length, a.baseAddress.unsafelyUnwrapped, length)
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b.baseAddress.unsafelyUnwrapped, length,
										 a.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		}
	}
}
public func filter(_ source: Stream, lpf: (ω₀: Stream, quality: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .lpf(ω₀: lpf.ω₀, quality: lpf.quality))
}
public func filter(_ source: Stream, hpf: (ω₀: Stream, quality: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .hpf(ω₀: hpf.ω₀, quality: hpf.quality))
}
public func filter(_ source: Stream, bpf: (ω₀: Stream, quality: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .bpf(ω₀: bpf.ω₀, quality: bpf.quality))
}
public func filter(_ source: Stream, bsf: (ω₀: Stream, quality: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .bsf(ω₀: bsf.ω₀, quality: bsf.quality))
}
public func filter(_ source: Stream, apf: (ω₀: Stream, quality: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .apf(ω₀: apf.ω₀, quality: apf.quality))
}
public func filter(_ source: Stream, lsf: (ω₀: Stream, quality: Stream, gain: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .lsf(ω₀: lsf.ω₀, quality: lsf.quality, gain: lsf.gain))
}
public func filter(_ source: Stream, hsf: (ω₀: Stream, quality: Stream, gain: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .hsf(ω₀: hsf.ω₀, quality: hsf.quality, gain: hsf.gain))
}
public func filter(_ source: Stream, peq: (ω₀: Stream, quality: Stream, gain: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .peq(ω₀: peq.ω₀, quality: peq.quality, gain: peq.gain))
}
