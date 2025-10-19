//
//  Protocol+Effect.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
public protocol Effect: Sendable {
	@inlinable func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws
}
@usableFromInline
struct Affect<Target: Sequence<Effect> & Sendable> {
	@usableFromInline let stream: Stream
	@usableFromInline let effect: Target
}
extension Affect: Stream {
	@inlinable
	var count: Int {
		stream.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		for effect in effect {
			try effect(interval: interval, capacity: capacity, instance: &instance)
		}
		return try stream(interval: interval, capacity: capacity, instance: &instance)
	}
}
extension Stream {
	public func with(_ effect: some Sequence<Effect> & Sendable) -> some Stream {
		Affect(stream: self, effect: effect)
	}
	@_disfavoredOverload
	public func with(_ effect: Effect...) -> some Stream {
		Affect(stream: self, effect: effect)
	}
}
