//
//  Graph+Special.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@usableFromInline
enum Graph {
	@usableFromInline
	final class Special {
		@usableFromInline let source: Stream
		@inlinable
		init(dispatch: Stream) {
			source = dispatch
		}
	}
}
extension Graph.Special: Sendable, Identifiable {}
extension Graph.Special: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
		case.some(var object as Instance):
			defer {
				instance.updateValue(object, forKey: .init(interval: interval, capacity: capacity, identity: id))
			}
			return try source(interval: interval, capacity: capacity, instance: &object)
		case.some:
			throw Error.resourceConflict
		case.none:
			var object = Instance()
			defer {
				instance.updateValue(object, forKey: .init(interval: interval, capacity: capacity, identity: id))
			}
			return try source(interval: interval, capacity: capacity, instance: &object)
		}
	}
}
