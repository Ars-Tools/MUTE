//
//  Basic+FMA.swift
//  MUTE
//
//  Created by Kota on 5/16/R7.
//
@preconcurrency import protocol Combine.Publisher
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import func Layout.broadcast
@usableFromInline
enum FMA {
	@usableFromInline
	struct ASS<Weight: Publisher<(Int, Float64), Never> & Sendable, Offset: Publisher<(Int, Float64), Never> & Sendable>: OperatorTernary.ASS.DSP, Sendable {
		@usableFromInline let x: Stream
		@usableFromInline let y: Weight
		@usableFromInline let z: Offset
		@inlinable @inline(__always)
		var initial: (Float64, Float64) {(1, 0)}
		@inlinable @inline(__always)
		static func `operator`(x: some AccelerateBuffer<Float64>, y: Float64, z: Float64, w: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.add(multiplication: (x, y), z, result: &w)
		}
	}
	@usableFromInline
	struct ASA<Weight: Publisher<(Int, Float64), Never> & Sendable>: OperatorTernary.ASA.DSP, Sendable {
		@usableFromInline let x: Stream
		@usableFromInline let y: Weight
		@usableFromInline let z: Stream
		@inlinable @inline(__always)
		var initial: Float64 { 1 }
		@inlinable @inline(__always)
		static func `operator`(x: some AccelerateBuffer<Float64>, y: Float64, z: some AccelerateBuffer<Float64>, w: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.add(multiplication: (x, y), z, result: &w)
		}
	}
	@usableFromInline
	struct AAS<Offset: Publisher<(Int, Float64), Never> & Sendable>: OperatorTernary.AAS.DSP, Sendable {
		@usableFromInline let x: Stream
		@usableFromInline let y: Stream
		@usableFromInline let z: Offset
		@inlinable @inline(__always)
		var initial: Float64 { 0 }
		@inlinable @inline(__always)
		static func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: Float64, w: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.add(multiplication: (x, y), z, result: &w)
		}
	}
	@usableFromInline
	struct AAA: OperatorTernary.AAA.DSP {
		@usableFromInline let x: Stream
		@usableFromInline let y: Stream
		@usableFromInline let z: Stream
		@inlinable @inline(__always)
		static func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: some AccelerateBuffer<Float64>, w: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.add(multiplication: (x, y), z, result: &w)
		}
	}
}
// MARK: ASS
public func fma(_ x: Stream, _ y: some Publisher<(Int, Float64), Never> & Sendable, _ z: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	FMA.ASS(x: x, y: y, z: z)
}
public func fma(_ x: Stream, _ y: some Publisher<(Int, Float64), Never> & Sendable, _ z: some Publisher<Float64, Never>) -> some Stream {
	fma(x, y, z.repeat(count: x.count))
}
public func fma(_ x: Stream, _ y: some Publisher<(Int, Float64), Never> & Sendable, _ z: some Sequence<Float64>) -> some Stream {
	fma(x, y, z.prefix(count: x.count))
}
public func fma(_ x: Stream, _ y: some Publisher<(Int, Float64), Never> & Sendable, _ z: Float64) -> some Stream {
	fma(x, y, `repeat`(z, count: x.count))
}
public func fma(_ x: Stream, _ y: some Publisher<Float64, Never>, _ z: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	fma(x, y.repeat(count: x.count), z)
}
public func fma(_ x: Stream, _ y: some Publisher<Float64, Never>, _ z: some Publisher<Float64, Never>) -> some Stream {
	fma(x, y.repeat(count: x.count), z.repeat(count: x.count))
}
public func fma(_ x: Stream, _ y: some Publisher<Float64, Never>, _ z: some Sequence<Float64>) -> some Stream {
	fma(x, y.repeat(count: x.count), z.prefix(count: x.count))
}
public func fma(_ x: Stream, _ y: some Publisher<Float64, Never>, _ z: Float64) -> some Stream {
	fma(x, y.repeat(count: x.count), `repeat`(z, count: x.count))
}
public func fma(_ x: Stream, _ y: some Sequence<Float64>, _ z: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	fma(x, y.prefix(count: x.count), z)
}
public func fma(_ x: Stream, _ y: some Sequence<Float64>, _ z: some Publisher<Float64, Never>) -> some Stream {
	fma(x, y.prefix(count: x.count), z.repeat(count: x.count))
}
public func fma(_ x: Stream, _ y: some Sequence<Float64>, _ z: some Sequence<Float64>) -> some Stream {
	fma(x, y.prefix(count: x.count), z.prefix(count: x.count))
}
public func fma(_ x: Stream, _ y: some Sequence<Float64>, _ z: Float64) -> some Stream {
	fma(x, y.prefix(count: x.count), `repeat`(z, count: x.count))
}
public func fma(_ x: Stream, _ y: Float64, _ z: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	fma(x, `repeat`(y, count: x.count), z)
}
public func fma(_ x: Stream, _ y: Float64, _ z: some Publisher<Float64, Never>) -> some Stream {
	fma(x, `repeat`(y, count: x.count), z.repeat(count: x.count))
}
public func fma(_ x: Stream, _ y: Float64, _ z: some Sequence<Float64>) -> some Stream {
	fma(x, `repeat`(y, count: x.count), z.prefix(count: x.count))
}
public func fma(_ x: Stream, _ y: Float64, _ z: Float64) -> some Stream {
	fma(x, `repeat`(y, count: x.count), `repeat`(z, count: x.count))
}
// MARK: ASA
public func fma(_ x: Stream, _ y: some Publisher<(Int, Float64), Never> & Sendable, _ z: Stream) -> some Stream {
	FMA.ASA(x: x, y: y, z: z)
}
public func fma(_ x: Stream, _ y: some Publisher<Float64, Never>, _ z: Stream) -> some Stream {
	fma(x, y.repeat(count: broadcast(x: x.count, y: z.count)), z)
}
public func fma(_ x: Stream, _ y: some Sequence<Float64>, _ z: Stream) -> some Stream {
	fma(x, y.prefix(count: broadcast(x: x.count, y: z.count)), z)
}
public func fma(_ x: Stream, _ y: Float64, _ z: Stream) -> some Stream {
	fma(x, `repeat`(y, count: broadcast(x: x.count, y: z.count)), z)
}
// MARK: AAS
public func fma(_ x: Stream, _ y: Stream, _ z: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	FMA.AAS(x: x, y: y, z: z)
}
public func fma(_ x: Stream, _ y: Stream, _ z: some Publisher<Float64, Never>) -> some Stream {
	fma(x, y, z.repeat(count: broadcast(x: x.count, y: y.count)))
}
public func fma(_ x: Stream, _ y: Stream, _ z: some Sequence<Float64>) -> some Stream {
	fma(x, y, z.prefix(count: broadcast(x: x.count, y: y.count)))
}
public func fma(_ x: Stream, _ y: Stream, _ z: Float64) -> some Stream {
	fma(x, y, `repeat`(z, count: broadcast(x: x.count, y: y.count)))
}
// MARK: AAA
public func fma(_ x: Stream, _ y: Stream, _ z: Stream) -> some Stream {
	FMA.AAA(x: x, y: y, z: z)
}
