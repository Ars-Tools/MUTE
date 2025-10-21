//
//  Framewise+Freq.swift
//  MUTE
//
//  Created by Kota on 6/28/R7.
//
import typealias Synchronization.Mutex
import func CoreMedia.CMTimeMultiply
import typealias Accelerate.vDSP
import typealias Accelerate.DSPDoubleSplitComplex
import func Accelerate.vDSP_fftm_ziptD
import func Accelerate.vDSP_create_fftsetupD
import func Accelerate.vDSP_destroy_fftsetupD
import func Accelerate.vDSP_vclrD
import let Accelerate.kFFTRadix2
import let Accelerate.kFFTDirection_Forward
import let Accelerate.kFFTDirection_Inverse
import typealias Numerics.Rational64
@usableFromInline
enum FramewiseFreq {
	@usableFromInline
	struct Ne {
		@usableFromInline let source: Stream
		@usableFromInline let window: WindowDesign
		@usableFromInline let stride: WindowStride
		@usableFromInline let margin: Rational64
		@usableFromInline let count: Int
		@usableFromInline let scale: Float64
		@usableFromInline let value: @Sendable (CMTime, Int) throws -> @Sendable (CMTime, Array<UnsafeMutableBufferPointer<Float64>>, Array<UnsafeMutableBufferPointer<Float64>>, inout Array<UnsafeMutableBufferPointer<Float64>>, inout Array<UnsafeMutableBufferPointer<Float64>>) -> Void
	}
}
extension FramewiseFreq.Ne: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, resource: &resource)
		let stream = (i: source.count, o: count)
		let window = window.coefficients(for: interval)
		let length = (window.count * Int(margin.numerator) - 1) / Int(margin.denominator) + 1
		let log2n = MemoryLayout<Int>.size * 8 - length.leadingZeroBitCount
		let frame = 1 << log2n
		let scale = scale / Float64(frame)
		let stride = switch stride {
		case.absolute(let duration):
			duration.samples(for: interval)
		case.relative(let duration):
			(window.count * Int(duration.numerator) - 1) / Int(duration.denominator) + 1
		}
		let worker = try value(interval, frame)
		let period = capacity + frame
		let buffer = Autorelease.Buffer<Float64>(count: (stream.o + stream.i) * period)
		let object = Autorelease.Opaque(pointer: vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped) {
			vDSP_destroy_fftsetupD($0)
		}
		return { moment, length, target, bounds in
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: max((stream.o + stream.i + 1) * 2 * frame, stream.i * length)) {
				guard let memory = $0.baseAddress else { return }
				var p = DSPDoubleSplitComplex(realp: memory.advanced(by: (0 * stream.i + 0 * stream.o + 0) * frame),
											  imagp: memory.advanced(by: (1 * stream.i + 0 * stream.o + 0) * frame))
				var q = DSPDoubleSplitComplex(realp: memory.advanced(by: (2 * stream.i + 0 * stream.o + 0) * frame),
											  imagp: memory.advanced(by: (2 * stream.i + 1 * stream.o + 0) * frame))
				var b = DSPDoubleSplitComplex(realp: memory.advanced(by: (2 * stream.i + 2 * stream.o + 0) * frame),
											  imagp: memory.advanced(by: (2 * stream.i + 2 * stream.o + 1) * frame))
				let i = (r: zip(Swift.stride(from: 0, to: stream.i * frame, by: frame).lazy.map(p.realp.advanced(by:)),
								sequence(state: frame, next: \.self)).map(UnsafeMutableBufferPointer.init),
						 i: zip(Swift.stride(from: 0, to: stream.i * frame, by: frame).lazy.map(p.imagp.advanced(by:)),
								sequence(state: frame, next: \.self)).map(UnsafeMutableBufferPointer.init))
				var o = (r: zip(Swift.stride(from: 0, to: stream.o * frame, by: frame).lazy.map(q.realp.advanced(by:)),
								sequence(state: frame, next: \.self)).map(UnsafeMutableBufferPointer.init),
						 i: zip(Swift.stride(from: 0, to: stream.o * frame, by: frame).lazy.map(q.imagp.advanced(by:)),
								sequence(state: frame, next: \.self)).map(UnsafeMutableBufferPointer.init))
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
				let lower = ( ( cursor          - 1 ) / stride + 1 ) * stride
				let upper = ( ( cursor + length - 1 ) / stride + 1 ) * stride
				for offset in Swift.stride(from: lower, to: upper, by: stride) {
					let index = offset % period
					let head = index..<min(index + window.count, period)
					let tail = 0..<max(0, index + window.count - period)
					vDSP_vclrD(memory, 1, .init((stream.o + stream.i) * 2 * frame))
					for (offset, target) in i.r.enumerated() {
						let source = UnsafeBufferPointer(start: ib.advanced(by: offset * period), count: period)
						var target = target.extracting(..<window.count)
						vDSP.multiply(window[..<head.count], source[head], result: &target[..<head.count])
						vDSP.multiply(window[head.count...], source[tail], result: &target[head.count...])
					}
					vDSP_fftm_ziptD(object.pointer, &p, 1, .init(frame), &b, .init(log2n), .init(stream.i), .init(kFFTDirection_Forward))
					worker(CMTimeMultiply(interval, multiplier: .init(offset)), i.r, i.i, &o.r, &o.i)
					vDSP_fftm_ziptD(object.pointer, &q, 1, .init(frame), &b, .init(log2n), .init(stream.o), .init(kFFTDirection_Inverse))
					for (offset, source) in o.r.enumerated() {
						var source = source.extracting(..<window.count)
						let target = UnsafeMutableBufferPointer(start: ob.advanced(by: offset * period), count: period)
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
				for cursor in Swift.stride(from: 0, to: stream.o * period, by: period).lazy.map(ob.advanced(by:)) {
					let buffer = UnsafeMutableBufferPointer(start: cursor, count: period)
					vDSP.clear(&buffer[oc.head])
					vDSP.clear(&buffer[oc.tail])
				}
			}
		}
	}
}
public func framewise(_ source: Stream, window: WindowDesign, stride: WindowStride, output count: Int, margin: Rational64 = 1, factor scale: Float64 = 1, ioproc value: @escaping@Sendable (CMTime, Int) throws -> @Sendable (CMTime, Array<UnsafeMutableBufferPointer<Float64>>, Array<UnsafeMutableBufferPointer<Float64>>, inout Array<UnsafeMutableBufferPointer<Float64>>, inout Array<UnsafeMutableBufferPointer<Float64>>) -> Void) -> some Stream {
	FramewiseFreq.Ne(source: source, window: window, stride: stride, margin: margin, count: count, scale: scale, value: value)
}
public func framewise(_ source: Stream, window: WindowDesign, stride: WindowStride, output count: Int, margin: Rational64 = 1, factor scale: Float64, ioproc value: @escaping@Sendable(CMTime, Array<UnsafeMutableBufferPointer<Float64>>, Array<UnsafeMutableBufferPointer<Float64>>, inout Array<UnsafeMutableBufferPointer<Float64>>, inout Array<UnsafeMutableBufferPointer<Float64>>) -> Void) -> some Stream {
	FramewiseFreq.Ne(source: source, window: window, stride: stride, margin: margin, count: count, scale: scale) { _, _ in value }
}
