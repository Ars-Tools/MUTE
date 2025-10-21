//
//  Operator+Ternary.swift
//  MUTE
//
//  Created by Kota on 5/16/R7.
//
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import protocol Synchronization.AtomicRepresentable
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import func Layout.broadcast
import func Layout.zip
@preconcurrency import protocol Combine.Publisher
@usableFromInline
enum OperatorTernary {
	@usableFromInline
	enum ASS {
		@usableFromInline
		protocol Raw: Stream {
			associatedtype Y
			associatedtype Z
			associatedtype YS: Publisher<(Int, Y), Never>
			associatedtype ZS: Publisher<(Int, Z), Never>
			@inlinable var x: Stream { get }
			@inlinable var y: YS { get }
			@inlinable var z: ZS { get }
			@inlinable var initial: (Y, Z) { get }
			@inlinable @inline(__always)
			static func`operator`(x: UnsafePointer<Float64>, ldx: Int,
								  y: UnsafePointer<Y>, incy: Int,
								  z: UnsafePointer<Z>, incz: Int,
								  w: UnsafeMutablePointer<Float64>, ldw: Int,
								  stream: Int, length: Int)
		}
		@usableFromInline
		protocol DSP: Raw {
			@inlinable @inline(__always)
			static func`operator`(x: some AccelerateBuffer<Float64>,
								  y: Y,
								  z: Z,
								  w: inout some AccelerateMutableBuffer<Float64>)
		}
	}
	@usableFromInline
	enum AAS {
		@usableFromInline
		protocol Raw: Stream {
			associatedtype Parameter
			associatedtype Z: Publisher<(Int, Parameter), Never>
			@inlinable var x: Stream { get }
			@inlinable var y: Stream { get }
			@inlinable var z: Z { get }
			@inlinable var initial: Parameter { get }
			@inlinable @inline(__always)
			static func`operator`(x: UnsafePointer<Float64>, ldx: Int,
								  y: UnsafePointer<Float64>, ldy: Int,
								  z: UnsafePointer<Parameter>, incz: Int,
								  w: UnsafeMutablePointer<Float64>, ldw: Int,
								  stream: Int, length: Int)
		}
		@usableFromInline
		protocol DSP: Raw {
			@inlinable @inline(__always)
			static func`operator`(x: some AccelerateBuffer<Float64>,
								  y: some AccelerateBuffer<Float64>,
								  z: Parameter,
								  w: inout some AccelerateMutableBuffer<Float64>)
		}
	}
	@usableFromInline
	enum ASA {
		@usableFromInline
		protocol Raw: Stream {
			associatedtype Parameter
			associatedtype Y: Publisher<(Int, Parameter), Never>
			@inlinable var x: Stream { get }
			@inlinable var y: Y { get }
			@inlinable var z: Stream { get }
			@inlinable var initial: Parameter { get }
			@inlinable @inline(__always)
			static func`operator`(x: UnsafePointer<Float64>, ldx: Int,
								  y: UnsafePointer<Parameter>, incy: Int,
								  z: UnsafePointer<Float64>, ldz: Int,
								  w: UnsafeMutablePointer<Float64>, ldw: Int,
								  stream: Int, length: Int)
		}
		@usableFromInline
		protocol DSP: Raw {
			@inlinable @inline(__always)
			static func`operator`(x: some AccelerateBuffer<Float64>,
								  y: Parameter,
								  z: some AccelerateBuffer<Float64>,
								  w: inout some AccelerateMutableBuffer<Float64>)
		}
	}
	@usableFromInline
	enum AAA {
		@usableFromInline
		protocol Raw: Stream {
			@inlinable var x: Stream { get }
			@inlinable var y: Stream { get }
			@inlinable var z: Stream { get }
			@inlinable @inline(__always)
			static func`operator`(x: UnsafePointer<Float64>, ldx: Int,
								  y: UnsafePointer<Float64>, ldy: Int,
								  z: UnsafePointer<Float64>, ldz: Int,
								  w: UnsafeMutablePointer<Float64>, ldw: Int,
								  stream: Int, length: Int)
		}
		@usableFromInline
		protocol DSP: Raw {
			@inlinable @inline(__always)
			static func`operator`(x: some AccelerateBuffer<Float64>,
								  y: some AccelerateBuffer<Float64>,
								  z: some AccelerateBuffer<Float64>,
								  w: inout some AccelerateMutableBuffer<Float64>)
		}
	}
}
extension OperatorTernary.ASS.Raw {
	@inlinable
	var count: Int { x.count }
}
extension OperatorTernary.ASS.Raw where Y == Float64, Z == Float64 {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try x(interval: interval, capacity: capacity, resource: &resource)
		switch x.count {
		case ..<1:
			throw Error.invalidChannel
		case 1:
			let yb = Atomic(initial.0)
			let zb = Atomic(initial.1)
			let ys = y.sink {
				switch $0 {
				case 0:
					yb.store($1, ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			let zs = z.sink {
				switch $0 {
				case 0:
					zb.store($1, ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return {
				xk($0, $1, $2, $3)
				var y = withExtendedLifetime(ys) { yb.load(ordering: .acquiring) }
				var z = withExtendedLifetime(zs) { zb.load(ordering: .acquiring) }
				Self.operator(x: $2, ldx: $3,
							  y: &y, incy: 0,
							  z: &z, incz: 0,
							  w: $2, ldw: $3,
							  stream: 1, length: $1)
			}
		case let stream: assert(2<=stream)
			let (yi, zi) = initial
			let yv = Mutex<Array<Float64>>(.init(repeating: yi, count: stream))
			let zv = Mutex<Array<Float64>>(.init(repeating: zi, count: stream))
			let ys = y.sink { index, value in
				yv.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			let zs = z.sink { index, value in
				zv.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return {
				xk($0, $1, $2, $3)
				let y = withExtendedLifetime(ys) { yv.withLock(\.self) }
				let z = withExtendedLifetime(zs) { zv.withLock(\.self) }
				Self.operator(x: $2, ldx: $3,
							  y: y, incy: 1,
							  z: z, incz: 1,
							  w: $2, ldw: $3,
							  stream: stream, length: $1)
			}
		}
	}
}
extension OperatorTernary.ASS.DSP {
	@inlinable @inline(__always)
	static func `operator`(x: UnsafePointer<Float64>, ldx: Int,
						   y: UnsafePointer<Y>, incy: Int,
						   z: UnsafePointer<Z>, incz: Int,
						   w: UnsafeMutablePointer<Float64>, ldw: Int,
						   stream: Int, length: Int) {
		for offset in (0..<stream).reversed() {
			let x = UnsafeBufferPointer(start: x.advanced(by: offset * ldx), count: length)
			var w = UnsafeMutableBufferPointer(start: w.advanced(by: offset * ldx), count: length)
			`operator`(x: x, y: y.advanced(by: offset * incy).pointee, z: z.advanced(by: offset * incz).pointee, w: &w)
		}
	}
}
extension OperatorTernary.AAS.Raw {
	@inlinable
	var count: Int {
		broadcast(x: x.count, y: y.count)
	}
}
extension OperatorTernary.AAS.Raw where Parameter == Float64 {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try x(interval: interval, capacity: capacity, resource: &resource)
		let yk = try y(interval: interval, capacity: capacity, resource: &resource)
		let xc = x.count
		let yc = y.count
		switch broadcast(x: xc, y: yc) {
		case 1:
			let zb = Atomic<Parameter>(initial)
			let zs = z.sink {
				switch $0 {
				case 0:
					zb.store($1, ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return { moment, length, result, stride in
				xk(moment, length, result, stride)
				var z = withExtendedLifetime(zs) { zb.load(ordering: .acquiring) }
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: length) {
					guard let source = $0.baseAddress else { return }
					yk(moment, length, source, length)
					Self.operator(x: result, ldx: stride,
								  y: source, ldy: length,
								  z: &z, incz: 0,
								  w: result, ldw: stride,
								  stream: 1, length: length)
				}
			}
		case xc:
			let zv = Mutex<Array<Parameter>>(.init(repeating: initial, count: xc))
			let ys = broadcast(target: xc, source: yc, stride: capacity)
			let zs = z.sink { index, value in
				zv.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, result, stride in
				xk(moment, length, result, stride)
				let z = withExtendedLifetime(zs) { zv.withLock(\.self) }
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: yc * capacity) {
					guard let source = $0.baseAddress else { return }
					yk(moment, length, source, capacity)
					Self.operator(x: result, ldx: stride,
								  y: source, ldy: ys,
								  z: z, incz: 1,
								  w: result, ldw: stride,
								  stream: xc, length: length)
				}
			}
		case yc:
			let zv = Mutex<Array<Parameter>>(.init(repeating: initial, count: yc))
			let xs = broadcast(target: yc, source: xc, stride: capacity)
			let zs = z.sink { index, value in
				zv.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, result, stride in
				yk(moment, length, result, stride)
				let z = withExtendedLifetime(zs) { zv.withLock(\.self) }
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * capacity) {
					guard let source = $0.baseAddress else { return }
					xk(moment, length, source, capacity)
					Self.operator(x: result, ldx: xs,
								  y: source, ldy: stride,
								  z: z, incz: 1,
								  w: result, ldw: stride,
								  stream: xc, length: length)
				}
			}
		case let wc:
			let zv = Mutex<Array<Float64>>(.init(repeating: initial, count: wc))
			let xs = broadcast(target: wc, source: xc, stride: capacity)
			let ys = broadcast(target: wc, source: yc, stride: capacity)
			let zs = z.sink { index, value in
				zv.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, result, stride in
				let z = withExtendedLifetime(zs) { zv.withLock(\.self) }
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: (xc + yc) * capacity) {
					let x = $0.baseAddress.unsafelyUnwrapped
					let y = x.advanced(by: xc * capacity)
					xk(moment, length, x, capacity)
					yk(moment, length, y, capacity)
					Self.operator(x: x, ldx: xs,
								  y: y, ldy: ys,
								  z: z, incz: 1,
								  w: result, ldw: stride,
								  stream: wc, length: length)
				}
			}
		}
	}
}
extension OperatorTernary.AAS.DSP {
	@inlinable @inline(__always)
	static func `operator`(x: UnsafePointer<Float64>, ldx: Int,
						   y: UnsafePointer<Float64>, ldy: Int,
						   z: UnsafePointer<Parameter>, incz: Int,
						   w: UnsafeMutablePointer<Float64>, ldw: Int,
						   stream: Int, length: Int) {
		for offset in (0..<stream).reversed() {
			let x = UnsafeBufferPointer(start: x.advanced(by: offset * ldx), count: length)
			let y = UnsafeBufferPointer(start: y.advanced(by: offset * ldx), count: length)
			var w = UnsafeMutableBufferPointer(start: w.advanced(by: offset * ldx), count: length)
			`operator`(x: x, y: y, z: z.advanced(by: offset * incz).pointee, w: &w)
		}
	}
}
extension OperatorTernary.ASA.Raw {
	@inlinable
	var count: Int {
		broadcast(x: x.count, y: z.count)
	}
}
extension OperatorTernary.ASA.Raw where Parameter == Float64 {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try x(interval: interval, capacity: capacity, resource: &resource)
		let zk = try z(interval: interval, capacity: capacity, resource: &resource)
		let xc = x.count
		let zc = z.count
		switch broadcast(x: xc, y: zc) {
		case 1:
			let yb = Atomic<Parameter>(initial)
			let ys = y.sink {
				switch $0 {
				case 0:
					yb.store($1, ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return { moment, length, result, stride in
				xk(moment, length, result, stride)
				var y = withExtendedLifetime(ys) { yb.load(ordering: .acquiring) }
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: length) {
					guard let source = $0.baseAddress else { return }
					zk(moment, length, source, length)
					Self.operator(x: result, ldx: stride,
								  y: &y, incy: 0,
								  z: source, ldz: length,
								  w: result, ldw: stride,
								  stream: 1, length: length)
				}
			}
		case xc:
			let yv = Mutex<Array<Parameter>>(.init(repeating: initial, count: xc))
			let zs = broadcast(target: xc, source: zc, stride: capacity)
			let ys = y.sink { index, value in
				yv.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, result, stride in
				xk(moment, length, result, stride)
				let y = withExtendedLifetime(ys) { yv.withLock(\.self) }
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: zc * capacity) {
					guard let source = $0.baseAddress else { return }
					zk(moment, length, source, capacity)
					Self.operator(x: result, ldx: stride,
								  y: y, incy: 1,
								  z: source, ldz: zs,
								  w: result, ldw: stride,
								  stream: xc, length: length)
				}
			}
		case zc:
			let xs = broadcast(target: zc, source: xc, stride: capacity)
			let yv = Mutex<Array<Parameter>>(.init(repeating: initial, count: zc))
			let ys = y.sink { index, value in
				yv.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, result, stride in
				zk(moment, length, result, stride)
				let y = withExtendedLifetime(ys) { yv.withLock(\.self) }
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * capacity) {
					guard let source = $0.baseAddress else { return }
					xk(moment, length, source, capacity)
					Self.operator(x: source, ldx: xs,
								  y: y, incy: 1,
								  z: result, ldz: stride,
								  w: result, ldw: stride,
								  stream: zc, length: length)
				}
			}
		case let wc:
			let xs = broadcast(target: wc, source: xc, stride: capacity)
			let yv = Mutex<Array<Parameter>>(.init(repeating: initial, count: wc))
			let zs = broadcast(target: wc, source: zc, stride: capacity)
			let ys = y.sink { index, value in
				yv.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, result, stride in
				let y = withExtendedLifetime(ys) { yv.withLock(\.self) }
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: (xc + zc) * capacity) {
					guard let x = $0.baseAddress else { return }
					let z = x.advanced(by: xc * capacity)
					xk(moment, length, x, capacity)
					zk(moment, length, z, capacity)
					Self.operator(x: x, ldx: xs,
								  y: y, incy: 1,
								  z: z, ldz: zs,
								  w: result, ldw: stride,
								  stream: wc, length: length)
				}
			}
		}
	}
}
extension OperatorTernary.ASA.DSP {
	@inlinable @inline(__always)
	static func `operator`(x: UnsafePointer<Float64>, ldx: Int,
						   y: UnsafePointer<Parameter>, incy: Int,
						   z: UnsafePointer<Float64>, ldz: Int,
						   w: UnsafeMutablePointer<Float64>, ldw: Int,
						   stream: Int, length: Int) {
		for offset in (0..<stream).reversed() {
			let x = UnsafeBufferPointer(start: x.advanced(by: offset * ldx), count: length)
			let z = UnsafeBufferPointer(start: z.advanced(by: offset * ldz), count: length)
			var w = UnsafeMutableBufferPointer(start: w.advanced(by: offset * ldw), count: length)
			`operator`(x: x, y: y.advanced(by: offset * incy).pointee, z: z, w: &w)
		}
	}
}
extension OperatorTernary.AAA.Raw {
	@inlinable
	var count: Int {
		broadcast(x: x.count, y: y.count, z: z.count)
	}
	@inlinable
	var dependencies: Array<Stream> {
		.init(arrayLiteral: x, y, z)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xc = x.count
		let yc = y.count
		let zc = z.count
		let xk = try x(interval: interval, capacity: capacity, resource: &resource)
		let yk = try y(interval: interval, capacity: capacity, resource: &resource)
		let zk = try z(interval: interval, capacity: capacity, resource: &resource)
		switch broadcast(x: xc, y: yc, z: zc) {
		case xc:
			let ys = broadcast(target: xc, source: yc, stride: capacity)
			let zs = broadcast(target: xc, source: zc, stride: capacity)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: (yc + zc) * capacity) {
					guard let y = $0.baseAddress else { return }
					let z = y.advanced(by: yc * capacity)
					xk(moment, length, result, stride)
					yk(moment, length, y, capacity)
					zk(moment, length, z, capacity)
					Self.operator(x: result, ldx: stride,
								  y: y, ldy: ys,
								  z: z, ldz: zs,
								  w: result, ldw: stride,
								  stream: xc, length: length)
				}
			}
		case yc:
			let zs = broadcast(target: yc, source: zc, stride: capacity)
			let xs = broadcast(target: yc, source: xc, stride: capacity)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: (zc + xc) * capacity) {
					guard let z = $0.baseAddress else { return }
					let x = z.advanced(by: zc * capacity)
					xk(moment, length, x, capacity)
					yk(moment, length, result, stride)
					zk(moment, length, z, capacity)
					Self.operator(x: x, ldx: xs,
								  y: result, ldy: stride,
								  z: z, ldz: zs,
								  w: result, ldw: stride,
								  stream: yc, length: length)
				}
			}
		case zc:
			let xs = broadcast(target: zc, source: xc, stride: capacity)
			let ys = broadcast(target: zc, source: yc, stride: capacity)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: (xc + yc) * capacity) {
					guard let x = $0.baseAddress else { return }
					let y = x.advanced(by: xc * capacity)
					xk(moment, length, x, capacity)
					yk(moment, length, y, capacity)
					zk(moment, length, result, stride)
					Self.operator(x: x, ldx: xs,
								  y: y, ldy: ys,
								  z: result, ldz: stride,
								  w: result, ldw: stride,
								  stream: zc, length: length)
				}
			}
		case let wc:
			assertionFailure("supposed not to be reached")
			let xs = broadcast(target: wc, source: xc, stride: capacity)
			let ys = broadcast(target: wc, source: yc, stride: capacity)
			let zs = broadcast(target: wc, source: zc, stride: capacity)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: (xc + yc + zc) * capacity) {
					guard let x = $0.baseAddress else { return }
					let y = x.advanced(by: xc * capacity)
					let z = y.advanced(by: yc * capacity)
					xk(moment, length, x, length)
					yk(moment, length, y, length)
					zk(moment, length, z, length)
					Self.operator(x: x, ldx: xs,
								  y: y, ldy: ys,
								  z: z, ldz: zs,
								  w: result, ldw: stride,
								  stream: wc, length: length)
				}
			}
		}
	}
}
extension OperatorTernary.AAA.DSP {
	@inlinable @inline(__always)
	static func`operator`(x: UnsafePointer<Float64>, ldx: Int,
						  y: UnsafePointer<Float64>, ldy: Int,
						  z: UnsafePointer<Float64>, ldz: Int,
						  w: UnsafeMutablePointer<Float64>, ldw: Int,
						  stream: Int, length: Int) {
		for offset in (0..<stream).reversed() {
			let x = UnsafeBufferPointer(start: x.advanced(by: offset * ldx), count: length)
			let y = UnsafeBufferPointer(start: y.advanced(by: offset * ldx), count: length)
			let z = UnsafeBufferPointer(start: z.advanced(by: offset * ldx), count: length)
			var w = UnsafeMutableBufferPointer(start: w.advanced(by: offset * ldx), count: length)
			`operator`(x: x, y: y, z: z, w: &w)
		}
	}
}
