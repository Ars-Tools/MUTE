//
//  Graph+Undersample.swift
//  MUTE
//
//  Created by Kota on 6/25/R7.
//
import func Accelerate.vDSP_vqintD
import CoreMedia
import Numerics
import struct Synchronization.Mutex
import typealias Accelerate.vDSP
@usableFromInline
enum Undersample {
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
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let Δτ = CMTimeMultiplyByRatio(interval, multiplier: factor.denominator, divisor: factor.numerator)
		let fn = Int(factor.numerator)
		let fd = Int(factor.denominator)
		let number = stream.count
		switch smooth {
		case.quadratic:
			let period = switch capacity.quotientAndRemainder(dividingBy: fd) {
			case (let q, let r):
				(q + r.signum()) * fn + 4
			}
			let kernel = try stream(interval: Δτ, capacity: period, resource: &resource)
			let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: number * period))
			return { t⁻, length, result, stride in
				let t⁺ = CMTimeAdd(t⁻, CMTimeMultiply(interval, multiplier: .init(length)))
				let s⁻ = t⁻.times(of: Δτ, rounding: .none)
				let s⁺ = t⁺.times(of: Δτ, rounding: .none)
				let u = Int(s⁻.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let v = Int(s⁺.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let w = ( s⁺.quotient + v ) - ( s⁻.quotient + u )
				let phasor = vDSP.ramp(withInitialValue: s⁻.remainder.seconds, increment: .init(fn) / .init(fd), count: length)
				buffer.withLock { $0.withUnsafeMutablePointer {
					kernel(CMTimeMultiply(Δτ, multiplier: .init(s⁻.quotient + u)), w, $0.advanced(by: 2 + u), period)
					for offset in 0..<number {
						vDSP_vqintD($0.advanced(by: offset * period),
									phasor, 1,
									result.advanced(by: offset * stride), 1,
									.init(length), .init(w + 2))
					}
					copy(x: $0.advanced(by: u + w - v), ldx: period,
						 y: $0, ldy: period,
						 rows: number, cols: 2 + v)
				}}
			}
		case.linear:
			let period = switch capacity.quotientAndRemainder(dividingBy: fd) {
			case (let q, let r):
				(q + r.signum()) * fn + 2
			}
			let kernel = try stream(interval: Δτ, capacity: period, resource: &resource)
			let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: number * period))
			return { t⁻, length, result, stride in
				let t⁺ = CMTimeAdd(t⁻, CMTimeMultiply(interval, multiplier: .init(length)))
				let s⁻ = t⁻.times(of: Δτ, rounding: .none)
				let s⁺ = t⁺.times(of: Δτ, rounding: .none)
				let u = Int(s⁻.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let v = Int(s⁺.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let w = ( s⁺.quotient + v ) - ( s⁻.quotient + u )
				let phasor = vDSP.ramp(withInitialValue: s⁻.remainder.seconds, increment: .init(fn) / .init(fd), count: length)
				buffer.withLock { $0.withUnsafeMutablePointer {
					kernel(CMTimeMultiply(Δτ, multiplier: .init(s⁻.quotient + u)), w, $0.advanced(by: 1 + u), period)
					for offset in (0..<number).reversed() {
						var result = UnsafeMutableBufferPointer(start: result.advanced(by: offset * stride), count: length)
						vDSP.linearInterpolate(elementsOf: UnsafeBufferPointer(start: $0.advanced(by: offset * period), count: length),
											   using: phasor,
											   result: &result)
					}
					copy(x: $0.advanced(by: u + w - v), ldx: period,
						 y: $0, ldy: period,
						 rows: number, cols: 1 + v)
				}}
			}
		case.none:
			let period = switch capacity.quotientAndRemainder(dividingBy: fd) {
			case (let q, let r):
				(q + r.signum()) * fn + 0
			}
			let kernel = try stream(interval: Δτ, capacity: period, resource: &resource)
			let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: number * period))
			return { t⁻, length, result, stride in
				let t⁺ = CMTimeAdd(t⁻, CMTimeMultiply(interval, multiplier: .init(length)))
				let s⁻ = t⁻.times(of: Δτ, rounding: .none)
				let s⁺ = t⁺.times(of: Δτ, rounding: .none)
				let u = Int(s⁻.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let v = Int(s⁺.remainder.convertScale(1, method: .roundAwayFromZero).value)
				let w = ( s⁺.quotient + v ) - ( s⁻.quotient + u )
				let phasor = vDSP.ramp(withInitialValue: s⁻.remainder.seconds + 1, increment: .init(fn) / .init(fd), count: length).map(UInt.init)
				buffer.withLock { $0.withUnsafeMutablePointer {
					kernel(CMTimeMultiply(Δτ, multiplier: .init(s⁻.quotient + u)), w, $0.advanced(by: 0 + u), period)
					for offset in 0..<number {
						var result = UnsafeMutableBufferPointer(start: $0.advanced(by: offset * stride), count: length)
						vDSP.gather(UnsafeBufferPointer(start: $0.advanced(by: offset * period), count: length), indices: phasor, result: &result)
					}
					copy(x: $0.advanced(by: u + w - v), ldx: period,
						 y: $0, ldy: period,
						 rows: number, cols: 0 + v)
				}}
			}
		}
	}
}
public func undersample(_ source: Stream, factor: Rational64, smooth: Interpolation = .linear) -> some Stream {
	Undersample.Ne(stream: source, factor: factor, smooth: smooth)
}
