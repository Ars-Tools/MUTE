//
//  Graph+Resize.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
import func CoreMedia.CMTimeAdd
import func CoreMedia.CMTimeMultiply
@usableFromInline
enum Resize {
	@usableFromInline
	struct Ne {
		@usableFromInline let source: Stream
		@usableFromInline let resize: Duration
	}
}
extension Resize.Ne: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let number = source.count
		let period = resize.samples(for: interval)
		let kernel = try source(interval: interval, capacity: period, instance: &instance)
		let buffer = Buffer(stream: number, period: period)
		return {
			let remain = switch $0.times(of: interval, rounding: .some(.roundHalfAwayFromZero)).quotient % period {
			case let remain:
				period * remain.signum() - remain
			}
			let memory = buffer.start
			copy(x: memory.advanced(by: period - remain), ldx: period,
				 y: $2, ldy: $3,
				 rows: number, cols: min($1, remain))
			for offset in stride(from: remain, to: $1, by: period) {
				assert(offset < $1)
				kernel(CMTimeAdd($0, CMTimeMultiply(interval, multiplier: .init(offset))), period, memory, period)
				copy(x: memory, ldx: period,
					 y: $2.advanced(by: offset), ldy: $3,
					 rows: number, cols: min($1 - offset, period))
			}
		}
	}
}
public func resize(_ source: Stream, resize: Duration) -> some Stream {
	Resize.Ne(source: source, resize: resize)
}
