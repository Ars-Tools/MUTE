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
extension Buffer: Buffer.Object {
    @inlinable
    public var count: Int {
        stream
    }
    @inlinable
    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
        { moment, length in self }
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
	public var unsafeMutableBufferPointer: some Collection<UnsafeMutableBufferPointer<Float64>> {
		// use lazy map to keep memory
		Swift.stride(from: 0, to: stream * period, by: period).lazy.map {
			UnsafeMutableBufferPointer(start: start.advanced(by: $0), count: period)
		}
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
        let head = Swift.min(length, period - base - 0)
        let tail = Swift.max(0, base + length - period)
		DSP.copy(x: source.advanced(by: base), ldx: period,
				 y: target, ldy: stride,
				 rows: stream, cols: head)
		DSP.copy(x: source, ldx: period,
				 y: target.advanced(by: head), ldy: stride,
				 rows: stream, cols: tail)
	}
}
extension Buffer {
    @inlinable@_transparent
	public func copy(cursor: Int, length: Int, source: UnsafePointer<Float64>, stride: Int) {
		assert([(0, cursor), (length, period)].allSatisfy(<=))
		let target = start
		let base = cursor % period
        let head = Swift.min(length, period - base - 0)
        let tail = Swift.max(0, base + length - period)
		DSP.copy(x: source, ldx: stride,
				 y: target.advanced(by: base), ldy: period,
				 rows: stream, cols: head)
		DSP.copy(x: source.advanced(by: head), ldx: stride,
				 y: target, ldy: period,
				 rows: stream, cols: tail)
	}
}
// Direct Storing
extension Buffer {
    @inlinable@inline(__always)@_transparent
	public func copy(cursor: Int, length: Int, source: (UnsafeMutablePointer<Float64>, Int) -> Void) {
        assertionFailure("deprecated")
		assert([(0, cursor), (length, period)].allSatisfy(<=))
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: stream * length) {
            guard let memory = $0.baseAddress else { return }
            source(memory, length)
            let target = start
            let base = cursor % period
            let head = Swift.min(length, period - base - 0)
            let tail = Swift.max(0, base + length - period)
            DSP.copy(x: memory, ldx: length,
                     y: target.advanced(by: base), ldy: period,
                     rows: stream, cols: head)
            DSP.copy(x: memory.advanced(by: head), ldx: length,
                     y: target, ldy: period,
                     rows: stream, cols: tail)
        }
	}
    @inlinable@inline(__always)@_transparent
    public func copy(cursor: Int, length: Int, source: (Int, Int, UnsafeMutablePointer<Float64>, Int) -> Void) {
        assert([(0, cursor), (length, period)].allSatisfy(<=))
        let bank = start
        let base = cursor % period
        let head = Swift.min(length, period - base - 0)
        let tail = Swift.max(0, base + length - period)
        if 0 < head {
            source(   0, head, bank.advanced(by: base), period)
        }
        if 0 < tail {
            source(head, tail, bank.advanced(by:    0), period)
        }
    }
}
// Feed
extension Buffer {
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
        let head = Swift.min(length, period - base - 0)
        let tail = Swift.max(0, base + length - period)
        for cursor in Swift.stride(from: source, to: source.advanced(by: stream * period), by: period) {
            vDSP_vclrD(cursor.advanced(by: base), 1, .init(head))
            vDSP_vclrD(cursor, 1, .init(tail))
        }
    }
    @inlinable@_transparent
    public func fetch(cursor: Int, length: Int, window: UnsafePointer<Float64>, target: UnsafeMutablePointer<Float64>, stride: Int) {
        assert([(0, cursor), (length, period)].allSatisfy(<=))
        let source = start
        let base = cursor % period
        let head = Swift.min(length, period - base - 0)
        let tail = Swift.max(0, base + length - period)
        for offset in 0..<stream {
            let source = source.advanced(by: offset * period)
            let target = target.advanced(by: offset * stride)
            vDSP_vmulD(window, 1,
                       source.advanced(by: base), 1,
                       target, 1,
                       .init(head))
            vDSP_vmulD(window.advanced(by: head), 1,
                       source, 1,
                       target.advanced(by: head), 1,
                       .init(tail))
        }
    }
    @inlinable@_transparent // OLA
    public func merge(cursor: Int, length: Int, window: UnsafePointer<Float64>, source: UnsafePointer<Float64>, stride: Int) {
        assert([(0, cursor), (length, period)].allSatisfy(<=))
        let target = start
        let base = cursor % period
        let head = Swift.min(length, period - base - 0)
        let tail = Swift.max(0, base + length - period)
        for offset in 0..<stream {
            let source = source.advanced(by: offset * stride)
            let target = target.advanced(by: offset * period)
            vDSP_vmaD(window, 1,
                      source, 1,
                      target.advanced(by: base), 1,
                      target.advanced(by: base), 1,
                      .init(head))
            vDSP_vmaD(window.advanced(by: head), 1,
                      source.advanced(by: head), 1,
                      target, 1,
                      target, 1,
                      .init(tail))
        }
    }
    @inlinable@_transparent // mix(buffer, source, weight)
    public func blend(cursor: Int, length: Int, weight: UnsafePointer<Float64>, source: UnsafePointer<Float64>, stride: Int) {
        assert([(0, cursor), (length, period)].allSatisfy(<=))
        let target = start
        let base = cursor % period
        let head = Swift.min(length, period - base - 0)
        let tail = Swift.max(0, base + length - period)
        for offset in 0..<stream {
            let source = source.advanced(by: offset * stride)
            let target = target.advanced(by: offset * period)
            mix_linear(target.advanced(by: base),
                       source,
                       weight,
                       target.advanced(by: base),
                       head)
            mix_linear(target,
                       source.advanced(by: head),
                       weight.advanced(by: head),
                       target,
                       tail)
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
