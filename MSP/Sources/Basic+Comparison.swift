//
//  Basic+Comparison.swift
//  MUTE
//
//  Created by Kota on 6/26/R7.
//
@preconcurrency import protocol Combine.Publisher
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import func Layout.zip
import func NSP.comparison_eq
import func NSP.comparison_ne
import func NSP.comparison_gt
import func NSP.comparison_lt
import func NSP.comparison_ge
import func NSP.comparison_le
// MARK: EQ
// MARK: NE
// MARK: GT
@usableFromInline
enum GT {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSRaw {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Signal
		@inlinable
		var initial: Float64 { 0 }
		@inlinable
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Double>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
			for offset in 0..<stream {
				comparison_gt(x.advanced(by: offset * ldx), 1,
							  y, 0,
							  z.advanced(by: offset * ldz), 1,
							  length)
			}
		}
	}
	@usableFromInline
	struct Ar: OperatorBinary.Raw {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
			for (x, y, z) in zip(stride(from: 0, to: stream * ldx, by: ldx).lazy.map(x.advanced(by:)),
								 stride(from: 0, to: stream * ldy, by: ldy).lazy.map(y.advanced(by:)),
								 stride(from: 0, to: stream * ldz, by: ldz).lazy.map(z.advanced(by:))) {
				comparison_gt(x, 1, y, 1, z, 1, length)
			}
		}
	}
}
public func>(lhs: Stream, rhs: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	GT.Kr(lhs: lhs, rhs: rhs)
}
public func>(lhs: Stream, rhs: some Publisher<Float64, Never> & Sendable) -> some Stream {
	lhs > rhs.repeat(count: lhs.count)
}
public func>(lhs: Stream, rhs: some Sequence<Float64>) -> some Stream {
	lhs > rhs.prefix(count: lhs.count)
}
public func>(lhs: Stream, rhs: Float64) -> some Stream {
	lhs > `repeat`(rhs, count: lhs.count)
}
public func>(lhs: Stream, rhs: Stream) -> some Stream {
	GT.Ar(lhs: lhs, rhs: rhs)
}
// MARK: LT
@usableFromInline
enum LT {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSRaw {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Signal
		@inlinable
		var initial: Float64 { 0 }
		@inlinable
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Double>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
			for offset in 0..<stream {
				comparison_lt(x.advanced(by: offset * ldx), 1,
							  y, 0,
							  z.advanced(by: offset * ldz), 1,
							  length)
			}
		}
	}
	@usableFromInline
	struct Ar: OperatorBinary.Raw {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
			for (x, y, z) in zip(stride(from: 0, to: stream * ldx, by: ldx).lazy.map(x.advanced(by:)),
								 stride(from: 0, to: stream * ldy, by: ldy).lazy.map(y.advanced(by:)),
								 stride(from: 0, to: stream * ldz, by: ldz).lazy.map(z.advanced(by:))) {
				comparison_lt(x, 1, y, 1, z, 1, length)
			}
		}
	}
}
public func<(lhs: Stream, rhs: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	LT.Kr(lhs: lhs, rhs: rhs)
}
public func<(lhs: Stream, rhs: some Publisher<Float64, Never> & Sendable) -> some Stream {
	lhs < rhs.repeat(count: lhs.count)
}
public func<(lhs: Stream, rhs: some Sequence<Float64>) -> some Stream {
	lhs < rhs.prefix(count: lhs.count)
}
public func<(lhs: Stream, rhs: Float64) -> some Stream {
	lhs < `repeat`(rhs, count: lhs.count)
}
public func<(lhs: Stream, rhs: Stream) -> some Stream {
	LT.Ar(lhs: lhs, rhs: rhs)
}
// MARK: GE
@usableFromInline
enum GE {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSRaw {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Signal
		@inlinable
		var initial: Float64 {
			0
		}
		@inlinable
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Double>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
			for offset in 0..<stream {
				comparison_ge(x.advanced(by: offset * ldx), 1,
							  y, 0,
							  z.advanced(by: offset * ldz), 1,
							  length)
			}
		}
	}
	@usableFromInline
	struct Ar: OperatorBinary.Raw {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
			for (x, y, z) in zip(stride(from: 0, to: stream * ldx, by: ldx).lazy.map(x.advanced(by:)),
								 stride(from: 0, to: stream * ldy, by: ldy).lazy.map(y.advanced(by:)),
								 stride(from: 0, to: stream * ldz, by: ldz).lazy.map(z.advanced(by:))) {
				comparison_ge(x, 1, y, 1, z, 1, length)
			}
		}
	}
}
public func>=(lhs: Stream, rhs: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	GE.Kr(lhs: lhs, rhs: rhs)
}
public func>=(lhs: Stream, rhs: some Publisher<Float64, Never> & Sendable) -> some Stream {
	lhs >= rhs.repeat(count: lhs.count)
}
public func>=(lhs: Stream, rhs: some Sequence<Float64>) -> some Stream {
	lhs >= rhs.prefix(count: lhs.count)
}
public func>=(lhs: Stream, rhs: Float64) -> some Stream {
	lhs >= `repeat`(rhs, count: lhs.count)
}
public func>=(lhs: Stream, rhs: Stream) -> some Stream {
	GE.Ar(lhs: lhs, rhs: rhs)
}
// MARK: LE
@usableFromInline
enum LE {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSRaw {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Signal
		@inlinable
		var initial: Float64 { 0 }
		@inlinable
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Double>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
			for offset in 0..<stream {
				comparison_le(x.advanced(by: offset * ldx), 1,
							  y, 0,
							  z.advanced(by: offset * ldz), 1,
							  length)
			}
		}
	}
	@usableFromInline
	struct Ar: OperatorBinary.Raw {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
			for (x, y, z) in zip(stride(from: 0, to: stream * ldx, by: ldx).lazy.map(x.advanced(by:)),
								 stride(from: 0, to: stream * ldy, by: ldy).lazy.map(y.advanced(by:)),
								 stride(from: 0, to: stream * ldz, by: ldz).lazy.map(z.advanced(by:))) {
				comparison_le(x, 1, y, 1, z, 1, length)
			}
		}
	}
}
public func<=(lhs: Stream, rhs: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	LE.Kr(lhs: lhs, rhs: rhs)
}
public func<=(lhs: Stream, rhs: some Publisher<Float64, Never> & Sendable) -> some Stream {
	lhs <= rhs.repeat(count: lhs.count)
}
public func<=(lhs: Stream, rhs: some Sequence<Float64>) -> some Stream {
	lhs <= rhs.prefix(count: lhs.count)
}
public func<=(lhs: Stream, rhs: Float64) -> some Stream {
	lhs <= `repeat`(rhs, count: lhs.count)
}
public func<=(lhs: Stream, rhs: Stream) -> some Stream {
	LE.Ar(lhs: lhs, rhs: rhs)
}
