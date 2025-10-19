//
//  Autorelease.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
//import Darwin
//import typealias Foundation.FileManager
//import typealias Foundation.POSIXError
//@usableFromInline
//enum Autorelease {
//	@usableFromInline
//	final class Object<Pointee>: @unchecked Sendable {
//		@usableFromInline let reference: UnsafeMutablePointer<Pointee>
//		@usableFromInline let finalizer: @convention(thin) (UnsafeMutablePointer<Pointee>) -> Void
//		@inlinable
//		init(object address: UnsafeMutablePointer<Pointee>, free closure: @convention(thin) (UnsafeMutablePointer<Pointee>) -> Void) {
//			reference = address
//			finalizer = closure
//		}
//		deinit {
//			finalizer(reference)
//		}
//	}
//	@usableFromInline
//	final class Memory: @unchecked Sendable {
//		@usableFromInline let start: UnsafeMutableRawPointer
//		@usableFromInline let count: Int
//		@usableFromInline let deallocator: @convention(c) (UnsafeMutableRawPointer, Int) -> Void
//		@inlinable
//		init(start: UnsafeMutableRawPointer, count: Int, deallocator: @convention(c) (UnsafeMutableRawPointer, Int) -> Void) {
//			self.start = start
//			self.count = count
//			self.deallocator = deallocator
//		}
//		deinit {
//			deallocator(start, count)
//		}
//	}
//	@usableFromInline
//	final class Opaque: @unchecked Sendable {
//		@usableFromInline let pointer: OpaquePointer
//		@usableFromInline let release: @convention(c) (OpaquePointer) -> Void
//		@inlinable
//		init(pointer address: OpaquePointer, release closure: @convention(c) (OpaquePointer) -> Void) {
//			pointer = address
//			release = closure
//		}
//		deinit {
//			release(pointer)
//		}
//	}
//}
//extension Autorelease.Memory {
//	@inlinable
//	convenience init(byteCount: Int, alignment: Int) {
//		self.init(start: .allocate(byteCount: byteCount, alignment: alignment), count: byteCount) { start, count in start.deallocate() }
//	}
//	@usableFromInline
//	convenience init<T: BitwiseCopyable>(repeating element: T, count: Int) {
//		self.init(byteCount: MemoryLayout<T>.stride * count, alignment: MemoryLayout<T>.alignment)
//		start.initializeMemory(as: T.self, repeating: element, count: count)
//	}
//}
//extension Autorelease.Memory {
//	@inlinable
//	convenience init(ro path: String) throws (POSIXError) { // cow
//		let descriptor = switch open(path, O_RDONLY) {
//		case ..<0:
//			throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped)
//		case let descriptor:
//			descriptor
//		}
//		defer {
//			close(descriptor)
//		}
//		var stat = stat()
//		let capacity = switch fstat(descriptor, &stat) {
//		case 0:
//			Int(stat.st_size)
//		default:
//			throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped)
//		}
//		switch mmap(.none, capacity, PROT_READ|PROT_WRITE, MAP_PRIVATE, descriptor, 0) {
//		case.none,MAP_FAILED:
//			throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped)
//		case.some(let start):
//			self.init(start: start, count: capacity) { munmap($0, $1) }
//		}
//	}
//	@inlinable
//	convenience init(rw path: String, minimum capacity: Int = 0, release: Bool = false) throws (POSIXError) {
//		let descriptor = switch open(path, O_RDWR|O_CREAT, S_IWUSR|S_IRUSR|S_IRGRP|S_IROTH) {
//		case ..<0:
//			throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped)
//		case let descriptor:
//			descriptor
//		}
//		defer {
//			close(descriptor)
//			if release {
//				Darwin.unlink(path)
//			}
//		}
//		switch ftruncate(descriptor, .init(capacity)) {
//		case 0:
//			break
//		default:
//			throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped)
//		}
//		switch mmap(.none, capacity, PROT_READ|PROT_WRITE, MAP_SHARED, descriptor, 0) {
//		case.none,MAP_FAILED:
//			throw POSIXError(.init(rawValue: errno).unsafelyUnwrapped)
//		case.some(let start):
//			self.init(start: start, count: capacity) { munmap($0, $1) }
//		}
//	}
//}
//extension Autorelease.Memory {
//	func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
//		try body(.init(start: start, count: count))
//	}
//	func withUnsafeMutableBytes<R>(_ body: (inout UnsafeMutableRawBufferPointer) throws -> R) rethrows -> R {
//		var target = UnsafeMutableRawBufferPointer(start: start, count: count)
//		return try body(&target)
//	}
//}
