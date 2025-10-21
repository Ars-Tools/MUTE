//
//  Waveshape+Special.swift
//  MUTE
//
//  Created by Kota on 6/27/R7.
//
@preconcurrency import protocol Combine.Publisher
import func NSP.vvj0
import func NSP.vvj1
import func NSP.vvjn
import func NSP.vvy0
import func NSP.vvy1
import func NSP.vvyn
import func NSP.vverf
import func NSP.vverfc
import func NSP.vvtgamma
import func NSP.vvlgamma
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
// MARK: J₀
@usableFromInline
enum J₀ {
	@usableFromInline
	struct He: OperatorUnary.Static.Raw {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
			for offset in (0..<stream).reversed() {
				vvj0(y.advanced(by: offset * ldy),
					 x.advanced(by: offset * ldx),
					 length)
			}
		}
	}
}
public func j₀(_ stream: Stream) -> some Stream {
	J₀.He(operand: stream)
}
// MARK: J₁
@usableFromInline
enum J₁ {
	@usableFromInline
	struct He: OperatorUnary.Static.Raw {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
			for offset in (0..<stream).reversed() {
				vvj1(y.advanced(by: offset * ldy),
					 x.advanced(by: offset * ldx),
					 length)
			}
		}
	}
}
public func j₁(_ stream: Stream) -> some Stream {
	J₁.He(operand: stream)
}
// MARK: Jₙ
@usableFromInline
enum Jₙ {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Order), Never> & Sendable, Order: BinaryInteger> {
		@usableFromInline let operand: Stream
		@usableFromInline let order: Signal
	}
}
extension Jₙ.Kr: Stream {
	@inlinable
	var count: Int {
		operand.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try operand(interval: interval, capacity: capacity, resource: &resource)
		switch operand.count {
		case ...0:
			throw Error.invalidChannel
		case 1:
			let factor = Atomic<Int>(.zero)
			let cancel = order.sink {
				switch $0 {
				case 0:
					factor.store(.init($1), ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return {
				var factor = withExtendedLifetime(cancel) { factor.load(ordering: .acquiring) }
				kernel($0, $1, $2, $3)
				vvjn($2, $2, &factor, $1)
			}
		case let n:assert(2<=n)
			let factor = Mutex<Array<Int>>(.init(repeating: .zero, count: n))
			let cancel = order.sink { index, value in
				factor.withLock {
					switch index {
					case $0.indices:
						$0[index] = .init(value)
					default:
						assertionFailure("out of range")
					}
				}
			}
			return {
				let factor = withExtendedLifetime(cancel) { factor.withLock(\.self) }
				kernel($0, $1, $2, $3)
				for (offset, var element) in factor.enumerated() {
					vvjn($2.advanced(by: offset * $3),
						 $2.advanced(by: offset * $3),
						 &element,
						 $1)
				}
			}
		}
	}
}
public func jₙ(_ stream: Stream, order: some Publisher<(Int, some BinaryInteger), Never> & Sendable) -> some Stream {
	Jₙ.Kr(operand: stream, order: order)
}
public func jₙ(_ stream: Stream, order: some Publisher<some BinaryInteger, Never>) -> some Stream {
	jₙ(stream, order: order.repeat(count: stream.count))
}
public func jₙ(_ stream: Stream, order: some Sequence<some BinaryInteger>) -> some Stream {
	jₙ(stream, order: order.prefix(count: stream.count))
}
public func jₙ(_ stream: Stream, order: some BinaryInteger) -> some Stream {
	jₙ(stream, order: `repeat`(order, count: stream.count))
}
// MARK Y₀
@usableFromInline
enum Y₀ {
	@usableFromInline
	struct He: OperatorUnary.Static.Raw {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
			for offset in (0..<stream).reversed() {
				vvy0(y.advanced(by: offset * ldy),
					 x.advanced(by: offset * ldx),
					 length)
			}
		}
	}
}
public func y₀(_ stream: Stream) -> some Stream {
	Y₀.He(operand: stream)
}
// MARK: Y₁
@usableFromInline
enum Y₁ {
	@usableFromInline
	struct He: OperatorUnary.Static.Raw {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
			for offset in (0..<stream).reversed() {
				vvy1(y.advanced(by: offset * ldy),
					 x.advanced(by: offset * ldx),
					 length)
			}
		}
	}
}
public func y₁(_ stream: Stream) -> some Stream {
	Y₁.He(operand: stream)
}
// MARK: Yn
@usableFromInline
enum Yₙ {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Order), Never> & Sendable, Order: BinaryInteger> {
		@usableFromInline let operand: Stream
		@usableFromInline let order: Signal
	}
}
extension Yₙ.Kr: Stream {
	@inlinable
	var count: Int {
		operand.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try operand(interval: interval, capacity: capacity, resource: &resource)
		switch operand.count {
		case ...0:
			throw Error.invalidChannel
		case 1:
			let factor = Atomic<Int>(.zero)
			let cancel = order.sink {
				switch $0 {
				case 0:
					factor.store(.init($1), ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return {
				var factor = withExtendedLifetime(cancel) { factor.load(ordering: .acquiring) }
				kernel($0, $1, $2, $3)
				vvyn($2, $2, &factor, $1)
			}
		case let n:assert(2<=n)
			let factor = Mutex<Array<Int>>(.init(repeating: .zero, count: n))
			let cancel = order.sink { index, value in
				factor.withLock {
					switch index {
					case $0.indices:
						$0[index] = .init(value)
					default:
						assertionFailure("out of range")
					}
				}
			}
			return {
				let factor = withExtendedLifetime(cancel) { factor.withLock(\.self) }
				kernel($0, $1, $2, $3)
				for (offset, var element) in factor.enumerated() {
					vvyn($2.advanced(by: offset * $3),
						 $2.advanced(by: offset * $3),
						 &element,
						 $1)
				}
			}
		}
	}
}
public func yₙ(_ stream: Stream, order: some Publisher<(Int, some BinaryInteger), Never> & Sendable) -> some Stream {
	Yₙ.Kr(operand: stream, order: order)
}
public func yₙ(_ stream: Stream, order: some Publisher<some BinaryInteger, Never>) -> some Stream {
	yₙ(stream, order: order.repeat(count: stream.count))
}
public func yₙ(_ stream: Stream, order: some Sequence<some BinaryInteger>) -> some Stream {
	yₙ(stream, order: order.prefix(count: stream.count))
}
public func yₙ(_ stream: Stream, order: some BinaryInteger) -> some Stream {
	yₙ(stream, order: `repeat`(order, count: stream.count))
}
// MARK: ERF
@usableFromInline
enum ERF {
	@usableFromInline
	struct He: OperatorUnary.Static.Raw {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
			for offset in (0..<stream).reversed() {
				vverf(y.advanced(by: offset * ldy),
					  x.advanced(by: offset * ldx),
					  length)
			}
		}
	}
}
public func erf(_ stream: Stream) -> some Stream {
	ERF.He(operand: stream)
}
// MARK: ERFC
@usableFromInline
enum ERFC {
	@usableFromInline
	struct He: OperatorUnary.Static.Raw {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
			for offset in (0..<stream).reversed() {
				vverfc(y.advanced(by: offset * ldy),
					   x.advanced(by: offset * ldx),
					   length)
			}
		}
	}
}
public func erfc(_ stream: Stream) -> some Stream {
	ERFC.He(operand: stream)
}
// MARK: Gamma
@usableFromInline
enum Gamma {
	@usableFromInline
	struct He: OperatorUnary.Static.Raw {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
			for offset in (0..<stream).reversed() {
				vvtgamma(y.advanced(by: offset * ldy),
						 x.advanced(by: offset * ldx),
						 length)
			}
		}
	}
}
public func Γ(_ stream: Stream) -> some Stream {
	Gamma.He(operand: stream)
}
// MARK: ln Gamma
@usableFromInline
enum lnGamma {
	@usableFromInline
	struct He: OperatorUnary.Static.Raw {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
			for offset in (0..<stream).reversed() {
				vvlgamma(y.advanced(by: offset * ldy),
						 x.advanced(by: offset * ldx),
						 length)
			}
		}
	}
}
public func lnΓ(_ stream: Stream) -> some Stream {
	lnGamma.He(operand: stream)
}
