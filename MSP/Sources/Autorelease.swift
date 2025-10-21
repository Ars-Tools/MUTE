//
//  Autorelease.swift
//  MUTE
//
//  Created by Kota on 5/15/R7.
//
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
@usableFromInline
enum Autorelease {
	@usableFromInline
	final class Object<Pointee>: @unchecked Sendable {
		@usableFromInline let reference: UnsafeMutablePointer<Pointee>
		@usableFromInline let finalizer: @convention(thin) (UnsafeMutablePointer<Pointee>) -> Void
		@inlinable
		init(object address: UnsafeMutablePointer<Pointee>, free closure: @convention(thin) (UnsafeMutablePointer<Pointee>) -> Void) {
			reference = address
			finalizer = closure
		}
		deinit {
			finalizer(reference)
		}
	}
	@usableFromInline
	final class Memory: @unchecked Sendable {
		@usableFromInline let start: UnsafeMutableRawPointer
		@usableFromInline let count: Int
		@usableFromInline let deallocator: @convention(c) (UnsafeMutableRawPointer, Int) -> Void
		@inlinable
		init(start: UnsafeMutableRawPointer, count: Int, deallocator: @convention(c) (UnsafeMutableRawPointer, Int) -> Void) {
			self.start = start
			self.count = count
			self.deallocator = deallocator
		}
		deinit {
			deallocator(start, count)
		}
	}
	@usableFromInline
	final class Opaque: @unchecked Sendable {
		@usableFromInline let pointer: OpaquePointer
		@usableFromInline let release: @convention(c) (OpaquePointer) -> Void
		@inlinable
		init(pointer: OpaquePointer, release: @convention(c) (OpaquePointer) -> Void) {
			self.pointer = pointer
			self.release = release
		}
		deinit {
			release(pointer)
		}
	}
	@usableFromInline
	struct Buffer<Element: BitwiseCopyable>: Sendable {
		@usableFromInline let memory: Memory
		@usableFromInline let layout: Range<Int>
	}
}
extension Autorelease.Memory {
	@inlinable
	func withUnsafeRawBufferPointer<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
		try body(.init(start: start, count: count))
	}
	@inlinable
	func withUnsafeMutableRawBufferPointer<R>(_ body: (UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
		try body(.init(start: start, count: count))
	}
}
extension Autorelease.Memory {
	@inlinable
	convenience init<T: BitwiseCopyable>(count: Int, as type: T.Type = T.self) {
		self.init(start: .allocate(byteCount: count * MemoryLayout<T>.stride, alignment: MemoryLayout<T>.alignment),
				  count: count * MemoryLayout<T>.stride) { start, count in
			start.deallocate()
		}
	}
	@inlinable
	convenience init<T: BitwiseCopyable>(count: Int, initialize: (UnsafeMutableBufferPointer<T>) throws -> Void) rethrows {
		self.init(count: count, as: T.self)
		try withUnsafeMutableRawBufferPointer {
			try initialize($0.assumingMemoryBound(to: T.self))
		}
	}
}
extension Autorelease.Memory {
	
}
extension Autorelease.Buffer {
	@inlinable
	init(count: Int) where Element: Numeric {
		memory = .init(count: count, as: Element.self)
		memory.start.initializeMemory(as: Element.self, repeating: .zero, count: count)
		layout = 0..<count
	}
}
extension Autorelease.Buffer {
	@inlinable
	var start: UnsafeMutablePointer<Element> {
		memory.start.assumingMemoryBound(to: Element.self).advanced(by: layout.lowerBound)
	}
	@inlinable
	var count: Int {
		layout.count
	}
}
extension Autorelease.Buffer: AccelerateBuffer {
	@inlinable
	func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R {
		try body(.init(start: start, count: count))
	}
}
extension Autorelease.Buffer: AccelerateMutableBuffer {
	@inlinable
	func withUnsafeMutableBufferPointer<R>(_ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R) rethrows -> R {
		var buffer = UnsafeMutableBufferPointer(start: start, count: count)
		return try body(&buffer)
	}
}
extension Autorelease.Buffer: RandomAccessCollection {
	@inlinable
	var startIndex: Int {
		layout.lowerBound
	}
	@inlinable
	var endIndex: Int {
		layout.upperBound
	}
	@inlinable
	subscript(position: Int) -> Element {
		_read {
			yield start[position]
		}
		_modify {
			yield &start[position]
		}
	}
	@usableFromInline
	subscript(bounds: Range<Int>) -> Self {
		get {
			.init(memory: memory, layout: bounds)
		}
		set {
			start.advanced(by: bounds.lowerBound).update(from: newValue.start, count: bounds.count)
		}
	}
}
