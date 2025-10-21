//
//  Framewise+Inplace.swift
//  MUTE
//
//  Created by Kota on 6/28/R7.
//
import typealias Accelerate.vDSP
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import func CoreMedia.CMTimeMultiply
@usableFromInline
enum FramewiseInplace {
	@usableFromInline
	struct Ne {
		@usableFromInline let source: Stream
		@usableFromInline let window: WindowDesign
		@usableFromInline let stride: WindowStride
		@usableFromInline let`operator`: @Sendable (CMTime) throws -> @Sendable (CMTime, Array<UnsafeMutableBufferPointer<Float64>.SubSequence>) -> Void
	}
}
extension FramewiseInplace.Ne {
	@inlinable
	var count: Int {
		source.count
	}
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, resource: &resource)
		let worker = try`operator`(interval)
		let stream = source.count
		let window = window.coefficients(for: interval)
		let slides = switch stride {
		case.absolute(let duration):
			duration.samples(for: interval)
		case.relative(let duration):
			(window.count * Int(duration.numerator) - 1) / Int(duration.denominator) + 1
		}
		let period = capacity * window.count
		let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: ( stream + stream ) * period))
		return { moment, length, result, stride in
			kernel(moment, length, result, stride)
			let cursor = moment.samples(for: interval)
			let rwc = (
				w: ( cursor + window.count ) % period,
				r: cursor % period
			)
			let rc = (
				head: rwc.r..<min(rwc.r + length, period),
				tail: 0..<max(0, rwc.r + length - period)
			)
			let wc = (
				head: rwc.w..<min(rwc.w + length, period),
				tail: 0..<max(0, rwc.w + length - period)
			)
			buffer.withLock { $0.withUnsafeMutablePointer {
				let wb = $0
				let rb = $0.advanced(by: stream * period)
				copy(x: result, ldx: stride,
					 y: wb.advanced(by: wc.head.lowerBound), ldy: period,
					 rows: stream, cols: wc.head.count)
				copy(x: result.advanced(by: wc.head.count), ldx: stride,
					 y: wb, ldy: period,
					 rows: stream, cols: wc.tail.count)
				let cursor = ( ( cursor - 1 ) / slides + 1 ) * slides
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: stream * window.count) {
					let memory = zip(sequence(state: $0, next: \.self), Swift.stride(from: 0, to: $0.count, by: window.count)).map { $0[$1..<$1+window.count] }
					for offset in Swift.stride(from: cursor, to: cursor + length, by: slides) {
						let index = offset % period
						let fc = (
							head: index..<min(index + window.count, period),
							tail: 0..<max(0, index + window.count - period)
						)
						for (offset, var target) in memory.enumerated() {
							let source = UnsafeBufferPointer(start: wb.advanced(by: offset * period), count: period)
							vDSP.multiply(window[..<fc.head.count],
										  source[fc.head],
										  result: &target[..<fc.head.count])
							vDSP.multiply(window[fc.head.count...],
										  source[fc.tail],
										  result: &target[fc.head.count...])
						}
						worker(CMTimeMultiply(interval, multiplier: .init(offset)), memory)
						for (offset, source) in memory.enumerated() {
							let target = UnsafeMutableBufferPointer(start: rb.advanced(by: offset * period), count: period)
							vDSP.add(multiplication: (window[..<fc.head.count], source[..<fc.head.count]),
									 target[fc.head], result: &target[fc.head])
							vDSP.add(multiplication: (window[fc.head.count...], source[fc.head.count...]),
									 target[fc.tail], result: &target[fc.tail])
						}
					}
				}
				copy(x: rb.advanced(by: rc.head.lowerBound), ldx: period,
					 y: result, ldy: stride,
					 rows: stream, cols: rc.head.count)
				copy(x: rb, ldx: period,
					 y: result.advanced(by: rc.head.count), ldy: stride,
					 rows: stream, cols: rc.tail.count)
				for offset in 0..<stream {
					let buffer = UnsafeMutableBufferPointer(start: rb.advanced(by: offset * period), count: period)
					vDSP.clear(&buffer[rc.head])
					vDSP.clear(&buffer[rc.tail])
				}
			}}
		}
	}
}
