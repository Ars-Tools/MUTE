//
//  Graph+Undersample.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
import func Accelerate.vecLib.vDSP_vrampD
import func Accelerate.vecLib.vDSP_vindexD
import func Accelerate.vecLib.vDSP_vlintD
import func Accelerate.vecLib.vDSP_vqintD
import func CoreMedia.CMTimeAdd
import func CoreMedia.CMTimeMultiply
import func CoreMedia.CMTimeMultiplyByRatio
import typealias Numerics.Rational64
import typealias Accelerate.vDSP
public enum Undersample {
	public enum Interpolation: Sendable & Hashable {
		case none
		case linear
		case quadratic
	}
	@usableFromInline
	struct Ne {
		@usableFromInline let stream: Stream
		@usableFromInline let factor: Rational64
		@usableFromInline let smooth: Interpolation
	}
}
extension Undersample.Ne: Stream {
	@inlinable
	var count: Int {
		stream.count
	}
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let Δτ = CMTimeMultiplyByRatio(interval, multiplier: factor.denominator, divisor: factor.numerator)
		let fn = Int(factor.numerator)
		let fd = Int(factor.denominator)
		let factor = Float64(factor)
		let number = stream.count
		switch smooth {
		case.quadratic:
			let period = switch capacity.quotientAndRemainder(dividingBy: fd) {
			case (let q, let r):
				(q + r.signum()) * fn + 4
			}
			let kernel = try stream(interval: Δτ, capacity: period, instance: &instance)
			let buffer = Buffer(stream: number, period: period)
			return { t⁻, length, target, stride in
				let t⁺ = CMTimeAdd(t⁻, CMTimeMultiply(interval, multiplier: .init(length)))
				let s⁻ = t⁻.times(of: Δτ, rounding: .none)
				let s⁺ = t⁺.times(of: Δτ, rounding: .none)
				let u = Int(s⁻.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let v = Int(s⁺.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let w = ( s⁺.quotient + v ) - ( s⁻.quotient + u )
				var phasor = UnsafeMutableBufferPointer(start: target, count: length)
				vDSP.formRamp(withInitialValue: s⁻.remainder.seconds, increment: factor, result: &phasor)
				let memory = buffer.start
				kernel(CMTimeMultiply(Δτ, multiplier: .init(s⁻.quotient + u)), w, memory.advanced(by: 2 + u), period)
				for offset in (0..<number).reversed() {
					vDSP_vqintD(memory.advanced(by: offset * period),
								target, 1,
								target.advanced(by: offset * stride), 1,
								.init(length), .init(w + 2))
				}
				copy(x: memory.advanced(by: u + w - v), ldx: period,
					 y: memory, ldy: period,
					 rows: number, cols: 2 + v)
			}
		case.linear:
			let period = switch capacity.quotientAndRemainder(dividingBy: fd) {
			case (let q, let r):
				(q + r.signum()) * fn + 2
			}
			let kernel = try stream(interval: Δτ, capacity: period, instance: &instance)
			let buffer = Buffer(stream: number, period: period)
			return { t⁻, length, target, stride in
				let t⁺ = CMTimeAdd(t⁻, CMTimeMultiply(interval, multiplier: .init(length)))
				let s⁻ = t⁻.times(of: Δτ, rounding: .none)
				let s⁺ = t⁺.times(of: Δτ, rounding: .none)
				let u = Int(s⁻.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let v = Int(s⁺.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let w = ( s⁺.quotient + v ) - ( s⁻.quotient + u )
				var phasor = UnsafeMutableBufferPointer(start: target, count: length)
				vDSP.formRamp(withInitialValue: s⁻.remainder.seconds, increment: factor, result: &phasor)
				let memory = buffer.start
				kernel(CMTimeMultiply(Δτ, multiplier: .init(s⁻.quotient + u)), w, memory.advanced(by: 1 + u), period)
				for offset in (0..<number).reversed() {
					vDSP_vlintD(memory.advanced(by: offset * period),
								target, 1,
								target.advanced(by: offset * stride), 1,
								.init(length), .init(w + 1))
				}
				copy(x: memory.advanced(by: u + w - v), ldx: period,
					 y: memory, ldy: period,
					 rows: number, cols: 1 + v)
			}
		case.none:
			let period = switch capacity.quotientAndRemainder(dividingBy: fd) {
			case (let q, let r):
				(q + r.signum()) * fn + 0
			}
			let kernel = try stream(interval: Δτ, capacity: period, instance: &instance)
			let buffer = Buffer(stream: number, period: period)
			return { t⁻, length, target, stride in
				let t⁺ = CMTimeAdd(t⁻, CMTimeMultiply(interval, multiplier: .init(length)))
				let s⁻ = t⁻.times(of: Δτ, rounding: .none)
				let s⁺ = t⁺.times(of: Δτ, rounding: .none)
				let u = Int(s⁻.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let v = Int(s⁺.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let w = ( s⁺.quotient + v ) - ( s⁻.quotient + u )
				var phasor = UnsafeMutableBufferPointer(start: target, count: length)
				vDSP.formRamp(withInitialValue: s⁻.remainder.seconds, increment: factor, result: &phasor)
				let memory = buffer.start
				kernel(CMTimeMultiply(Δτ, multiplier: .init(s⁻.quotient + u)), w, memory.advanced(by: 0 + u), period)
				for offset in (0..<number).reversed() {
					vDSP_vindexD(memory.advanced(by: offset * period),
								 target, 1,
								 target.advanced(by: offset * stride), 1,
								 .init(length))
				}
				copy(x: memory.advanced(by: u + w - v), ldx: period,
					 y: memory, ldy: period,
					 rows: number, cols: 0 + v)
			}
		}
	}
}
public func undersample(_ source: Stream, factor: Rational64, smooth: Undersample.Interpolation = .linear) -> some Stream {
	Undersample.Ne(stream: source, factor: factor, smooth: smooth)
}
