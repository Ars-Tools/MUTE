//
//  Graph+Inject.swift
//  MUTE
//
//  Created by Kota on 7/17/R7.
//
@usableFromInline
enum Inject {
	@usableFromInline
	struct Ne {
		@usableFromInline let source: Stream
		@usableFromInline let inject: @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void
	}
}
extension Inject.Ne: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		return {
			kernel($0, $1, $2, $3)
			inject($0, $1, $2, $3)
		}
	}
}
public func inject(_ source: Stream, body inject: @escaping@Sendable(CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void) -> some Stream {
	Inject.Ne(source: source, inject: inject)
}
