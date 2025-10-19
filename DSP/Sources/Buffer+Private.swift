//
//  Buffer+Private.swift
//  MUTE
//
//  Created by Kota on 7/15/R7.
//
import typealias Synchronization.Atomic
import os.log
extension Buffer {
	@usableFromInline
	final class Private: Sendable, Identifiable {
		@usableFromInline let stream: Int
		@usableFromInline let period: Duration
		@usableFromInline let follow: Atomic<UInt>
		@inlinable
		init(count: Int, capacity: Duration) {
			stream = count
			period = capacity
			follow = .init(0)
		}
	}
}
extension Buffer.Private {
	@inlinable
	func retain() {
		follow.add(1, ordering: .acquiringAndReleasing)
	}
	@inlinable
	func release() {
		follow.subtract(1, ordering: .acquiringAndReleasing)
	}
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> Buffer {
		switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
		case.some(let buffer as Buffer):
			return buffer
		case.some:
			throw Error.resourceConflict
		case.none:
			switch follow.load(ordering: .acquiring) {
			case 2...:
				throw Error.resourceConflict
			case 0:
				os_log(.info, log: type(of: self).subsystem, "%{public}@ will be no longer update", String(describing: id))
				fallthrough
			default:
				let buffer = Buffer(stream: stream, period: period.samples(for: interval) + capacity)
				guard case.none = instance.updateValue(buffer, forKey: .init(interval: interval, capacity: capacity, identity: id)) else {
					throw Error.invalidContext
				}
				return buffer
			}
		}
	}
}
extension Buffer.Private: Buffer.`Protocol` {
	private static let subsystem = OSLog(subsystem: #file, category: .pointsOfInterest)
	@inlinable
	var count: Int {
		stream
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
		let buffer = try callAsFunction(interval: interval, capacity: capacity, instance: &instance) as Buffer
		return { moment, length in buffer }
	}	
}
extension Buffer.Private: Buffer.Reference {
	@inlinable
	var target: some Buffer.`Protocol` {
		self
	}
}
