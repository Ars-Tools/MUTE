//
//  Buffer+Object.swift
//  MUTE
//
//  Created by Kota on 5/16/R7.
//
extension Buffer {
	public struct Object: Sendable {
		@usableFromInline let stream: Int
		@usableFromInline let period: Int
		@usableFromInline let memory: Autorelease.Memory
		@usableFromInline let offset: Int
	}
}
extension Buffer.Object {
	@inlinable
	init(stream rows: Int, period cols: Int) {
		stream = rows
		period = cols
		memory = .init(count: stream * period) { $0.initialize(repeating: 0 as Float64) }
		offset = 0
	}
}
extension Buffer.Object {
	@inlinable
	func withUnsafePointer<R>(_ body: (UnsafePointer<Float64>) throws -> R) rethrows -> R {
		try body(memory.start.advanced(by: offset).assumingMemoryBound(to: Float64.self))
	}
	@inlinable
	func withUnsafeMutablePointer<R>(_ body: (UnsafeMutablePointer<Float64>) throws -> R) rethrows -> R {
		try body(memory.start.advanced(by: offset).assumingMemoryBound(to: Float64.self))
	}
}
extension Buffer.Object {
	@inlinable
	func copy(cursor: Int, length: Int,
			  source: UnsafePointer<Float64>, stride: Int) {
		assert(length <= period)
		withUnsafeMutablePointer {
			let base = cursor % period
			let head = base..<min(base + length,  period)
			let tail = 0..<max(0, base + length - period)
			MSP.copy(x: source, ldx: stride,
					 y: $0.advanced(by: head.lowerBound), ldy: period,
					 rows: stream, cols: head.count)
			MSP.copy(x: source.advanced(by: head.count), ldx: stride,
					 y: $0, ldy: period,
					 rows: stream, cols: tail.count)
		}
	}
	@inlinable
	func copy(cursor: Int, length: Int,
			  source: UnsafePointer<Float64>, stride: Int,
			  extent: Range<Int>) {
		assert(length <= period)
		withUnsafeMutablePointer {
			let base = cursor % period
			let head = base..<min(base + length,  period)
			let tail = 0..<max(0, base + length - period)
			MSP.copy(x: source, ldx: stride,
					 y: $0.advanced(by: extent.lowerBound * period).advanced(by: head.lowerBound), ldy: period,
					 rows: extent.count, cols: head.count)
			MSP.copy(x: source.advanced(by: head.count), ldx: stride,
					 y: $0.advanced(by: extent.lowerBound * period), ldy: period,
					 rows: extent.count, cols: tail.count)
		}
	}
}
extension Buffer.Object {
	@inlinable
	func copy(cursor: Int, length: Int,
			  target: UnsafeMutablePointer<Float64>, stride: Int) {
		assert(length <= period)
		withUnsafePointer {
			let base = cursor % period
			let head = base..<min(base + length,  period)
			let tail = 0..<max(0, base + length - period)
			MSP.copy(x: $0.advanced(by: head.lowerBound), ldx: period,
					 y: target, ldy: stride,
					 rows: stream, cols: head.count)
			MSP.copy(x: $0, ldx: period,
					 y: target.advanced(by: head.count), ldy: stride,
					 rows: stream, cols: tail.count)
		}
	}
	@inlinable
	func copy(cursor: Int, length: Int,
			  target: UnsafeMutablePointer<Float64>, stride: Int,
			  extent: Range<Int>) {
		assert(length <= period)
		withUnsafePointer {
			let base = cursor % period
			let head = base..<min(base + length,  period)
			let tail = 0..<max(0, base + length - period)
			MSP.copy(x: $0.advanced(by: extent.lowerBound * period).advanced(by: head.lowerBound), ldx: period,
					 y: target, ldy: stride,
					 rows: extent.count, cols: head.count)
			MSP.copy(x: $0.advanced(by: extent.lowerBound * period), ldx: period,
					 y: target.advanced(by: head.count), ldy: stride,
					 rows: extent.count, cols: tail.count)
		}
	}
}
