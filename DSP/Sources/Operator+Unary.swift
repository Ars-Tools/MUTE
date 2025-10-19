//
//  Operator+Unary.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
@preconcurrency import Combine
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias Synchronization._Atomic64BitStorage
import protocol Synchronization.AtomicRepresentable
@usableFromInline
enum OperatorUnary {
	@usableFromInline
	enum Static {
		@usableFromInline
		protocol Raw: Stream {
			@inlinable
			var operand: Stream { get }
			@inlinable @inline(__always)
			func`operator`(x: UnsafePointer<Float64>, ldx: Int,
						   y: UnsafeMutablePointer<Float64>, ldy: Int,
						   stream: Int, length: Int)
		}
		@usableFromInline
		protocol DSP: Raw {
			@inlinable @inline(__always)
			func`operator`(x: some AccelerateBuffer<Float64>,
						   y: inout some AccelerateMutableBuffer<Float64>)
		}
	}
	@usableFromInline
	enum Signal {
		@usableFromInline
		protocol Raw: Stream {
			associatedtype Parameter: Numeric & Sendable
			associatedtype Signal: Publisher<(Int, Parameter), Never>
			@inlinable
			var operand: Stream { get }
			@inlinable
			var signal: Signal { get }
			@inlinable
			var initial: Parameter { get }
			@inlinable @inline(__always)
			func`operator`(x: UnsafePointer<Float64>, ldx: Int,
						   y: UnsafePointer<Parameter>, incy: Int,
						   z: UnsafeMutablePointer<Float64>, ldz: Int,
						   stream: Int, length: Int)
		}
		@usableFromInline
		protocol DSP: Raw {
			@inlinable @inline(__always)
			func`operator`(x: some AccelerateBuffer<Float64>,
						   y: Parameter,
						   z: inout some AccelerateMutableBuffer<Float64>)
		}
	}
	@usableFromInline
	enum Latest {
		@usableFromInline
		protocol Raw: Stream {
			@inlinable
			var operand: Stream { get }
			@inlinable
			var initial: Float64 { get }
			@inlinable @inline(__always)
			func`operator`(x: UnsafePointer<Float64>, ldx: Int,
						   y: UnsafeMutablePointer<Float64>, incy: Int,
						   z: UnsafeMutablePointer<Float64>, ldz: Int,
						   stream: Int, length: Int)
		}
		@usableFromInline
		protocol DSP: Raw {
			@inlinable @inline(__always)
			func`operator`(x: some AccelerateBuffer<Float64>,
						   y: inout Float64,
						   z: inout some AccelerateMutableBuffer<Float64>)
		}
	}
}
extension OperatorUnary.Static.Raw {
	@inlinable
	var count: Int {
		operand.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let stream = operand.count
		let kernel = try operand(interval: interval, capacity: capacity, instance: &instance)
		return {
			kernel($0, $1, $2, $3)
			`operator`(x: $2, ldx: $3, y: $2, ldy: $3, stream: stream, length: $1)
		}
	}
}
extension OperatorUnary.Static.DSP {
	@inlinable
	func`operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
		for idx in (0..<stream).reversed() {
			let x = UnsafeBufferPointer(start: x.advanced(by: idx * ldx), count: length)
			var y = UnsafeMutableBufferPointer(start: y.advanced(by: idx * ldy), count: length)
			`operator`(x: x, y: &y)
		}
	}
}
extension OperatorUnary.Signal.Raw {
	@inlinable
	var count: Int {
		operand.count
	}
}
extension OperatorUnary.Signal.Raw where Parameter == Float64 {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try operand(interval: interval, capacity: capacity, instance: &instance)
		switch operand.count {
		case ..<1:
			throw Error.invalidChannel
		case 1:
			let factor = Atomic<Parameter>(initial)
			let cancel = signal.sink {
				switch $0 {
				case 0:
					factor.store($1, ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return {
				var y = withExtendedLifetime(cancel) { factor.load(ordering: .acquiring) }
				kernel($0, $1, $2, $3)
				`operator`(x: $2, ldx: $3,
						   y: &y, incy: 0,
						   z: $2, ldz: $3,
						   stream: 1, length: $1)
			}
		case let stream: assert(2<=stream)
			let factor = Mutex<Array<Parameter>>(.init(repeating: initial, count: stream))
			let cancel = signal.sink { index, value in
				factor.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return {
				let y = withExtendedLifetime(cancel) { factor.withLock(\.self) }
				kernel($0, $1, $2, $3)
				`operator`(x: $2, ldx: $3,
						   y: y, incy: 1,
						   z: $2, ldz: $3,
						   stream: 1, length: $1)
			}
		}
	}
}
extension OperatorUnary.Signal.DSP where Parameter == Float64 {
	@inlinable @inline(__always)
	func`operator`(x: UnsafePointer<Float64>, ldx: Int,
				   y: UnsafePointer<Parameter>, incy: Int,
				   z: UnsafeMutablePointer<Float64>, ldz: Int,
				   stream: Int, length: Int) {
		for idx in 0..<stream {
			let x = UnsafeBufferPointer(start: x.advanced(by: idx * ldx), count: length)
			var z = UnsafeMutableBufferPointer(start: z.advanced(by: idx * ldz), count: length)
			`operator`(x: x, y: y.advanced(by: idx * incy).pointee, z: &z)
		}
	}
}
extension OperatorUnary.Latest.Raw {
	@inlinable
	var count: Int {
		operand.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try operand(interval: interval, capacity: capacity, instance: &instance)
		switch operand.count {
		case ..<1:
			throw Error.invalidChannel
		case 1:
			let latest = Atomic<Float64>(initial)
			return {
				kernel($0, $1, $2, $3)
				var r = latest.load(ordering: .acquiring)
				`operator`(x: $2, ldx: $3,
						   y: &r, incy: 0,
						   z: $2, ldz: $3,
						   stream: 1, length: $1)
				latest.store(r, ordering: .releasing)
			}
		case let stream: assert(2<=stream)
            let latest = Mutex<Array<Float64>>(.init(repeating: initial, count: stream))
			return { moment, length, target, stride in
				kernel(moment, length, target, stride)
                latest.withLock {
                    `operator`(x: target, ldx: stride,
                               y: &$0, incy: 1,
                               z: target, ldz: stride,
                               stream: stream, length: length)
                }
			}
		}
	}
}
extension OperatorUnary.Latest.DSP {
	@inlinable
	func`operator`(x: UnsafePointer<Float64>, ldx: Int,
						  y: UnsafeMutablePointer<Float64>, incy: Int,
						  z: UnsafeMutablePointer<Float64>, ldz: Int,
						  stream: Int, length: Int) {
		for idx in (0..<stream).reversed() {
			let x = UnsafeBufferPointer(start: x.advanced(by: idx * ldx), count: length)
			var z = UnsafeMutableBufferPointer(start: y.advanced(by: idx * ldz), count: length)
			`operator`(x: x, y: &y[idx * incy], z: &z)
		}
	}
}
enum ClosureUnary {
	@usableFromInline
	struct Static {
		@usableFromInline let operand: Stream
		@usableFromInline let closure: @Sendable (UnsafePointer<Float64>, Int,
												  UnsafeMutablePointer<Float64>, Int,
												  Int, Int) -> Void
	}
}
extension ClosureUnary.Static: OperatorUnary.Static.Raw {
	@usableFromInline
	func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
		closure(x, ldx, y, ldy, stream, length)
	}
}
public func apply(_ source: Stream, closure: @escaping @Sendable (UnsafeBufferPointer<Float64>, inout UnsafeMutableBufferPointer<Float64>) -> Void) -> some Stream {
	ClosureUnary.Static(operand: source) {
		for offset in (0..<$4).reversed() {
			let x = UnsafeBufferPointer(start: $0.advanced(by: offset * $1), count: $5)
			var y = UnsafeMutableBufferPointer(start: $2.advanced(by: offset * $3), count: $5)
			closure(x, &y)
		}
	}
}
