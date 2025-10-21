//
//  Filter+Biquad.swift
//  MUTE
//
//  Created by Kota on 5/16/R7.
//
import typealias Synchronization.Mutex
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func Layout.broadcast
import func Accelerate.vDSP_biquadm_CreateSetupD
import func Accelerate.vDSP_biquadm_DestroySetupD
import func Accelerate.vDSP_biquadm_SetCoefficientsDoubleD
import func Accelerate.vDSP_biquadmD
import func simd.log2
import func NSP.universal_convolution
@preconcurrency import protocol Combine.Publisher
@usableFromInline
enum BiquadFilter {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Int, BiquadFilterDesign), Never> & Sendable>: Sendable {
		@usableFromInline let source: Stream
		@usableFromInline let design: Signal
		@usableFromInline let length: Int
	}
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
		}
	}
}
extension BiquadFilter.Kr: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, resource: &resource)
		let stream = source.count
		guard let opaque = vDSP_biquadm_CreateSetupD(repeatElement([1,0,0,0,0], count: stream * length).flatMap(\.self), .init(length), .init(stream)) else {
			throw Error.noBufferAssigned
		}
		let object = Autorelease.Opaque(pointer: opaque, release: vDSP_biquadm_DestroySetupD)
		let cancel = design.sink { channel, section, design in
			switch (channel, section) {
			case (0..<stream, 0..<length):
				vDSP_biquadm_SetCoefficientsDoubleD(object.pointer,
													design.coefficients(for: interval),
													.init(section), .init(channel),
													1, 1)
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
public func filter(_ source: Stream, cascade element: some Publisher<(Int, Int, BiquadFilterDesign), Never> & Sendable, length: Int) -> some Stream {
	BiquadFilter.Kr(source: source, design: element, length: length)
}
public func filter(_ source: Stream, cascade element: some Publisher<(Int, BiquadFilterDesign), Never>, length: Int) -> some Stream {
	filter(source, cascade: element.repeat(count: source.count).map { ($0, $1.0, $1.1) }, length: length)
}
public func filter(_ source: Stream, cascade element: some Collection<BiquadFilterDesign>) -> some Stream {
	filter(source, cascade: element.enumerated().publisher.map(\.self), length: element.count)
}
@_disfavoredOverload
public func filter(_ source: Stream, cascade design: BiquadFilterDesign...) -> some Stream {
	filter(source, cascade: design)
}
extension BiquadFilter.Ar: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try source(interval: interval, capacity: capacity, resource: &resource)
		let factor = 2.0 * .pi * interval.seconds
		let number = source.count
		let period = capacity + 2
		let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: 2 * number * period))
		switch design {
		case.lpf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, resource: &resource)
			let qk = try quality(interval: interval, capacity: capacity, resource: &resource)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = UnsafeMutableBufferPointer(rebasing: $0[(0*length)..<(1*length)])
					var b1 = UnsafeMutableBufferPointer(rebasing: $0[(1*length)..<(2*length)])
					var b2 = UnsafeMutableBufferPointer(rebasing: $0[(2*length)..<(3*length)])
					var a0 = UnsafeMutableBufferPointer(rebasing: $0[(3*length)..<(4*length)])
					var a1 = UnsafeMutableBufferPointer(rebasing: $0[(4*length)..<(5*length)])
					var a2 = UnsafeMutableBufferPointer(rebasing: $0[(5*length)..<(6*length)])
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
					buffer.withLock {
						$0.withUnsafeMutablePointer { x in
							let y = x.advanced(by: number * period)
							xk(moment, length, x.advanced(by: 2), period)
							universal_convolution(b0.baseAddress.unsafelyUnwrapped, length,
												  a0.baseAddress.unsafelyUnwrapped, length,
												  x, period,
												  y, period,
												  3, 3,
												  number, length)
							copy(x: y.advanced(by: 2), ldx: period,
								 y: result, ldy: stride,
								 rows: number, cols: length)
							copy(x: y.advanced(by: length), ldx: period,
								 y: y, ldy: period,
								 rows: number, cols: 2)
							copy(x: x.advanced(by: length), ldx: period,
								 y: x, ldy: period,
								 rows: number, cols: 2)
						}
					}
				}
			}
		case.hpf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, resource: &resource)
			let qk = try quality(interval: interval, capacity: capacity, resource: &resource)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = UnsafeMutableBufferPointer(rebasing: $0[(0*length)..<(1*length)])
					var b1 = UnsafeMutableBufferPointer(rebasing: $0[(1*length)..<(2*length)])
					var b2 = UnsafeMutableBufferPointer(rebasing: $0[(2*length)..<(3*length)])
					var a0 = UnsafeMutableBufferPointer(rebasing: $0[(3*length)..<(4*length)])
					var a1 = UnsafeMutableBufferPointer(rebasing: $0[(4*length)..<(5*length)])
					var a2 = UnsafeMutableBufferPointer(rebasing: $0[(5*length)..<(6*length)])
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
					buffer.withLock {
						$0.withUnsafeMutablePointer { x in
							let y = x.advanced(by: number * period)
							xk(moment, length, x.advanced(by: 2), period)
							universal_convolution(b0.baseAddress.unsafelyUnwrapped, length,
												  a0.baseAddress.unsafelyUnwrapped, length,
												  x, period,
												  y, period,
												  3, 3,
												  number, length)
							copy(x: y.advanced(by: 2), ldx: period,
								 y: result, ldy: stride,
								 rows: number, cols: length)
							copy(x: y.advanced(by: length), ldx: period,
								 y: y, ldy: period,
								 rows: number, cols: 2)
							copy(x: x.advanced(by: length), ldx: period,
								 y: x, ldy: period,
								 rows: number, cols: 2)
						}
					}
				}
			}
		case.bpf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, resource: &resource)
			let qk = try quality(interval: interval, capacity: capacity, resource: &resource)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = UnsafeMutableBufferPointer(rebasing: $0[(0*length)..<(1*length)])
					var b1 = UnsafeMutableBufferPointer(rebasing: $0[(1*length)..<(2*length)])
					var b2 = UnsafeMutableBufferPointer(rebasing: $0[(2*length)..<(3*length)])
					var a0 = UnsafeMutableBufferPointer(rebasing: $0[(3*length)..<(4*length)])
					var a1 = UnsafeMutableBufferPointer(rebasing: $0[(4*length)..<(5*length)])
					var a2 = UnsafeMutableBufferPointer(rebasing: $0[(5*length)..<(6*length)])
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
					buffer.withLock {
						$0.withUnsafeMutablePointer { x in
							let y = x.advanced(by: number * period)
							xk(moment, length, x.advanced(by: 2), period)
							universal_convolution(b0.baseAddress.unsafelyUnwrapped, length,
												  a0.baseAddress.unsafelyUnwrapped, length,
												  x, period,
												  y, period,
												  3, 3,
												  number, length)
							copy(x: y.advanced(by: 2), ldx: period,
								 y: result, ldy: stride,
								 rows: number, cols: length)
							copy(x: y.advanced(by: length), ldx: period,
								 y: y, ldy: period,
								 rows: number, cols: 2)
							copy(x: x.advanced(by: length), ldx: period,
								 y: x, ldy: period,
								 rows: number, cols: 2)
						}
					}
				}
			}
		case.bsf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, resource: &resource)
			let qk = try quality(interval: interval, capacity: capacity, resource: &resource)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = UnsafeMutableBufferPointer(rebasing: $0[(0*length)..<(1*length)])
					var b1 = UnsafeMutableBufferPointer(rebasing: $0[(1*length)..<(2*length)])
					var b2 = UnsafeMutableBufferPointer(rebasing: $0[(2*length)..<(3*length)])
					var a0 = UnsafeMutableBufferPointer(rebasing: $0[(3*length)..<(4*length)])
					var a1 = UnsafeMutableBufferPointer(rebasing: $0[(4*length)..<(5*length)])
					var a2 = UnsafeMutableBufferPointer(rebasing: $0[(5*length)..<(6*length)])
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
					buffer.withLock {
						$0.withUnsafeMutablePointer { x in
							let y = x.advanced(by: number * period)
							xk(moment, length, x.advanced(by: 2), period)
							universal_convolution(b0.baseAddress.unsafelyUnwrapped, length,
												  a0.baseAddress.unsafelyUnwrapped, length,
												  x, period,
												  y, period,
												  3, 3,
												  number, length)
							copy(x: y.advanced(by: 2), ldx: period,
								 y: result, ldy: stride,
								 rows: number, cols: length)
							copy(x: y.advanced(by: length), ldx: period,
								 y: y, ldy: period,
								 rows: number, cols: 2)
							copy(x: x.advanced(by: length), ldx: period,
								 y: x, ldy: period,
								 rows: number, cols: 2)
						}
					}
				}
			}
		case.apf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, resource: &resource)
			let qk = try quality(interval: interval, capacity: capacity, resource: &resource)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = UnsafeMutableBufferPointer(rebasing: $0[(0*length)..<(1*length)])
					var b1 = UnsafeMutableBufferPointer(rebasing: $0[(1*length)..<(2*length)])
					var b2 = UnsafeMutableBufferPointer(rebasing: $0[(2*length)..<(3*length)])
					var a0 = UnsafeMutableBufferPointer(rebasing: $0[(3*length)..<(4*length)])
					var a1 = UnsafeMutableBufferPointer(rebasing: $0[(4*length)..<(5*length)])
					var a2 = UnsafeMutableBufferPointer(rebasing: $0[(5*length)..<(6*length)])
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
					buffer.withLock {
						$0.withUnsafeMutablePointer { x in
							let y = x.advanced(by: number * period)
							xk(moment, length, x.advanced(by: 2), period)
							universal_convolution(b0.baseAddress.unsafelyUnwrapped, length,
												  a0.baseAddress.unsafelyUnwrapped, length,
												  x, period,
												  y, period,
												  3, 3,
												  number, length)
							copy(x: y.advanced(by: 2), ldx: period,
								 y: result, ldy: stride,
								 rows: number, cols: length)
							copy(x: y.advanced(by: length), ldx: period,
								 y: y, ldy: period,
								 rows: number, cols: 2)
							copy(x: x.advanced(by: length), ldx: period,
								 y: x, ldy: period,
								 rows: number, cols: 2)
						}
					}
				}
			}
		case.lsf(let ω₀, let quality, let gain):
			guard ω₀.count == 1, quality.count == 1, gain.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, resource: &resource)
			let qk = try quality(interval: interval, capacity: capacity, resource: &resource)
			let gk = try gain(interval: interval, capacity: capacity, resource: &resource)
			let dB = SIMD2<Float64>(repeating: log2(10.0)) / SIMD2<Float64>(40, 80)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = UnsafeMutableBufferPointer(rebasing: $0[(0*length)..<(1*length)])
					var b1 = UnsafeMutableBufferPointer(rebasing: $0[(1*length)..<(2*length)])
					var b2 = UnsafeMutableBufferPointer(rebasing: $0[(2*length)..<(3*length)])
					var a0 = UnsafeMutableBufferPointer(rebasing: $0[(3*length)..<(4*length)])
					var a1 = UnsafeMutableBufferPointer(rebasing: $0[(4*length)..<(5*length)])
					var a2 = UnsafeMutableBufferPointer(rebasing: $0[(5*length)..<(6*length)])
					var dc = UnsafeMutableBufferPointer(start: result, count: length)
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
					buffer.withLock {
						$0.withUnsafeMutablePointer { x in
							let y = x.advanced(by: number * period)
							xk(moment, length, x.advanced(by: 2), period)
							universal_convolution(b0.baseAddress.unsafelyUnwrapped, length,
												  a0.baseAddress.unsafelyUnwrapped, length,
												  x, period,
												  y, period,
												  3, 3,
												  number, length)
							copy(x: y.advanced(by: 2), ldx: period,
								 y: result, ldy: stride,
								 rows: number, cols: length)
							copy(x: y.advanced(by: length), ldx: period,
								 y: y, ldy: period,
								 rows: number, cols: 2)
							copy(x: x.advanced(by: length), ldx: period,
								 y: x, ldy: period,
								 rows: number, cols: 2)
						}
					}
				}
			}
		case.hsf(let ω₀, let quality, let gain):
			guard ω₀.count == 1, quality.count == 1, gain.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, resource: &resource)
			let qk = try quality(interval: interval, capacity: capacity, resource: &resource)
			let gk = try gain(interval: interval, capacity: capacity, resource: &resource)
			let dB = SIMD2<Float64>(repeating: log2(10.0)) / SIMD2<Float64>(40, 80)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = UnsafeMutableBufferPointer(rebasing: $0[(0*length)..<(1*length)])
					var b1 = UnsafeMutableBufferPointer(rebasing: $0[(1*length)..<(2*length)])
					var b2 = UnsafeMutableBufferPointer(rebasing: $0[(2*length)..<(3*length)])
					var a0 = UnsafeMutableBufferPointer(rebasing: $0[(3*length)..<(4*length)])
					var a1 = UnsafeMutableBufferPointer(rebasing: $0[(4*length)..<(5*length)])
					var a2 = UnsafeMutableBufferPointer(rebasing: $0[(5*length)..<(6*length)])
					var dc = UnsafeMutableBufferPointer(start: result, count: length)
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
					buffer.withLock {
						$0.withUnsafeMutablePointer { x in
							let y = x.advanced(by: number * period)
							xk(moment, length, x.advanced(by: 2), period)
							universal_convolution(b0.baseAddress.unsafelyUnwrapped, length,
												  a0.baseAddress.unsafelyUnwrapped, length,
												  x, period,
												  y, period,
												  3, 3,
												  number, length)
							copy(x: y.advanced(by: 2), ldx: period,
								 y: result, ldy: stride,
								 rows: number, cols: length)
							copy(x: y.advanced(by: length), ldx: period,
								 y: y, ldy: period,
								 rows: number, cols: 2)
							copy(x: x.advanced(by: length), ldx: period,
								 y: x, ldy: period,
								 rows: number, cols: 2)
						}
					}
				}
			}
		case.peq(let ω₀, let quality, let gain):
			guard ω₀.count == 1, quality.count == 1, gain.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, resource: &resource)
			let qk = try quality(interval: interval, capacity: capacity, resource: &resource)
			let gk = try gain(interval: interval, capacity: capacity, resource: &resource)
			let dB = log2(10.0) / 40.0
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = UnsafeMutableBufferPointer(rebasing: $0[(0*length)..<(1*length)])
					var b1 = UnsafeMutableBufferPointer(rebasing: $0[(1*length)..<(2*length)])
					var b2 = UnsafeMutableBufferPointer(rebasing: $0[(2*length)..<(3*length)])
					var a0 = UnsafeMutableBufferPointer(rebasing: $0[(3*length)..<(4*length)])
					var a1 = UnsafeMutableBufferPointer(rebasing: $0[(4*length)..<(5*length)])
					var a2 = UnsafeMutableBufferPointer(rebasing: $0[(5*length)..<(6*length)])
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
					buffer.withLock {
						$0.withUnsafeMutablePointer { x in
							let y = x.advanced(by: number * period)
							xk(moment, length, x.advanced(by: 2), period)
							universal_convolution(b0.baseAddress.unsafelyUnwrapped, length,
												  a0.baseAddress.unsafelyUnwrapped, length,
												  x, period,
												  y, period,
												  3, 3,
												  number, length)
							copy(x: y.advanced(by: 2), ldx: period,
								 y: result, ldy: stride,
								 rows: number, cols: length)
							copy(x: y.advanced(by: length), ldx: period,
								 y: y, ldy: period,
								 rows: number, cols: 2)
							copy(x: x.advanced(by: length), ldx: period,
								 y: x, ldy: period,
								 rows: number, cols: 2)
						}
					}
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
