//
//  Operator+Binary.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import func Layout.broadcast
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
@preconcurrency import protocol Combine.Publisher
@usableFromInline
enum OperatorBinary {
	@usableFromInline
	protocol LHSRaw: Stream {
		associatedtype Parameter
		associatedtype Signal: Publisher<(Int, Parameter), Never>
		@inlinable
		var lhs: Stream { get }
		@inlinable
		var rhs: Signal { get }
		@inlinable @inline(__always)
		var initial: Parameter { get }
		@inlinable @inline(__always)
		func`operator`(x: UnsafePointer<Float64>, ldx: Int,
					   y: UnsafePointer<Parameter>, incy: Int,
					   z: UnsafeMutablePointer<Float64>, ldz: Int,
					   stream: Int, length: Int)
	}
	@usableFromInline
	protocol LHSDSP: LHSRaw {
		@inlinable @inline(__always)
		func`operator`(x: some AccelerateBuffer<Float64>, y: Parameter, z: inout some AccelerateMutableBuffer<Float64>)
	}
	@usableFromInline
	protocol RHSRaw: Stream {
		associatedtype Parameter
		associatedtype Signal: Publisher<(Int, Parameter), Never>
		@inlinable
		var lhs: Signal { get }
		@inlinable
		var rhs: Stream { get }
		@inlinable @inline(__always)
		var initial: Parameter { get }
		@inlinable @inline(__always)
		func`operator`(x: UnsafePointer<Parameter>, incx: Int,
					   y: UnsafePointer<Float64>, ldy: Int,
					   z: UnsafeMutablePointer<Float64>, ldz: Int,
					   stream: Int, length: Int)
	}
	@usableFromInline
	protocol RHSDSP: RHSRaw {
		@inlinable @inline(__always)
		func`operator`(x: Parameter, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>)
	}
	@usableFromInline
	protocol Raw: Stream {
		@inlinable
		var lhs: Stream { get }
		@inlinable
		var rhs: Stream { get }
		@inlinable @inline(__always)
		func`operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int)
	}
	@usableFromInline
	protocol DSP: Raw {
		@inlinable @inline(__always)
		func`operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>)
	}
}
extension OperatorBinary.LHSRaw {
	@inlinable
	var count: Int { lhs.count }
}
extension OperatorBinary.LHSRaw where Parameter == Float64 {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try lhs(interval: interval, capacity: capacity, instance: &instance)
		switch lhs.count {
		case ...0:
			throw Error.invalidChannel
		case 1:
			let factor = Atomic<Float64>(initial)
			let cancel = rhs.sink {
				switch $0 {
				case 0:
					factor.store($1, ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return {
				kernel($0, $1, $2, $3)
				var v = withExtendedLifetime(cancel) { factor.load(ordering: .acquiring) }
				`operator`(x: $2, ldx: $3,
						   y: &v, incy: 0,
						   z: $2, ldz: $3,
						   stream: 1, length: $1)
			}
		case let stream: assert(2<=stream)
			let factor = Mutex<Array<Float64>>(.init(repeating: initial, count: lhs.count))
			let cancel = rhs.sink { index, value in
				factor.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, target, stride in
				kernel(moment, length, target, stride)
				let factor = withExtendedLifetime(cancel) { factor.withLock(\.self) }
				`operator`(x: target, ldx: stride,
						   y: factor, incy: 1,
						   z: target, ldz: stride,
						   stream: stream, length: length)
			}
		}
	}
}
extension OperatorBinary.LHSDSP {
	@inlinable @inline(__always)
	func`operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Parameter>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
		for offset in (0..<stream).reversed() {
			let x = UnsafeBufferPointer(start: x.advanced(by: offset * ldx), count: length)
			let y = y.advanced(by: offset * incy).pointee
			var z = UnsafeMutableBufferPointer(start: z.advanced(by: offset * ldz), count: length)
			`operator`(x: x, y: y, z: &z)
		}
	}
}
extension OperatorBinary.RHSRaw {
	@inlinable
	var count: Int { rhs.count }
}
extension OperatorBinary.RHSRaw where Parameter == Float64 {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try rhs(interval: interval, capacity: capacity, instance: &instance)
		switch rhs.count {
		case ..<1:
			throw Error.invalidChannel
		case 1:
			let factor = Atomic<Parameter>(initial)
			let cancel = lhs.sink {
				switch $0 {
				case 0:
					factor.store($1, ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return {
				kernel($0, $1, $2, $3)
				var v = withExtendedLifetime(cancel) { factor.load(ordering: .acquiring) }
				`operator`(x: &v, incx: 0,
						   y: $2, ldy: $3,
						   z: $2, ldz: $3,
						   stream: 1, length: $1)
			}
		case let stream: assert(2<=stream)
			let factor = Mutex<Array<Float64>>(.init(repeating: initial, count: stream))
			let cancel = lhs.sink { index, value in
				factor.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, target, stride in
				kernel(moment, length, target, stride)
				let factor = withExtendedLifetime(cancel) { factor.withLock(\.self) }
				`operator`(x: factor, incx: 1,
						   y: target, ldy: stride,
						   z: target, ldz: stride,
						   stream: stream, length: length)
			}
		}
	}
}
extension OperatorBinary.RHSDSP {
	@inlinable @inline(__always)
	func `operator`(x: UnsafePointer<Parameter>, incx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
		for offset in (0..<stream).reversed() {
			let x = x.advanced(by: offset * incx)
			let y = UnsafeBufferPointer(start: y.advanced(by: offset * ldy), count: length)
			var z = UnsafeMutableBufferPointer(start: z.advanced(by: offset * ldz), count: length)
			`operator`(x: x.pointee, y: y, z: &z)
		}
	}
}
extension OperatorBinary.Raw {
	@inlinable
	var count: Int { broadcast(x: lhs.count, y: rhs.count) }
	@inlinable @inline(__always)
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xc = lhs.count
		let yc = rhs.count
		let xk = try lhs(interval: interval, capacity: capacity, instance: &instance)
		let yk = try rhs(interval: interval, capacity: capacity, instance: &instance)
		return switch broadcast(x: xc, y: yc) {
		case xc:
			{ moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: yc * length) {
					guard let ym = $0.baseAddress else { return }
					xk(moment, length, result, stride)
					yk(moment, length, ym, length)
					`operator`(x: result, ldx: stride,
							   y: ym, ldy: broadcast(target: xc, source: yc, stride: length),
							   z: result, ldz: stride,
							   stream: xc, length: length)
				}
			}
		case yc:
			{ moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length) {
					guard let xm = $0.baseAddress else { return }
					xk(moment, length, xm, length)
					yk(moment, length, result, stride)
					`operator`(x: xm, ldx: broadcast(target: yc, source: xc, stride: length),
							   y: result, ldy: stride,
							   z: result, ldz: stride,
							   stream: yc, length: length)
				}
			}
		case let zc:
			{ moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( xc + yc ) * length) {
					let xm = $0.baseAddress.unsafelyUnwrapped
					let ym = xm.advanced(by: xc * length)
					xk(moment, length, xm, length)
					yk(moment, length, ym, length)
					`operator`(x: xm, ldx: broadcast(target: zc, source: xc, stride: length),
							   y: ym, ldy: broadcast(target: zc, source: yc, stride: length),
							   z: result, ldz: stride,
							   stream: zc, length: length)
				}
			}
		}
	}
}
extension OperatorBinary.DSP {
	@inlinable @inline(__always)
	func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
		for offset in (0..<stream).reversed() {
			let x = UnsafeBufferPointer(start: x.advanced(by: offset * ldx), count: length)
			let y = UnsafeBufferPointer(start: y.advanced(by: offset * ldy), count: length)
			var z = UnsafeMutableBufferPointer(start: z.advanced(by: offset * ldz), count: length)
			`operator`(x: x, y: y, z: &z)
		}
	}
}
