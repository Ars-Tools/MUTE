//
//  Framewise+RAW.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
import typealias Accelerate.vDSP
import typealias Synchronization.Mutex
import func CoreMedia.CMTimeMultiply
import typealias Numerics.Rational64
extension Framewise {
	@usableFromInline
	enum RAW {
		@usableFromInline
		struct Ne {
			@usableFromInline let source: Stream
			@usableFromInline let window: Window
			@usableFromInline let stride: Stride
			@usableFromInline let output: Int
			@usableFromInline let ioproc: @Sendable (CMTime, Int) throws -> @Sendable (CMTime, ArraySlice<UnsafeMutableBufferPointer<Float64>>, ArraySlice<UnsafeMutableBufferPointer<Float64>>) -> Void
		}
	}
}
extension Framewise.RAW.Ne: Stream {
	@inlinable
	var count: Int {
		output
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let window = window.coefficients(for: interval)
		let ioproc = try ioproc(interval, window.count)
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let stream = (o: count, i: source.count)
		let stride = switch stride {
		case.absolute(let duration):
			duration.samples(for: interval)
		case.relative(let relation):
			(window.count * Int(relation.numerator) - 1) / Int(relation.denominator) + 1
		}
		let period = capacity + window.count
		let buffer = Buffer(stream: stream.o + stream.i, period: period)
		return { moment, length, target, bounds in
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: max((stream.o + stream.i) * window.count, stream.i * length)) {
				guard let source = $0.baseAddress else { return }
				let layout = fold(start: source, count: window.count, stream: stream.o + stream.i, period: window.count)
				let memory = (o: layout[..<stream.o], i: layout[stream.o...])
				let cursor = moment.samples(for: interval)
				let lower = ( ( cursor          - 1 ) / stride + 1 ) * stride
				let upper = ( ( cursor + length - 1 ) / stride + 1 ) * stride
				let oc = switch ( cursor                ) % period {
				case let index: (
					head: index..<min(index + length, period),
					tail: 0..<max(0, index + length - period)
				)}
				let ic = switch ( cursor + window.count ) % period {
				case let index: (
					head: index..<min(index + length, period),
					tail: 0..<max(0, index + length - period)
				)}
				kernel(moment, length, source, length)
				let ob = buffer.start
				let ib = ob.advanced(by: stream.o * period)
				copy(x: source, ldx: length,
					 y: ib.advanced(by: ic.head.lowerBound), ldy: period,
					 rows: stream.i, cols: ic.head.count)
				copy(x: source.advanced(by: ic.head.count), ldx: length,
					 y: ib, ldy: period,
					 rows: stream.i, cols: ic.tail.count)
				for offset in Swift.stride(from: lower, to: upper, by: stride) {
					let index = offset % period
					let head = index..<min(index + window.count, period)
					let tail = 0..<max(0, index + window.count - period)
					for (offset, var target) in memory.i.enumerated() {
						let source = UnsafeBufferPointer(start: ib.advanced(by: offset * period), count: period)
						vDSP.multiply(window[..<head.count], source[head], result: &target[..<head.count])
						vDSP.multiply(window[head.count...], source[tail], result: &target[head.count...])
					}
					ioproc(CMTimeMultiply(interval, multiplier: .init(offset)), memory.i, memory.o)
					for (offset, source) in memory.o.enumerated() {
						let target = UnsafeMutableBufferPointer(start: ob.advanced(by: offset * period), count: period)
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
				for target in fold(start: ob, count: period, stream: stream.o, period: period) {
					vDSP.clear(&target[oc.head])
					vDSP.clear(&target[oc.tail])
				}
			}
		}
	}
}
public func framewise(_ source: Stream, window: Framewise.Window, stride: Framewise.Stride, output: Int, ioproc: @escaping@Sendable(CMTime, Int) throws -> @Sendable (CMTime, ArraySlice<UnsafeMutableBufferPointer<Float64>>, ArraySlice<UnsafeMutableBufferPointer<Float64>>) -> Void) -> some Stream {
	Framewise.RAW.Ne(source: source, window: window, stride: stride, output: output, ioproc: ioproc)
}
public func framewise(_ source: Stream, window: Framewise.Window, stride: Framewise.Stride, output: Int, ioproc: @escaping@Sendable(CMTime, ArraySlice<UnsafeMutableBufferPointer<Float64>>, ArraySlice<UnsafeMutableBufferPointer<Float64>>) -> Void) -> some Stream {
	Framewise.RAW.Ne(source: source, window: window, stride: stride, output: output) { _, _ in ioproc }
}
