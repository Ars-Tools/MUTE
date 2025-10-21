//
//  Buffer+Split.swift
//  MUTE
//
//  Created by Kota on 5/22/R7.
//
extension Buffer {
	@usableFromInline
	struct Split<Super: Buffer.Instance> {
		@usableFromInline let`super`: Super
		@usableFromInline let range: Range<Int>
	}
}
extension Buffer.Split: Buffer.Instance {
	@inlinable
	var count: Int {
		range.count
	}
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> (Buffer.Object, Ground) {
		switch try `super`(interval: interval, capacity: capacity, resource: &resource) {
		case (let object, let ground):
			(.init(stream: range.count,
				   period: object.period,
				   memory: object.memory,
				   offset: object.offset + range.lowerBound * object.period * MemoryLayout<Float64>.stride), ground)
		}
	}
}
extension Buffer.Instance {
	@_disfavoredOverload
	public subscript(_ channels: Range<Int>) -> some Buffer.Instance {
		Buffer.Split(super: self, range: channels)
	}
	@_disfavoredOverload
	public subscript(_ channel: Int) -> some Buffer.Instance {
		Buffer.Split(super: self, range: channel..<channel+1)
	}
}
