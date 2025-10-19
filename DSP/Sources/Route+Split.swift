//
//  Route+Split.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@usableFromInline
enum Split {
	@usableFromInline
	struct Ne {
		@usableFromInline let source: Stream
		@usableFromInline let ranges: RangeSet<Int>
	}
}
extension Split.Ne: Stream {
	@inlinable
	var count: Int {
		ranges.ranges.lazy.map(\.count).reduce(0, +)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let stream = source.count
		let ranges = sequence(state: (ranges.ranges.makeIterator(), 0 as Int)) { state in
			state.0.next().map { element in
				defer {
					state.1 += element.count
				}
				return (state.1, element)
			}
		}.map(\.self)
		return { moment, length, target, stride in
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: stream * length) {
				guard let source = $0.baseAddress else { return }
				kernel(moment, length, source, length)
				for (offset, ranges) in ranges {
					copy(x: source.advanced(by: ranges.lowerBound * length), ldx: length,
						 y: target.advanced(by: offset * stride), ldy: stride,
						 rows: ranges.count, cols: length)
				}
			}
		}
	}
}
extension Stream {
	@_disfavoredOverload
	public subscript(subranges: RangeSet<Int>) -> some Stream {
		Split.Ne(source: self, ranges: subranges)
	}
	@_disfavoredOverload
	public subscript(bounds: Range<Int>) -> some Stream {
		Split.Ne(source: self, ranges: .init(bounds))
	}
}
