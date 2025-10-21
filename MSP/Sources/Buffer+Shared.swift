//
//  Buffer+Allocator.swift
//  MUTE
//
//  Created by Kota on 5/22/R7.
//
import typealias Accelerate.vDSP
import typealias Synchronization.Mutex
import typealias Synchronization.Atomic
import func Layout.broadcast
extension Buffer {
	public protocol SharedInstance: Instance {
		var target: He { get }
	}
	public protocol MutableSharedInstance: SharedInstance {
		var target: He { get nonmutating set }
	}
	public final class He {
		public let count: Int
		@usableFromInline let extra: Duration
		@inlinable
		init(upstream: Int, capacity: Duration) {
			count = upstream
			extra = capacity
		}
	}
	@usableFromInline
	final class Ne {
		@usableFromInline let count: Int
		@usableFromInline let refer: Mutex<He>
		@inlinable
		init(upstream: Int, capacity: Duration) {
			count = upstream
			refer = .init(.init(upstream: count, capacity: capacity))
		}
	}
	@usableFromInline
	final class Ar {
		@usableFromInline let source: Stream
		@usableFromInline let target: He
		init(upstream: Stream, capacity: Duration) {
			source = upstream
			target = .init(upstream: source.count, capacity: capacity)
		}
	}
}
extension Buffer.He: Identifiable & Sendable {}
extension Buffer.He: Buffer.SharedInstance {
	@usableFromInline
	internal func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> Buffer.Object {
		let stream = count
		let period = extra.samples(for: interval) + capacity
		switch resource[.init(interval: interval, capacity: capacity, instance: id)] {
		case.some(let object as Buffer.Object):
			return object
		case.some:
			throw Error.alreadyReserved
		case.none:
			let object = Buffer.Object(stream: stream, period: period)
			defer {
				resource.updateValue(object, forKey: .init(interval: interval, capacity: capacity, instance: id))
			}
			return object
		}
	}
	public func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> (Buffer.Object, Ground) {
		try (callAsFunction(interval: interval, capacity: capacity, resource: &resource), {
			vDSP.ramp(withInitialValue: .init($0.samples(for: interval)), increment: 1, count: $1)
		})
	}
	public var target: Buffer.He {
		self
	}
}
extension Buffer.Ne: Identifiable & Sendable {}
extension Buffer.Ne: Buffer.MutableSharedInstance {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> (Buffer.Object, Ground) {
		try refer.withLock(\.self)(interval: interval, capacity: capacity, resource: &resource)
	}
	@inlinable
	var target: Buffer.He {
		get {
			refer.withLock(\.self)
		}
		set {
			refer.withLock {
				$0 = newValue
			}
		}
	}
}
extension Buffer.Ar: Identifiable & Sendable {}
extension Buffer.Ar: Buffer.SharedInstance {
	@usableFromInline
	var count: Int {
		broadcast(x: source.count, y: target.count)
	}
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> (Buffer.Object, Ground) {
		let object = try target(interval: interval, capacity: capacity, resource: &resource) as Buffer.Object
		switch resource[.init(interval: interval, capacity: capacity, instance: id)] {
		case.some(let ground as Ground):
			return (object, ground)
		case.some:
			throw Error.alreadyReserved
		case.none:
			let source = try source(interval: interval, capacity: capacity, resource: &resource)
			let latest = Atomic<Int>(.min)
			let ground = { moment, length in
				.init(unsafeUninitializedCapacity: object.stream * length) {
					guard let memory = $0.baseAddress else { return }
					switch latest.max(moment.samples(for: interval), ordering: .acquiringAndReleasing) {
					case (let old, let new) where old < new:
						source(moment, length, memory, length)
						object.copy(cursor: new, length: length, source: memory, stride: length)
						vDSP.formRamp(withInitialValue: .init(new), increment: 1, result: &$0[..<length])
					case (let old, let new):
						assert(old == new)
						vDSP.formRamp(withInitialValue: .init(new), increment: 1, result: &$0[..<length])
					}
					$1 = length
				}
			} as Ground
			defer {
				resource.updateValue(ground, forKey: .init(interval: interval, capacity: capacity, instance: id))
			}
			return (object, ground)
		}
	}
}
public func buffer(count upstream: Int) -> some Buffer.MutableSharedInstance {
	Buffer.Ne(upstream: upstream, capacity: 0)
}
public func buffer(_ upstream: Stream, capacity: Duration = 0) -> some Buffer.SharedInstance {
	Buffer.Ar(upstream: upstream, capacity: capacity)
}
