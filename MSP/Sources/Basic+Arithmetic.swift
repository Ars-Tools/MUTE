//
//  Basic+Arithmetic.swift
//  MUTE
//
//  Created by Kota on 5/16/R7.
//
import typealias Synchronization.Mutex
import typealias Synchronization.Atomic
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import func Layout.broadcast
@preconcurrency import protocol Combine.Publisher
// MARK: NEG
@usableFromInline
enum Neg {
	@usableFromInline
	struct He: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.negative(x, result: &y)
		}
	}
}
public prefix func-(source: Stream) -> some Stream {
	Neg.He(operand: source)
}
// MARK: Add
@usableFromInline
enum Add {
	@usableFromInline
	struct LHS<RHS: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSDSP, Sendable {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: RHS
		@inlinable @inline(__always)
		var initial: Float64 { 0 }
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: Float64, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.add(y, x, result: &z)
		}
	}
	@usableFromInline
	struct RHS<LHS: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.RHSDSP, Sendable {
		@usableFromInline let lhs: LHS
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		var initial: Float64 { 0 }
		@inlinable @inline(__always)
		func `operator`(x: Float64, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.add(x, y, result: &z)
		}
	}
	@usableFromInline
	struct DSP: OperatorBinary.DSP {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.add(x, y, result: &z)
		}
	}
}
public func+(lhs: Stream, rhs: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Add.LHS(lhs: lhs, rhs: rhs)
}
public func+(lhs: some Publisher<(Int, Float64), Never> & Sendable, rhs: Stream) -> some Stream {
	Add.RHS(lhs: lhs, rhs: rhs)
}
public func+(lhs: Stream, rhs: some Publisher<Float64, Never>) -> some Stream {
	lhs + rhs.repeat(count: lhs.count)
}
public func+(lhs: some Publisher<Float64, Never>, rhs: Stream) -> some Stream {
	lhs.repeat(count: rhs.count) + rhs
}
public func+(lhs: Stream, rhs: some Sequence<Float64>) -> some Stream {
	lhs + rhs.prefix(count: lhs.count)
}
public func+(lhs: some Sequence<Float64>, rhs: Stream) -> some Stream {
	lhs.prefix(count: rhs.count) + rhs
}
public func+(lhs: Stream, rhs: Float64) -> some Stream {
	lhs + `repeat`(rhs, count: lhs.count)
}
public func+(lhs: Float64, rhs: Stream) -> some Stream {
	`repeat`(lhs, count: rhs.count) + rhs
}
public func+(lhs: Stream, rhs: Stream) -> some Stream {
	Add.DSP(lhs: lhs, rhs: rhs)
}
// MARK: Sub
@usableFromInline
enum Sub {
	@usableFromInline
	struct LHS<RHS: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSDSP, Sendable {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: RHS
		@inlinable @inline(__always)
		var initial: Float64 { 0 }
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: Float64, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.add(-y, x, result: &z)
		}
	}
	@usableFromInline
	struct RHS<LHS: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.RHSDSP, Sendable {
		@usableFromInline let lhs: LHS
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		var initial: Float64 { 0 }
		@inlinable @inline(__always)
		func `operator`(x: Float64, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.add(multiplication: (y, -1), x, result: &z)
		}
	}
	@usableFromInline
	struct DSP: OperatorBinary.DSP {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.subtract(x, y, result: &z)
		}
	}
}
public func-(lhs: Stream, rhs: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Sub.LHS(lhs: lhs, rhs: rhs)
}
public func-(lhs: some Publisher<(Int, Float64), Never> & Sendable, rhs: Stream) -> some Stream {
	Sub.RHS(lhs: lhs, rhs: rhs)
}
public func-(lhs: Stream, rhs: some Publisher<Float64, Never>) -> some Stream {
	lhs - rhs.repeat(count: lhs.count)
}
public func-(lhs: some Publisher<Float64, Never>, rhs: Stream) -> some Stream {
	lhs.repeat(count: rhs.count) - rhs
}
public func-(lhs: Stream, rhs: some Sequence<Float64>) -> some Stream {
	lhs - rhs.prefix(count: lhs.count)
}
public func-(lhs: some Sequence<Float64>, rhs: Stream) -> some Stream {
	lhs.prefix(count: rhs.count) - rhs
}
public func-(lhs: Stream, rhs: Float64) -> some Stream {
	lhs - `repeat`(rhs, count: lhs.count)
}
public func-(lhs: Float64, rhs: Stream) -> some Stream {
	`repeat`(lhs, count: rhs.count) - rhs
}
public func-(lhs: Stream, rhs: Stream) -> some Stream {
	Sub.DSP(lhs: lhs, rhs: rhs)
}
// MARK: Mul
@usableFromInline
enum Mul {
	@usableFromInline
	struct LHS<RHS: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSDSP, Sendable {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: RHS
		@inlinable @inline(__always)
		var initial: Float64 { 1 }
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: Float64, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.multiply(y, x, result: &z)
		}
	}
	@usableFromInline
	struct RHS<LHS: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.RHSDSP, Sendable {
		@usableFromInline let lhs: LHS
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		var initial: Float64 { 1 }
		@inlinable @inline(__always)
		func `operator`(x: Float64, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.multiply(x, y, result: &z)
		}
	}
	@usableFromInline
	struct DSP: OperatorBinary.DSP {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.multiply(x, y, result: &z)
		}
	}
}
public func*(lhs: Stream, rhs: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Mul.LHS(lhs: lhs, rhs: rhs)
}
public func*(lhs: some Publisher<(Int, Float64), Never> & Sendable, rhs: Stream) -> some Stream {
	Mul.RHS(lhs: lhs, rhs: rhs)
}
public func*(lhs: Stream, rhs: some Publisher<Float64, Never>) -> some Stream {
	lhs * rhs.repeat(count: lhs.count)
}
public func*(lhs: some Publisher<Float64, Never>, rhs: Stream) -> some Stream {
	lhs.repeat(count: rhs.count) * rhs
}
public func*(lhs: Stream, rhs: some Sequence<Float64>) -> some Stream {
	lhs * rhs.prefix(count: lhs.count)
}
public func*(lhs: some Sequence<Float64>, rhs: Stream) -> some Stream {
	lhs.prefix(count: rhs.count) * rhs
}
public func*(lhs: Stream, rhs: Float64) -> some Stream {
	lhs * `repeat`(rhs, count: lhs.count)
}
public func*(lhs: Float64, rhs: Stream) -> some Stream {
	`repeat`(lhs, count: rhs.count) * rhs
}
public func*(lhs: Stream, rhs: Stream) -> some Stream {
	Mul.DSP(lhs: lhs, rhs: rhs)
}
// MARK: Div
@usableFromInline
enum Div {
	@usableFromInline
	struct LHS<RHS: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSDSP, Sendable {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: RHS
		@inlinable @inline(__always)
		var initial: Float64 { 1 }
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: Float64, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.divide(x, y, result: &z)
		}
	}
	@usableFromInline
	struct RHS<LHS: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.RHSDSP, Sendable {
		@usableFromInline let lhs: LHS
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		var initial: Float64 { 1 }
		@inlinable @inline(__always)
		func `operator`(x: Float64, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.divide(x, y, result: &z)
		}
	}
	@usableFromInline
	struct DSP: OperatorBinary.DSP {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.divide(x, y, result: &z)
		}
	}
}
public func/(lhs: Stream, rhs: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Div.LHS(lhs: lhs, rhs: rhs)
}
public func/(lhs: some Publisher<(Int, Float64), Never> & Sendable, rhs: Stream) -> some Stream {
	Div.RHS(lhs: lhs, rhs: rhs)
}
public func/(lhs: Stream, rhs: some Publisher<Float64, Never>) -> some Stream {
	lhs / rhs.repeat(count: lhs.count)
}
public func/(lhs: some Publisher<Float64, Never>, rhs: Stream) -> some Stream {
	lhs.repeat(count: rhs.count) / rhs
}
public func/(lhs: Stream, rhs: some Sequence<Float64>) -> some Stream {
	lhs / rhs.prefix(count: lhs.count)
}
public func/(lhs: some Sequence<Float64>, rhs: Stream) -> some Stream {
	lhs.prefix(count: rhs.count) / rhs
}
public func/(lhs: Stream, rhs: Float64) -> some Stream {
	lhs / `repeat`(rhs, count: lhs.count)
}
public func/(lhs: Float64, rhs: Stream) -> some Stream {
	`repeat`(lhs, count: rhs.count) / rhs
}
public func/(lhs: Stream, rhs: Stream) -> some Stream {
	Div.DSP(lhs: lhs, rhs: rhs)
}
