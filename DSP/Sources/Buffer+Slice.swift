//
//  Buffer+Slice.swift
//  MUTE
//
//  Created by Kota on 7/13/R7.
//
//extension Buffer {
//	@usableFromInline
//	struct Slice<Target: Protocol> {
//		@usableFromInline let source: Target
//		@usableFromInline let bounds: Range<Int>
//	}
//}
//extension Buffer.Slice: Buffer.`Protocol` {
//	@inlinable
//	var count: Int {
//		bounds.count
//	}
//	@inlinable
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
//		let buffer = try source(interval: interval, capacity: capacity, instance: &instance)
//		return {
//			buffer($0, $1)[bounds]
//		}
//	}
//}
//extension Buffer.`Protocol` {
//	public subscript(position: Int) -> some Buffer.`Protocol` {
//		Buffer.Slice(source: self, bounds: position..<position+1)
//	}
//	public subscript(bounds: Range<Int>) -> some Buffer.`Protocol` {
//		Buffer.Slice(source: self, bounds: bounds)
//	}
//}
