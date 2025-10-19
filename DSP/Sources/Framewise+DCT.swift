//
//  Framewise+DCT.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
@preconcurrency import typealias Accelerate.vDSP
import func Accelerate.vecLib.vDSP_vclr
import func CoreMedia.CMTimeMultiply
import typealias Numerics.Rational64
extension Framewise {
	public enum DCT {
		@usableFromInline
		struct Ne {
			@usableFromInline let source: Stream
			@usableFromInline let window: Window
			@usableFromInline let stride: Stride
			@usableFromInline let margin: Rational64
			@usableFromInline let forward: vDSP.DCTTransformType
			@usableFromInline let inverse: vDSP.DCTTransformType
			@usableFromInline let count: Int
			@usableFromInline let scale: Float64
			@usableFromInline let value: @Sendable (CMTime, Int) throws -> @Sendable (CMTime, Array<UnsafeMutableBufferPointer<Float32>>, inout Array<UnsafeMutableBufferPointer<Float32>>) -> Void
		}
	}
}
extension Framewise.DCT.Ne: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let stream = (i: source.count, o: count)
		let window = window.coefficients(for: interval)
		let length = (window.count * Int(margin.numerator) - 1) / Int(margin.denominator) + 1
		let frame = [1, 3, 5, 15].compactMap { f in
			(4...).lazy.map {
				f * (1 << $0)
			}.first {
				length <= $0
			}
		}.min() ?? length
		let object = switch (vDSP.DCT(count: frame, transformType: forward), vDSP.DCT(count: frame, transformType: inverse)) {
		case(.some(let forward), .some(let inverse)):
			(forward: forward, inverse: inverse)
		case(.some,.none),(.none,.some),(.none,.none):
			throw Error.failedToAllocate(vDSP.DCT.self)
		}
		let scale = scale / Float64(frame)
		let stride = switch stride {
		case.absolute(let duration):
			duration.samples(for: interval)
		case.relative(let duration):
			(window.count * Int(duration.numerator) - 1) / Int(duration.denominator) + 1
		}
		let worker = try value(interval, frame)
		let period = capacity + frame
		let buffer = Buffer(stream: stream.o + stream.i, period: period)
		let size = (
			o: max(window.count * MemoryLayout<Float64>.stride, stream.o * frame * MemoryLayout<Float32>.stride),
			i: max(window.count * MemoryLayout<Float64>.stride, stream.i * frame * MemoryLayout<Float32>.stride)
		)
		return { moment, length, target, bounds in
			let byte = max(
				size.o + size.i,
				length * stream.i * MemoryLayout<Float64>.stride
			)
			withUnsafeTemporaryAllocation(byteCount: byte, alignment: MemoryLayout<Float64>.alignment) {
				guard let raw = $0.baseAddress else { return }
				let cursor = moment.samples(for: interval)
				let f64 = (
					i: raw.advanced(by: size.o).assumingMemoryBound(to: Float64.self),
					o: raw.assumingMemoryBound(to: Float64.self)
				)
				let f32 = (
					i: raw.advanced(by: size.o).assumingMemoryBound(to: Float32.self),
					o: raw.assumingMemoryBound(to: Float32.self)
				)
				var memory = (
					i: UnsafeMutableBufferPointer(start: f64.i, count: window.count),
					o: UnsafeMutableBufferPointer(start: f64.o, count: window.count)
				)
				let i = fold(start: f32.i, count: frame, stream: stream.i, period: frame)
				var o = fold(start: f32.o, count: frame, stream: stream.o, period: frame)
				let ic = switch ( cursor + window.count ) % period {
				case let index: (
					head: index..<min(index + length, period),
					tail: 0..<max(0, index + length - period)
				)}
				let oc = switch ( cursor                ) % period {
				case let index: (
					head: index..<min(index + length, period),
					tail: 0..<max(0, index + length - period)
				)}
				let ob = buffer.start
				let ib = ob.advanced(by: stream.o * period)
				kernel(moment, length, f64.o, length)
				copy(x: f64.o, ldx: length,
					 y: ib.advanced(by: ic.head.lowerBound), ldy: period,
					 rows: stream.i, cols: ic.head.count)
				copy(x: f64.o.advanced(by: ic.head.count), ldx: length,
					 y: ib, ldy: period,
					 rows: stream.i, cols: ic.tail.count)
				let lower = ( ( cursor          - 1 ) / stride + 1 ) * stride
				let upper = ( ( cursor + length - 1 ) / stride + 1 ) * stride
				for offset in Swift.stride(from: lower, to: upper, by: stride) {
					let index = offset % period
					let head = index..<min(index + window.count, period)
					let tail = 0..<max(0, index + window.count - period)
					vDSP_vclr(f32.i, 1, .init(stream.i * frame))
					for (source, var target) in zip(fold(start: ib, count: period, stream: stream.i, period: period), i) {
						vDSP.multiply(window[..<head.count], source[head], result: &memory.o[..<head.count])
						vDSP.multiply(window[head.count...], source[tail], result: &memory.o[head.count...])
						vDSP.convertElements(of: memory.o, to: &target[..<window.count])
						object.forward.transform(target, result: &target)
					}
					worker(CMTimeMultiply(interval, multiplier: .init(offset)), i, &o)
					for (var source, target) in zip(o, fold(start: ob, count: period, stream: stream.o, period: period)) {
						object.inverse.transform(source, result: &source)
						vDSP.convertElements(of: source[..<window.count], to: &memory.i)
						vDSP.multiply(scale, memory.i, result: &memory.i)
						vDSP.add(multiplication: (window[..<head.count], memory.i[..<head.count]), target[head], result: &target[head])
						vDSP.add(multiplication: (window[head.count...], memory.i[head.count...]), target[tail], result: &target[tail])
					}
				}
				copy(x: ob.advanced(by: oc.head.lowerBound), ldx: period,
					 y: target, ldy: bounds,
					 rows: stream.o, cols: oc.head.count)
				copy(x: ob, ldx: period,
					 y: target.advanced(by: oc.head.count), ldy: bounds,
					 rows: stream.o, cols: oc.tail.count)
				for target in fold(target: buffer) {
					vDSP.clear(&target[oc.head])
					vDSP.clear(&target[oc.tail])
				}
			}
		}
	}
}
public func framewise(_ source: Stream, window: Framewise.Window, stride: Framewise.Stride, output count: Int, margin: Rational64 = 1, method types: (vDSP.DCTTransformType, vDSP.DCTTransformType), factor scale: Float64 = 1, ioproc value: @escaping@Sendable (CMTime, Int) throws -> @Sendable (CMTime, Array<UnsafeMutableBufferPointer<Float32>>, inout Array<UnsafeMutableBufferPointer<Float32>>) -> Void) -> some Stream {
	Framewise.DCT.Ne(source: source, window: window, stride: stride, margin: margin, forward: types.0, inverse: types.1, count: count, scale: scale, value: value)
}
public func framewise(_ source: Stream, window: Framewise.Window, stride: Framewise.Stride, output count: Int, margin: Rational64 = 1, method types: (vDSP.DCTTransformType, vDSP.DCTTransformType), factor scale: Float64 = 1, ioproc value: @escaping@Sendable(CMTime, Array<UnsafeMutableBufferPointer<Float32>>, inout Array<UnsafeMutableBufferPointer<Float32>>) -> Void) -> some Stream {
	Framewise.DCT.Ne(source: source, window: window, stride: stride, margin: margin, forward: types.0, inverse: types.1, count: count,  scale: scale) { _, _ in value }
}


