//
//  Buffer.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
import typealias Accelerate.vDSP
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMatrixBuffer
import typealias Accelerate.AccelerateMatrixOrder
import typealias Auxiliary.Autorelease
import func Accelerate.vDSP_vclrD
import func Accelerate.vDSP_vmulD
import func Accelerate.vDSP_vsbmD
import func Accelerate.vDSP_vmaD
import func Accelerate.vDSP_vmsbD
import func NSP.periodic_lookup_with_static
import func NSP.periodic_lookup_with_active
import func NSP.mix_linear
public struct Buffer: Sendable {
	public let stream: Int
	public let period: Int
	@usableFromInline let memory: Autorelease.Memory
	@usableFromInline let offset: Int
}
extension Buffer {
	@inlinable
	public init(stream rows: Int, period cols: Int) {
		stream = rows
		period = cols
		memory = .init(repeating: .zero as Float64, count: stream * period)
		offset = 0
	}
}
extension Buffer {
	public protocol `Protocol`: Sendable {
		@inlinable var count: Int { get }
		@inlinable func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer
	}
}
extension Buffer: RandomAccessCollection {
//	public typealias Element = Float64
	public typealias Index = Int
	public var startIndex: Int { 0 }
	public var endIndex: Int { count }
    @inlinable
	public subscript(position: Int) -> Buffer {
        self[position...position, 0...]
	}
    @inlinable
	public subscript(bounds: some RangeExpression<Int>) -> Buffer {
        self[bounds, 0...]
	}
    @inlinable
    public subscript(position: Int, sample: some RangeExpression<Int>) -> Buffer {
        self[position...position, sample]
    }
    public subscript(bounds: some RangeExpression<Int>, sample: some RangeExpression<Int>) -> Buffer {
        let bounds = bounds.relative(to: 0..<stream)
        let sample = sample.relative(to: 0..<period)
        precondition([bounds, sample].allSatisfy { !$0.isEmpty })
        return.init(stream: bounds.count,
                    period: period,
                    memory: memory,
                    offset: offset + (bounds.lowerBound * period + sample.lowerBound) * MemoryLayout<Float64>.stride)
    }
    @inlinable
    public subscript(stream: Int, sample: Int) -> Float64 {
        start[stream*period+sample]
    }
    @inlinable
    public subscript(bounds: some RangeExpression<Int>, sample: Int) -> Array<Float64> {
        stride(from: 0, to: stream * period, by: period)
            .map(bounds.relative(to: 0..<stream).lowerBound.advanced(by:))
            .map(start.advanced(by:))
            .map(\.pointee)
    }
}
extension Buffer {
    @inlinable@_transparent
	public var unsafeMutableBufferPointer: some Collection<UnsafeMutableBufferPointer<Float64>> {
		// use lazy map to keep memory
		Swift.stride(from: 0, to: stream * period, by: period).lazy.map {
			UnsafeMutableBufferPointer(start: start.advanced(by: $0), count: period)
		}
	}
}
extension Buffer {
    @inlinable@_transparent
	public var start: UnsafeMutablePointer<Float64> {
		memory.start.advanced(by: offset).assumingMemoryBound(to: Float64.self)
	}
}
extension Buffer {
    @inlinable@_transparent
	public func withUnsafePointer<R>(_ body: (UnsafePointer<Float64>) throws -> R) rethrows -> R {
		try body(memory.start.advanced(by: offset).assumingMemoryBound(to: Float64.self))
	}
    @inlinable@_transparent
	public func withUnsafeMutablePointer<R>(_ body: (UnsafeMutablePointer<Float64>) throws -> R) rethrows -> R {
		try body(memory.start.advanced(by: offset).assumingMemoryBound(to: Float64.self))
	}
}
extension Buffer: Buffer.`Protocol` {
    @inlinable@_transparent
	public var count: Int {
		stream
	}
    @inlinable@_transparent
	public var reference: Self {
		self
	}
    @inlinable@_transparent
	public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
		{ moment, length in self }
	}
}
extension Buffer: DSP.Stream {
    @inlinable@_transparent
	public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		{ // oneshot
			let lower = $0.samples(for: interval)
			let upper = lower + $1
			let range = lower..<upper
			let valid = range.clamped(to: 0..<period)
			for var target in fold(start: $2, count: $1, stream: stream, period: $3) {
				vDSP.clear(&target[..<Swift.max(target.startIndex, Swift.min(target.endIndex, valid.lowerBound - range.lowerBound))])
				vDSP.clear(&target[Swift.max(target.startIndex, Swift.min(target.endIndex, valid.upperBound - range.lowerBound))...])
			}
			DSP.copy(x: start.advanced(by: valid.lowerBound), ldx: period,
					 y: $2.advanced(by: valid.lowerBound - range.lowerBound), ldy: $3,
					 rows: stream, cols: valid.count)
		}
	}
}
extension Buffer {
    @inlinable@_transparent
	public func copy(cursor: Int, length: Int, target: UnsafeMutablePointer<Float64>, stride: Int) {
		assert([(0, cursor), (length, period)].allSatisfy(<=))
		let source = start
		let base = cursor % period
		let head = base..<Swift.min(base + length,  period)
		let tail = 0..<Swift.max(0, base + length - period)
		DSP.copy(x: source.advanced(by: head.lowerBound), ldx: period,
				 y: target, ldy: stride,
				 rows: stream, cols: head.count)
		DSP.copy(x: source, ldx: period,
				 y: target.advanced(by: head.count), ldy: stride,
				 rows: stream, cols: tail.count)
	}
}
extension Buffer {
    @inlinable@_transparent
	public func copy(cursor: Int, length: Int, source: UnsafePointer<Float64>, stride: Int) {
		assert([(0, cursor), (length, period)].allSatisfy(<=))
		let target = start
		let base = cursor % period
		let head = base..<Swift.min(base + length,  period)
		let tail = 0..<Swift.max(0, base + length - period)
		DSP.copy(x: source, ldx: stride,
				 y: target.advanced(by: head.lowerBound), ldy: period,
				 rows: stream, cols: head.count)
		DSP.copy(x: source.advanced(by: head.count), ldx: stride,
				 y: target, ldy: period,
				 rows: stream, cols: tail.count)
	}
}
// Direct Storing
extension Buffer {
    @inlinable@_transparent
	public func copy(cursor: Int, length: Int, source: (UnsafeMutablePointer<Float64>, Int) -> Void) {
		assert([(0, cursor), (length, period)].allSatisfy(<=))
		let target = start
		switch cursor % period {
		case let base where base + length < period:
			source(target.advanced(by: base), period)
		case let base:
			let head = base..<Swift.min(base + length,  period)
			let tail = 0..<Swift.max(0, base + length - period)
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: stream * length) {
				vDSP.clear(&$0[0..<$0.count])
				guard let memory = $0.baseAddress else { return }
				source(memory, length)
				DSP.copy(x: memory, ldx: length,
						 y: target.advanced(by: head.lowerBound), ldy: period,
						 rows: stream, cols: head.count)
				DSP.copy(x: memory.advanced(by: head.count), ldx: length,
						 y: target, ldy: period,
						 rows: stream, cols: tail.count)
			}
		}
	}
}
// Feed
extension Buffer {
    @inlinable@_transparent
    public func feed(cursor: UnsafePointer<Float64>, length: Int, target: UnsafeMutablePointer<Float64>, stride: Int) {
        let source = start
        for stream in (0..<stream).reversed() {
            periodic_lookup_with_static(source.advanced(by: stream * period),
                                        cursor,
                                        target.advanced(by: stream * stride),
                                        period, length)
        }
    }
    @inlinable@_transparent
    public func read(cursor: UnsafePointer<Float64>, length: Int, target: UnsafeMutablePointer<Float64>, stride: Int) {
        let source = start
        for stream in (0..<stream).reversed() {
            periodic_lookup_with_static(source.advanced(by: stream * period),
                                        cursor,
                                        target.advanced(by: stream * stride),
                                        period, length)
        }
    }
}
// OLA
extension Buffer {
    @inlinable@_transparent
    public func flush(cursor: Int, length: Int) {
        let source = start
        let base = cursor % period
        let head = base..<Swift.min(base + length,  period)
        let tail = 0..<Swift.max(0, base + length - period)
        for cursor in Swift.stride(from: source, to: source.advanced(by: stream * period), by: period) {
            vDSP_vclrD(cursor.advanced(by: head.lowerBound), 1, .init(head.count))
            vDSP_vclrD(cursor, 1, .init(tail.count))
        }
    }
    @inlinable@_transparent
    public func fetch(cursor: Int, length: Int, window: UnsafePointer<Float64>, target: UnsafeMutablePointer<Float64>, stride: Int) {
        assert([(0, cursor), (length, period)].allSatisfy(<=))
        let source = start
        let base = cursor % period
        let head = base..<Swift.min(base + length,  period)
        let tail = 0..<Swift.max(0, base + length - period)
        for offset in 0..<stream {
            let source = source.advanced(by: offset * period)
            let target = target.advanced(by: offset * stride)
            vDSP_vmulD(window, 1,
                       source.advanced(by: head.lowerBound), 1,
                       target, 1,
                       .init(head.count))
            vDSP_vmulD(window.advanced(by: head.count), 1,
                       source, 1,
                       target.advanced(by: head.count), 1,
                       .init(tail.count))
        }
    }
    @inlinable@_transparent // OLA
    public func merge(cursor: Int, length: Int, window: UnsafePointer<Float64>, source: UnsafePointer<Float64>, stride: Int) {
        assert([(0, cursor), (length, period)].allSatisfy(<=))
        let target = start
        let base = cursor % period
        let head = base..<Swift.min(base + length,  period)
        let tail = 0..<Swift.max(0, base + length - period)
        for offset in 0..<stream {
            let source = source.advanced(by: offset * stride)
            let target = target.advanced(by: offset * period)
            vDSP_vmaD(window, 1,
                      source, 1,
                      target.advanced(by: head.lowerBound), 1,
                      target.advanced(by: head.lowerBound), 1,
                      .init(head.count))
            vDSP_vmaD(window.advanced(by: head.count), 1,
                      source.advanced(by: head.count), 1,
                      target, 1,
                      target, 1,
                      .init(tail.count))
        }
    }
    @inlinable@_transparent // mix(buffer, source, weight)
    public func blend(cursor: Int, length: Int, weight: UnsafePointer<Float64>, source: UnsafePointer<Float64>, stride: Int) {
        assert([(0, cursor), (length, period)].allSatisfy(<=))
        let target = start
        let base = cursor % period
        let head = base..<Swift.min(base + length,  period)
        let tail = 0..<Swift.max(0, base + length - period)
        for offset in 0..<stream {
            let source = source.advanced(by: offset * stride)
            let target = target.advanced(by: offset * period)
            mix_linear(target.advanced(by: head.lowerBound),
                       source,
                       weight,
                       target.advanced(by: head.lowerBound),
                       head.count)
            mix_linear(target,
                       source.advanced(by: head.count),
                       weight.advanced(by: head.count),
                       target,
                       tail.count)
//            vDSP_vmsbD(weight, 1,
//                       target.advanced(by: head.lowerBound), 1,
//                       target.advanced(by: head.lowerBound), 1,
//                       target.advanced(by: head.lowerBound), 1,
//                       .init(head.count))
//            vDSP_vmsbD(weight, 1,
//                       source, 1,
//                       target.advanced(by: head.lowerBound), 1,
//                       target.advanced(by: head.lowerBound), 1,
//                       .init(head.count))
//            vDSP_vmsbD(weight.advanced(by: head.count), 1,
//                       target, 1,
//                       target, 1,
//                       target, 1,
//                       .init(tail.count))
//            vDSP_vmsbD(weight.advanced(by: head.count), 1,
//                       source.advanced(by: head.count), 1,
//                       target, 1,
//                       target, 1,
//                       .init(tail.count))
        }
    }
}
