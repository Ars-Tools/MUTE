//
//  Waveshape+Fold.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
import func NSP.folding_sup
import func NSP.folding_inf
import func NSP.folding_bounds
@usableFromInline
enum Foldings {}
// Sup
extension Foldings {
	@usableFromInline
	enum Sup {}
}
extension Foldings.Sup {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline
		let lhs: Stream
		@usableFromInline
		let rhs: Signal
	}
	@usableFromInline
	struct Ar {
		@usableFromInline
		let lhs: Stream
		@usableFromInline
		let rhs: Stream
	}
}
extension Foldings.Sup.Kr: OperatorBinary.LHSRaw {
	@inlinable
	var initial: Float64 {
		0
	}
	@inlinable
	func`operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
		for offset in 0..<stream {
			folding_sup(x.advanced(by: offset * ldx),
						z.advanced(by: offset * ldz),
						y, incy, length)
		}
	}
}
extension Foldings.Sup.Ar: OperatorBinary.Raw {
	@usableFromInline
	func`operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
		for offset in 0..<stream {
			folding_sup(x.advanced(by: offset * ldx),
						z.advanced(by: offset * ldz),
						y.advanced(by: offset * ldy), 1,
						length)
		}
	}
}
// Inf
extension Foldings {
	@usableFromInline
	enum Inf {}
}
extension Foldings.Inf {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline
		let lhs: Stream
		@usableFromInline
		let rhs: Signal
	}
	@usableFromInline
	struct Ar {
		@usableFromInline
		let lhs: Stream
		@usableFromInline
		let rhs: Stream
	}
}
extension Foldings.Inf.Kr: OperatorBinary.LHSRaw {
	@inlinable
	var initial: Float64 {
		0
	}
	@usableFromInline
	func`operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
		for offset in 0..<stream {
			folding_inf(x.advanced(by: offset * ldx),
						z.advanced(by: offset * ldz),
						y, incy,
						length)
		}
	}
}
extension Foldings.Inf.Ar: OperatorBinary.Raw {
	@usableFromInline
	func`operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
		for offset in 0..<stream {
			folding_inf(x.advanced(by: offset * ldx),
						z.advanced(by: offset * ldz),
						y.advanced(by: offset * ldy), 1,
						length)
		}
	}
}
// Bounds
extension Foldings {
	@usableFromInline
	enum Bounds {}
}
extension Foldings.Bounds {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Signal
	}
	@usableFromInline
	struct Ar {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
	}
}
extension Foldings.Bounds.Kr: OperatorBinary.LHSRaw {
	@inlinable
	var initial: Float64 {
		0
	}
	@inlinable
	func`operator`(x: UnsafePointer<Float64>, ldx: Int,
				   y: UnsafePointer<Float64>, incy: Int,
				   z: UnsafeMutablePointer<Float64>, ldz: Int,
				   stream: Int, length: Int) {
		for offset in 0..<stream {
			folding_bounds(x.advanced(by: offset * ldx),
						   z.advanced(by: offset * ldz),
						   y, incy,
						   length)
		}
	}
}
extension Foldings.Bounds.Ar: OperatorBinary.Raw {
	@usableFromInline
	func`operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
		for offset in 0..<stream {
			folding_bounds(x.advanced(by: offset * ldx),
						   z.advanced(by: offset * ldz),
						   y.advanced(by: offset * ldy), 1,
						   length)
		}
	}
}
// Entrypoint
public func folding(_ stream: Stream, bounds: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Foldings.Bounds.Kr(lhs: stream, rhs: bounds)
}
public func folding(_ stream: Stream, bounds: some Publisher<Float64, Never>) -> some Stream {
	Foldings.Bounds.Kr(lhs: stream, rhs: bounds.repeat(count: stream.count))
}
public func folding(_ stream: Stream, bounds: some Sequence<Float64>) -> some Stream {
	Foldings.Bounds.Kr(lhs: stream, rhs: bounds.prefix(stream.count).enumerated().publisher.map(\.self))
}
public func folding(_ stream: Stream, bounds: Float64) -> some Stream {
	Foldings.Bounds.Kr(lhs: stream, rhs: repeatElement(bounds, count: stream.count).enumerated().publisher.map(\.self))
}
public func folding(_ stream: Stream, bounds: Stream) -> some Stream {
	Foldings.Bounds.Ar(lhs: stream, rhs: bounds)
}
//
public func folding(_ stream: Stream, sup: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Foldings.Sup.Kr(lhs: stream, rhs: sup)
}
public func folding(_ stream: Stream, sup: some Publisher<Float64, Never> & Sendable) -> some Stream {
	Foldings.Sup.Kr(lhs: stream, rhs: sup.repeat(count: stream.count))
}
public func folding(_ stream: Stream, sup: some Sequence<Float64>) -> some Stream {
	Foldings.Sup.Kr(lhs: stream, rhs: sup.prefix(stream.count).enumerated().publisher.map(\.self))
}
public func folding(_ stream: Stream, sup: Float64) -> some Stream {
	Foldings.Sup.Kr(lhs: stream, rhs: repeatElement(sup, count: stream.count).enumerated().publisher.map(\.self))
}
public func folding(_ stream: Stream, sup: Stream) -> some Stream {
	Foldings.Sup.Ar(lhs: stream, rhs: sup)
}
//
public func folding(_ stream: Stream, inf: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Foldings.Inf.Kr(lhs: stream, rhs: inf)
}
public func folding(_ stream: Stream, inf: some Publisher<Float64, Never> & Sendable) -> some Stream {
	Foldings.Inf.Kr(lhs: stream, rhs: inf.repeat(count: stream.count))
}
public func folding(_ stream: Stream, inf: some Sequence<Float64>) -> some Stream {
	Foldings.Inf.Kr(lhs: stream, rhs: inf.prefix(stream.count).enumerated().publisher.map(\.self))
}
public func folding(_ stream: Stream, inf: Float64) -> some Stream {
	Foldings.Inf.Kr(lhs: stream, rhs: repeatElement(inf, count: stream.count).enumerated().publisher.map(\.self))
}
public func folding(_ stream: Stream, inf: Stream) -> some Stream {
	Foldings.Inf.Ar(lhs: stream, rhs: inf)
}
