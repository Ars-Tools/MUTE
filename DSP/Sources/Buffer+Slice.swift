//
//  Buffer+Slice.swift
//  MUTE
//
//  Created by Kota on 7/13/R7.
//
extension Buffer: RandomAccessCollection {
    public typealias Index = Int
    @inlinable
    public var startIndex: Int { 0 }
    @inlinable
    public var endIndex: Int { count }
    @inlinable
    public subscript(position: Int) -> Buffer {
        get {
            self[position...position]
        }
        set {
            self[position...position] = newValue
        }
    }
    public subscript(bounds: some RangeExpression<Int>) -> Buffer {
        get {
            let bounds = bounds.relative(to: 0..<stream)
            return.init(stream: bounds.count,
                        period: period,
                        memory: memory,
                        offset: offset + (bounds.lowerBound * period) * MemoryLayout<Float64>.stride)
        }
        set {
            let bounds = bounds.relative(to: 0..<stream)
            DSP.copy(x: newValue.start, ldx: newValue.period,
                     y: start, ldy: period,
                     rows: Swift.min(bounds.count, newValue.stream),
                     cols: Swift.min(period, newValue.period))
        }
    }
    @inlinable
    public subscript(stream: Int, sample: Int) -> Float64 {
        _read {
            yield start[stream*period+sample]
        }
        _modify {
            yield &start[stream*period+sample]
        }
    }
    @inlinable
    public subscript(bounds: some RangeExpression<Int>, sample: Int) -> Array<Float64> {
        stride(from: 0, to: stream * period, by: period)
            .map(bounds.relative(to: 0..<stream).lowerBound.advanced(by:))
            .map(start.advanced(by: sample).advanced(by:))
            .map(\.pointee)
    }
}
extension Buffer {
	@usableFromInline
	struct Slice<Target: Object> {
		@usableFromInline let source: Target
		@usableFromInline let bounds: Range<Int>
	}
}
extension Buffer.Slice: Buffer.Object {
	@inlinable
	var count: Int {
		bounds.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
		let buffer = try source(interval: interval, capacity: capacity, instance: &instance)
		return {
			buffer($0, $1)[bounds]
		}
	}
}
extension Buffer.Object {
	public subscript(position: Int) -> some Buffer.Object {
		Buffer.Slice(source: self, bounds: position..<position+1)
	}
	public subscript(bounds: Range<Int>) -> some Buffer.Object {
		Buffer.Slice(source: self, bounds: bounds)
	}
}
