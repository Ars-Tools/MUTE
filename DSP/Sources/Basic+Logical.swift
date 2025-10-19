//
//  Basic+Logical.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
@preconcurrency import protocol Combine.Publisher
import func NSP.logical_not
import func NSP.logical_or
import func NSP.logical_and
import func NSP.logical_nor
import func NSP.logical_nand
import func NSP.logical_xor
import func NSP.logical_xnor
@usableFromInline
enum Logical {}
// MARK: NOT
extension Logical {
	@usableFromInline
	enum Not {
		@usableFromInline
		struct He: OperatorUnary.Static.Raw {
			@usableFromInline let operand: Stream
			@usableFromInline
			func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafeMutablePointer<Float64>, ldy: Int, stream: Int, length: Int) {
				for offset in 0..<stream {
					logical_not(x.advanced(by: offset * ldx), 1,
								y.advanced(by: offset * ldy), 1,
								length)
				}
			}
		}
	}
}
prefix func!(_ source: Stream) -> some Stream {
	Logical.Not.He(operand: source)
}
// MARK: OR
extension Logical {
	@usableFromInline
	enum Or {
		@usableFromInline
		struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSRaw {
			@usableFromInline let lhs: Stream
			@usableFromInline let rhs: Signal
			@inlinable
			var initial: Float64 { 0 }
			@inlinable
			func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
				for offset in 0..<stream {
					logical_or(x.advanced(by: offset * ldx), 1,
							   y, incy,
							   z.advanced(by: offset * ldz), 1,
							   length)
				}
			}
		}
		@usableFromInline
		struct Ar: OperatorBinary.Raw {
			@usableFromInline let lhs: Stream
			@usableFromInline let rhs: Stream
			@inlinable
			func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
				for offset in 0..<stream {
					logical_or(x.advanced(by: offset * ldx), 1,
							   y.advanced(by: offset * ldy), 1,
							   z.advanced(by: offset * ldz), 1,
							   length)
				}
			}
		}
	}
}
public func||(lhs: Stream, rhs: some Publisher<(Int, Bool), Never> & Sendable) -> some Stream {
	Logical.Or.Kr(lhs: lhs, rhs: rhs.map { ($0, $1 ? 1 : 0) })
}
public func||(lhs: some Publisher<(Int, Bool), Never> & Sendable, rhs: Stream) -> some Stream {
	Logical.Or.Kr(lhs: rhs, rhs: lhs.map { ($0, $1 ? 1 : 0) })
}
public func||(lhs: Stream, rhs: some Publisher<Bool, Never>) -> some Stream {
	Logical.Or.Kr(lhs: lhs, rhs: rhs.map { $0 ? 1 : 0 }.repeat(count: lhs.count))
}
public func||(lhs: some Publisher<Bool, Never>, rhs: Stream) -> some Stream {
	Logical.Or.Kr(lhs: rhs, rhs: lhs.map { $0 ? 1 : 0 }.repeat(count: rhs.count))
}
public func||(lhs: Stream, rhs: some Sequence<Bool>) -> some Stream {
	Logical.Or.Kr(lhs: lhs, rhs: rhs.map { $0 ? 1 : 0 }.prefix(lhs.count).enumerated().publisher.map(\.self))
}
public func||(lhs: some Sequence<Bool>, rhs: Stream) -> some Stream {
	Logical.Or.Kr(lhs: rhs, rhs: lhs.map { $0 ? 1 : 0 }.prefix(rhs.count).enumerated().publisher.map(\.self))
}
public func||(lhs: Stream, rhs: Bool) -> some Stream {
	Logical.Or.Kr(lhs: lhs, rhs: `repeat`(rhs ? 1 : 0, count: lhs.count))
}
public func||(lhs: Bool, rhs: Stream) -> some Stream {
	Logical.Or.Kr(lhs: rhs, rhs: `repeat`(lhs ? 1 : 0, count: rhs.count))
}
public func||(lhs: Stream, rhs: Stream) -> some Stream {
	Logical.Or.Ar(lhs: lhs, rhs: rhs)
}
// MARK: AND
extension Logical {
	@usableFromInline
	enum And {
		@usableFromInline
		struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSRaw {
			@usableFromInline let lhs: Stream
			@usableFromInline let rhs: Signal
			@inlinable
			var initial: Float64 { 1 }
			@inlinable
			func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
				for offset in 0..<stream {
					logical_and(x.advanced(by: offset * ldx), 1,
								y, incy,
								z.advanced(by: offset * ldz), 1,
								length)
				}
			}
		}
		@usableFromInline
		struct Ar: OperatorBinary.Raw {
			@usableFromInline let lhs: Stream
			@usableFromInline let rhs: Stream
			@inlinable
			func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
				for offset in 0..<stream {
					logical_and(x.advanced(by: offset * ldx), 1,
								y.advanced(by: offset * ldy), 1,
								z.advanced(by: offset * ldz), 1,
								length)
				}
			}
		}
	}
}
public func&&(lhs: Stream, rhs: some Publisher<(Int, Bool), Never> & Sendable) -> some Stream {
	Logical.And.Kr(lhs: lhs, rhs: rhs.map { ($0, $1 ? 1 : 0) })
}
public func&&(lhs: some Publisher<(Int, Bool), Never> & Sendable, rhs: Stream) -> some Stream {
	Logical.And.Kr(lhs: rhs, rhs: lhs.map { ($0, $1 ? 1 : 0) })
}
public func&&(lhs: Stream, rhs: some Publisher<Bool, Never>) -> some Stream {
	Logical.And.Kr(lhs: lhs, rhs: rhs.map { $0 ? 1 : 0 }.repeat(count: lhs.count))
}
public func&&(lhs: some Publisher<Bool, Never>, rhs: Stream) -> some Stream {
	Logical.And.Kr(lhs: rhs, rhs: lhs.map { $0 ? 1 : 0 }.repeat(count: rhs.count))
}
public func&&(lhs: Stream, rhs: some Sequence<Bool>) -> some Stream {
	Logical.And.Kr(lhs: lhs, rhs: rhs.map { $0 ? 1 : 0 }.prefix(lhs.count).enumerated().publisher.map(\.self))
}
public func&&(lhs: some Sequence<Bool>, rhs: Stream) -> some Stream {
	Logical.And.Kr(lhs: rhs, rhs: lhs.map { $0 ? 1 : 0 }.prefix(rhs.count).enumerated().publisher.map(\.self))
}
public func&&(lhs: Stream, rhs: Bool) -> some Stream {
	Logical.And.Kr(lhs: lhs, rhs: `repeat`(rhs ? 1 : 0, count: lhs.count))
}
public func&&(lhs: Bool, rhs: Stream) -> some Stream {
	Logical.And.Kr(lhs: rhs, rhs: `repeat`(lhs ? 1 : 0, count: rhs.count))
}
public func&&(lhs: Stream, rhs: Stream) -> some Stream {
	Logical.And.Ar(lhs: lhs, rhs: rhs)
}
// MARK: XOR
extension Logical {
	@usableFromInline
	enum Xor {
		@usableFromInline
		struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSRaw {
			@usableFromInline let lhs: Stream
			@usableFromInline let rhs: Signal
			@inlinable
			var initial: Float64 { 0 }
			@inlinable
			func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
				for offset in 0..<stream {
					logical_and(x.advanced(by: offset * ldx), 1,
								y, incy,
								z.advanced(by: offset * ldz), 1,
								length)
				}
			}
		}
		@usableFromInline
		struct Ar: OperatorBinary.Raw {
			@usableFromInline let lhs: Stream
			@usableFromInline let rhs: Stream
			@inlinable
			func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
				for offset in 0..<stream {
					logical_and(x.advanced(by: offset * ldx), 1,
								y.advanced(by: offset * ldy), 1,
								z.advanced(by: offset * ldz), 1,
								length)
				}
			}
		}
	}
}
public func^(lhs: Stream, rhs: some Publisher<(Int, Bool), Never> & Sendable) -> some Stream {
	Logical.Xor.Kr(lhs: lhs, rhs: rhs.map { ($0, $1 ? 1 : 0) })
}
public func^(lhs: some Publisher<(Int, Bool), Never> & Sendable, rhs: Stream) -> some Stream {
	Logical.Xor.Kr(lhs: rhs, rhs: lhs.map { ($0, $1 ? 1 : 0) })
}
public func^(lhs: Stream, rhs: some Publisher<Bool, Never>) -> some Stream {
	Logical.Xor.Kr(lhs: lhs, rhs: rhs.map { $0 ? 1 : 0 }.repeat(count: lhs.count))
}
public func^(lhs: some Publisher<Bool, Never>, rhs: Stream) -> some Stream {
	Logical.Xor.Kr(lhs: rhs, rhs: lhs.map { $0 ? 1 : 0 }.repeat(count: rhs.count))
}
public func^(lhs: Stream, rhs: some Sequence<Bool>) -> some Stream {
	Logical.Xor.Kr(lhs: lhs, rhs: rhs.map { $0 ? 1 : 0 }.prefix(lhs.count).enumerated().publisher.map(\.self))
}
public func^(lhs: some Sequence<Bool>, rhs: Stream) -> some Stream {
	Logical.Xor.Kr(lhs: rhs, rhs: lhs.map { $0 ? 1 : 0 }.prefix(rhs.count).enumerated().publisher.map(\.self))
}
public func^(lhs: Stream, rhs: Bool) -> some Stream {
	Logical.Xor.Kr(lhs: lhs, rhs: `repeat`(rhs ? 1 : 0, count: lhs.count))
}
public func^(lhs: Bool, rhs: Stream) -> some Stream {
	Logical.Xor.Kr(lhs: rhs, rhs: `repeat`(lhs ? 1 : 0, count: rhs.count))
}
public func^(lhs: Stream, rhs: Stream) -> some Stream {
	Logical.Xor.Ar(lhs: lhs, rhs: rhs)
}
