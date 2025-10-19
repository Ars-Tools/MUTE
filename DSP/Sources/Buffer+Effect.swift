//
//  Buffer+Effect.swift
//  MUTE
//
//  Created by Kota on 7/15/R7.
//
import typealias Synchronization.Mutex
import typealias CoreMedia.CMTimeRange
import func CoreMedia.CMTimeMultiply
import os.log
extension Buffer {
	public protocol Effect: DSP.Effect, Reference {
		@inlinable
		var input: Optional<DSP.Stream> { get nonmutating set }
	}
	@usableFromInline
	final class Eager: Sendable, Identifiable {
		@usableFromInline let source: Mutex<Optional<DSP.Stream>>
		@usableFromInline let target: Private
		@inlinable
		init(upstream count: Int, capacity: Duration) {
			source = .init(.none)
			target = .init(count: count, capacity: capacity)
			target.retain()
		}
		deinit {
			target.release()
		}
	}
}
//extension Buffer.Eager: Buffer.`Protocol` {
//	@inlinable
//	var count: Int {
//		target.count
//	}
//	@usableFromInline
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
//		assertionFailure("embedding Buffer.Lazy into DSP diagram, the circular reference might be occured")
//		try callAsFunction(interval: interval, capacity: capacity, instance: &instance) as Void
//		return try target(interval: interval, capacity: capacity, instance: &instance)
//	}
//}
extension Buffer.Eager: Buffer.Effect {
	private static let subsystem = OSLog(subsystem: #file, category: .pointsOfInterest)
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws {
		switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
		case.some(is Prefix.Element):
			break
		case.some(id as ObjectIdentifier):
			os_log(.debug, log: type(of: self).subsystem, "%@ Manual release might be required", String(describing: id))
		case.some:
			throw Error.resourceConflict
		case.none:
			guard case.some(let source) = source.withLock(\.self) else {
				os_log(.debug, log: type(of: self).subsystem, "no longer update", String(describing: id))
				return
			}
			guard case.none = instance.updateValue(id, forKey: .init(interval: interval, capacity: capacity, identity: id)) else {
				throw Error.invalidContext
			}
			let buffer = try target(interval: interval, capacity: capacity, instance: &instance) as Buffer
			let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
			guard case.some(id as ObjectIdentifier) = instance.updateValue({ moment, length in
				buffer.copy(cursor: moment.samples(for: interval), length: length) {
					kernel(moment, length, $0, $1)
				}
			} as Prefix.Element, forKey: .init(interval: interval, capacity: capacity, identity: id)) else {
				throw Error.invalidContext
			}
		}
	}
	@inlinable
	var input: Optional<DSP.Stream> {
		get {
			source.withLock(\.self)
		}
		set {
			source.withLock {
				$0 = newValue
			}
		}
	}
}
extension Buffer.Eager: Buffer.Reference {
	
}
public func buffer(_ upstream: Int, capacity: Duration = 0 as Samples) -> some Buffer.Effect {
	Buffer.Eager(upstream: upstream, capacity: capacity)
}
extension RangeReplaceableCollection where Element == Effect {
	public mutating func buffer(_ upstream: Int, capacity: Duration = 0 as Samples) -> some Buffer.Effect {
		let effect = Buffer.Eager(upstream: upstream, capacity: capacity)
		defer {
			append(effect)
		}
		return effect
	}
}
//extension Buffer.Lazy: DSP.Effect {
//	private static let subsystem = OSLog(subsystem: #file, category: .pointsOfInterest)
//	@usableFromInline
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws {
//		switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
//		case.some(is Endpoint):
//			break
//		case.some(id as ObjectIdentifier):
//			os_log(.debug, log: type(of: self).subsystem, "%@ Manual releasing will be required", String(describing: id))
//		case.some:
//			throw Error.resourceConflict
//		case.none:
//			guard case.some(let source) = source.withLock(\.self) else {
//				os_log(.debug, log: type(of: self).subsystem, "no longer update", String(describing: id))
//				return
//			}
//			guard case.none = instance.updateValue(id, forKey: .init(interval: interval, capacity: capacity, identity: id)) else {
//				throw Error.invalidContext
//			}
//			let status = Mutex<CMTimeRange>(.invalid)
//			let buffer = try target(interval: interval, capacity: capacity, instance: &instance) as Buffer
//			let update = try source(interval: interval, capacity: capacity, instance: &instance)
//			let kernel = { moment, length in
//				status.withLock {
//					let status = CMTimeRange(start: moment, duration: CMTimeMultiply(interval, multiplier: .init(length)))
//					if !status.containsTimeRange($0) {
//						buffer.copy(cursor: moment.samples(for: interval), length: length) {
//							update(moment, length, $0, $1)
//						}
//						$0 = status
//					}
//				}
//			} as Endpoint
//			guard case.some(id as ObjectIdentifier) = instance.updateValue(kernel, forKey: .init(interval: interval, capacity: capacity, identity: id)) else {
//				throw Error.invalidContext
//			}
//		}
//	}
//}
//extension Buffer.Lazy: Buffer.Effect {
//	@inlinable
//	var input: Optional<any Stream> {
//		get {
//			source.withLock(\.self)
//		}
//		set {
//			source.withLock {
//				$0 = newValue
//			}
//		}
//	}
//	@inlinable
//	var count: Int {
//		target.stream
//	}
//	@inlinable
//	var reference: some Buffer.`Protocol` {
//		target
//	}
//	@usableFromInline
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> Buffer {
//		try callAsFunction(interval: interval, capacity: capacity, instance: &instance) as Void
//		return try target(interval: interval, capacity: capacity, instance: &instance)
//	}
//}
//extension Buffer.Lazy: DSP.Stream {
//	@usableFromInline
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//		let buffer = try callAsFunction(interval: interval, capacity: capacity, instance: &instance) as Buffer
//		let update = switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
//		case.some(let update as Endpoint):
//			update
//		case.some:
//			throw Error.resourceConflict
//		case.none:
//			throw Error.invalidContext
//		}
//		return {
//			update($0, $1)
//			buffer.copy(cursor: $0.samples(for: interval), length: $1, target: $2, stride: $3)
//		}
//	}
//}
//public func buffer(_ count: Int, capacity: Duration = 0 as Samples) -> some Buffer.Effect & DSP.Stream {
//	Buffer.Lazy(upstream: count, capacity: capacity)
//}
//public func buffer(_ upstream: DSP.Stream, capacity: Duration = 0 as Samples) -> some Buffer.Effect & DSP.Stream {
//	let x = Buffer.Lazy(upstream: upstream.count, capacity: capacity)
//	x.input = upstream
//	return x
//}
