//
//  Framewise+DFT.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import typealias Accelerate.vDSP
import func Accelerate.vecLib.vDSP_vclrD
import func CoreMedia.CMTimeMultiply
import func Layout.zip
import typealias Numerics.Rational64
extension Framewise {
	public enum DFT {
		@usableFromInline
		struct Ne {
			@usableFromInline let source: Stream
			@usableFromInline let window: Window
			@usableFromInline let stride: Stride
			@usableFromInline let margin: Rational64
			@usableFromInline let count: Int
			@usableFromInline let scale: Float64
			@usableFromInline let value: @Sendable (CMTime, Int) throws -> @Sendable (CMTime, ArraySlice<UnsafeMutableBufferPointer<Float64>>, ArraySlice<UnsafeMutableBufferPointer<Float64>>, inout ArraySlice<UnsafeMutableBufferPointer<Float64>>, inout ArraySlice<UnsafeMutableBufferPointer<Float64>>) -> Void
		}
	}
}
extension Framewise.DFT.Ne: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let stream = (i: source.count, o: count)
		let window = window.coefficients(for: interval)
		let length = (window.count * Int(margin.numerator) - 1) / Int(margin.denominator) + 1
		let frame = [1, 3, 5, 15].compactMap { f in
			(3...).lazy.map {
				f * (1 << $0)
			}.first {
				length <= $0
			}
		}.min() ?? length
		let object = try (
			forward: vDSP.DiscreteFourierTransform(count: frame, direction: .forward, transformType: .complexComplex, ofType: Float64.self),
			inverse: vDSP.DiscreteFourierTransform(count: frame, direction: .inverse, transformType: .complexComplex, ofType: Float64.self)
		)
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
		return { moment, length, target, bounds in
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: max((stream.i + stream.o) * frame * 2, stream.i * length)) {
				guard let memory = $0.baseAddress else { return }
				let cursor = moment.samples(for: interval)
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
				kernel(moment, length, memory, length)
				copy(x: memory, ldx: length,
					 y: ib.advanced(by: ic.head.lowerBound), ldy: period,
					 rows: stream.i, cols: ic.head.count)
				copy(x: memory.advanced(by: ic.head.count), ldx: length,
					 y: ib, ldy: period,
					 rows: stream.i, cols: ic.tail.count)
				let d = fold(start: memory, count: frame, stream: (stream.i * stream.o) * 2, period: frame)
				let i = (r: d[(stream.i * 0 + stream.o * 0)..<(stream.i * 1 + stream.o * 0)],
						 i: d[(stream.i * 1 + stream.o * 0)..<(stream.i * 2 + stream.o * 0)])
				var o = (r: d[(stream.i * 2 + stream.o * 0)..<(stream.i * 2 + stream.o * 1)],
						 i: d[(stream.i * 2 + stream.o * 1)..<(stream.i * 2 + stream.o * 2)])
				let lower = ( ( cursor          - 1 ) / stride + 1 ) * stride
				let upper = ( ( cursor + length - 1 ) / stride + 1 ) * stride
				for offset in Swift.stride(from: lower, to: upper, by: stride) {
					let index = offset % period
					let head = index..<min(index + window.count, period)
					let tail = 0..<max(0, index + window.count - period)
					vDSP_vclrD(memory, 1, .init(stream.i * frame * 2))
					for (source, var r, var i) in zip(fold(start: ib, count: period, stream: stream.i, period: period), i.r, i.i) {
						var target = r.extracting(..<window.count)
						vDSP.multiply(window[..<head.count], source[head], result: &target[..<head.count])
						vDSP.multiply(window[head.count...], source[tail], result: &target[head.count...])
						object.forward.transform(inputReal: r, inputImaginary: i, outputReal: &r, outputImaginary: &i)
					}
					worker(CMTimeMultiply(interval, multiplier: .init(offset)), i.r, i.i, &o.r, &o.i)
					for (var r, var i, target) in zip(o.r, o.i, fold(start: ob, count: period, stream: stream.o, period: period)) {
						object.inverse.transform(inputReal: r, inputImaginary: i, outputReal: &r, outputImaginary: &i)
						var source = r.extracting(..<window.count)
						vDSP.multiply(scale, source, result: &source)
						vDSP.add(multiplication: (window[..<head.count], source[..<head.count]), target[head], result: &target[head])
						vDSP.add(multiplication: (window[head.count...], source[head.count...]), target[tail], result: &target[tail])
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
public func framewise(_ source: Stream, window: Framewise.Window, stride: Framewise.Stride, output count: Int, margin: Rational64 = 1, factor scale: Float64 = 1, ioproc value: @escaping@Sendable (CMTime, Int) throws -> @Sendable (CMTime, ArraySlice<UnsafeMutableBufferPointer<Float64>>, ArraySlice<UnsafeMutableBufferPointer<Float64>>, inout ArraySlice<UnsafeMutableBufferPointer<Float64>>, inout ArraySlice<UnsafeMutableBufferPointer<Float64>>) -> Void) -> some Stream {
	Framewise.DFT.Ne(source: source, window: window, stride: stride, margin: margin, count: count, scale: scale, value: value)
}
public func framewise(_ source: Stream, window: Framewise.Window, stride: Framewise.Stride, output count: Int, margin: Rational64 = 1, factor scale: Float64 = 1, ioproc value: @escaping@Sendable(CMTime, ArraySlice<UnsafeMutableBufferPointer<Float64>>, ArraySlice<UnsafeMutableBufferPointer<Float64>>, inout ArraySlice<UnsafeMutableBufferPointer<Float64>>, inout ArraySlice<UnsafeMutableBufferPointer<Float64>>) -> Void) -> some Stream {
	Framewise.DFT.Ne(source: source, window: window, stride: stride, margin: margin, count: count, scale: scale) { _, _ in value }
}

