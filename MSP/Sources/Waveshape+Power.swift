//
//  Waveshape+Power.swift
//  MUTE
//
//  Created by Kota on 6/27/R7.
//
@preconcurrency import protocol Combine.Publisher
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vForce
import typealias Synchronization.Mutex
import func Accelerate.vvfabs
import func Accelerate.vvpows
import func Accelerate.vvpow
import func Accelerate.vvcopysign
import func Layout.broadcast
import func NSP.vvexp10
// MARK: Pow
@usableFromInline
enum Pow {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline let sign: Bool
		@usableFromInline let significand: Stream
		@usableFromInline let exponent: Signal
	}
	@usableFromInline
	struct Ar {
		@usableFromInline let sign: Bool
		@usableFromInline let significand: Stream
		@usableFromInline let exponent: Stream
	}
}
extension Pow.Kr: Stream {
	@inlinable
	var count: Int {
		significand.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try significand(interval: interval, capacity: capacity, resource: &resource)
		let factor = Mutex<Array<Float64>>(.init(repeating: 1, count: significand.count))
		let cancel = exponent.sink { index, value in
			factor.withLock {
				switch index {
				case $0.indices:
					$0[index] = value
				default:
					assertionFailure("out of range")
				}
			}
		}
		return if sign {
			{ moment, length, target, stride in
				let factor = withExtendedLifetime(cancel) { factor.withLock(\.self) }
				kernel(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: length) {
					guard let memory = $0.baseAddress else { return }
					withUnsafePointer(to: Int32(length)) {
						for (offset, var element) in factor.enumerated() {
							let target = target.advanced(by: offset * stride)
							vvfabs(memory, target, $0)
							vvpows(memory, &element, memory, $0)
							vvcopysign(target, memory, target, $0)
						}
					}
				}
			}
		} else {
			{ moment, length, target, stride in
				let factor = withExtendedLifetime(cancel) { factor.withLock(\.self) }
				kernel(moment, length, target, stride)
				withUnsafePointer(to: Int32(length)) {
					for (offset, var element) in factor.enumerated() {
						let target = target.advanced(by: offset * stride)
						vvpows(target, &element, target, $0)
					}
				}
			}
		}
	}
}
extension Pow.Ar: Stream {
	@inlinable
	var count: Int {
		broadcast(x: significand.count, y: exponent.count)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xc = significand.count
		let yc = exponent.count
		let xk = try significand(interval: interval, capacity: capacity, resource: &resource)
		let yk = try exponent(interval: interval, capacity: capacity, resource: &resource)
		return switch (broadcast(x: xc, y: yc), sign) {
		case (xc, true):
			{ moment, length, target, stride in
				xk(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length + length) {
					guard let buffer = $0.baseAddress else { return }
					let memory = buffer.advanced(by: length)
					let ys = broadcast(target: xc, source: yc, stride: length)
					yk(moment, length, memory, length)
					withUnsafePointer(to: Int32(length)) {
						for offset in (0..<xc).reversed() {
							vvfabs(buffer, target.advanced(by: offset * stride), $0)
							vvpow(buffer, memory.advanced(by: offset * ys), buffer, $0)
							vvcopysign(target.advanced(by: offset * stride), buffer, target.advanced(by: offset * stride), $0)
						}
					}
				}
			}
		case (xc, false):
			{ moment, length, target, stride in
				xk(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length) {
					guard let memory = $0.baseAddress else { return }
					let ys = broadcast(target: xc, source: yc, stride: length)
					yk(moment, length, memory, length)
					withUnsafePointer(to: Int32(length)) {
						for offset in (0..<xc).reversed() {
							vvpow(target.advanced(by: offset * stride), memory.advanced(by: offset * ys), target.advanced(by: offset * stride), $0)
						}
					}
				}
			}
		case (yc, true):
			{ moment, length, target, stride in
				yk(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length + length) {
					guard let buffer = $0.baseAddress else { return }
					let memory = buffer.advanced(by: length)
					let xs = broadcast(target: yc, source: xc, stride: length)
					xk(moment, length, memory, length)
					withUnsafePointer(to: Int32(length)) {
						for offset in (0..<yc).reversed() {
							vvfabs(buffer, memory.advanced(by: offset * xs), $0)
							vvpow(buffer, target.advanced(by: offset * stride), buffer, $0)
							vvcopysign(target.advanced(by: offset * stride), buffer, memory.advanced(by: offset * xs), $0)
						}
					}
				}
			}
		case (yc, false):
			{ moment, length, target, stride in
				yk(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length) {
					guard let memory = $0.baseAddress else { return }
					let xs = broadcast(target: yc, source: xc, stride: length)
					xk(moment, length, memory, length)
					withUnsafePointer(to: Int32(length)) {
						for offset in (0..<yc).reversed() {
							vvpow(target.advanced(by: offset * stride), target.advanced(by: offset * stride), memory.advanced(by: offset * xs), $0)
						}
					}
				}
			}
		default:
			throw Error.invalidChannel
		}
	}
}
public func pow(_ significand: Stream, _ exponent: some Publisher<(Int, Float64), Never> & Sendable, sign: Bool = false) -> some Stream {
	Pow.Kr(sign: sign, significand: significand, exponent: exponent)
}
public func pow(_ significand: Stream, _ exponent: some Publisher<Float64, Never>, sign: Bool = false) -> some Stream {
	pow(significand, exponent.repeat(count: significand.count), sign: sign)
}
public func pow(_ significand: Stream, _ exponent: some Sequence<Float64>, sign: Bool = false) -> some Stream {
	pow(significand, exponent.prefix(count: significand.count), sign: sign)
}
public func pow(_ significand: Stream, _ exponent: Float64, sign: Bool = false) -> some Stream {
	pow(significand, `repeat`(exponent, count: significand.count), sign: sign)
}
public func pow(_ significand: Stream, _ exponent: Stream, sign: Bool = false) -> some Stream {
	Pow.Ar(sign: sign, significand: significand, exponent: exponent)
}
// MARK: Log
@usableFromInline
enum Log {
	@usableFromInline
	struct He: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.log(x, result: &y)
		}
	}
}
@usableFromInline
enum Log2 {
	@usableFromInline
	struct He: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.log2(x, result: &y)
		}
	}
}
@usableFromInline
enum Log10 {
	@usableFromInline
	struct He: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.log10(x, result: &y)
		}
	}
}
@usableFromInline
enum Log1p {
	@usableFromInline
	struct He: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.log1p(x, result: &y)
		}
	}
}
public func log(_ source: Stream) -> some Stream {
	Log.He(operand: source)
}
public func log2(_ source: Stream) -> some Stream {
	Log2.He(operand: source)
}
public func log10(_ source: Stream) -> some Stream {
	Log10.He(operand: source)
}
public func log1p(_ source: Stream) -> some Stream {
	Log1p.He(operand: source)
}
// MARK: Exp
@usableFromInline
enum Exp {
	@usableFromInline
	struct He: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.exp(x, result: &y)
		}
	}
}
@usableFromInline
enum Exp2 {
	@usableFromInline
	struct He: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.exp2(x, result: &y)
		}
	}
}
@usableFromInline
enum Exp10 {
	@usableFromInline
	struct He: OperatorUnary.Static.Raw {
		@usableFromInline let operand: Stream
		@inlinable
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
			for offset in 0..<stream {
				vvexp10(y.advanced(by: offset * ldy),
						x.advanced(by: offset * ldx),
						length)
			}
		}
	}
}
@usableFromInline
enum Expm1 {
	@usableFromInline
	struct He: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.expm1(x, result: &y)
		}
	}
}
public func exp(_ source: Stream) -> some Stream {
	Exp.He(operand: source)
}
public func exp2(_ source: Stream) -> some Stream {
	Exp2.He(operand: source)
}
public func exp10(_ source: Stream) -> some Stream {
	Exp10.He(operand: source)
}
public func expm1(_ source: Stream) -> some Stream {
	Expm1.He(operand: source)
}
