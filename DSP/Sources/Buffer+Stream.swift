//
//  Buffer+Stream.swift
//  MUTE
//
//  Created by Kota on 7/15/R7.
//
import typealias Synchronization.Mutex
import typealias CoreMedia.CMTimeRange
import func CoreMedia.CMTimeMultiply
import os.log
extension Buffer {
	public protocol Stream: DSP.Stream, Reference {}
	@usableFromInline
	final class Lazy: Sendable, Identifiable {
		@usableFromInline let source: DSP.Stream
		@usableFromInline let origin: Private
		@inlinable
		init(upstream count: DSP.Stream, capacity: Duration) {
			source = count
			origin = .init(count: source.count, capacity: capacity)
			origin.retain()
		}
		deinit {
			origin.release()
		}
	}
}
extension Buffer.Lazy: Buffer.`Protocol` {
	@inlinable
	var count: Int {
		origin.count
	}
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
		switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
		case.some(let kernel as @Sendable (CMTime, Int) -> Buffer):
			return kernel
		case.some:
			throw Error.resourceConflict
		case.none:
			let status = Mutex<CMTimeRange>(.invalid)
			let buffer = try origin(interval: interval, capacity: capacity, instance: &instance) as Buffer
			let source = try source(interval: interval, capacity: capacity, instance: &instance)
			let kernel = {
                let moment = CMTimeRange(start: $0, duration: CMTimeMultiply(interval, multiplier: .init($1)))
                return status.withLock {
                    if moment.intersection($0).isEmpty {
                        buffer.copy(cursor: moment.start.samples(for: interval), length: moment.duration.samples(for: interval)) {
                            source(moment.start, moment.duration.samples(for: interval), $0, $1)
                        }
                        $0 = moment
                    }
                    return buffer
                }
			} as @Sendable (CMTime, Int) -> Buffer
			guard case.none = instance.updateValue(kernel, forKey: .init(interval: interval, capacity: capacity, identity: id)) else {
				throw Error.invalidContext
			}
			return kernel
		}
	}
}
extension Buffer.Lazy: Buffer.Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try callAsFunction(interval: interval, capacity: capacity, instance: &instance) as @Sendable (CMTime, Int) -> Buffer
		return {
			kernel($0, $1).copy(cursor: $0.samples(for: interval), length: $1, target: $2, stride: $3)
		}
	}
}
extension Buffer.Lazy: Buffer.Reference {
	@inlinable
	var target: some Buffer.`Protocol` {
		self
	}
}
public func buffer(_ upstream: DSP.Stream, capacity: Duration = 0 as Samples) -> some Buffer.Stream {
	Buffer.Lazy(upstream: upstream, capacity: capacity)
}
//extension Buffer.Lazy: DSP.Stream {
//	@inlinable
//	var count: Int {
//		source.count
//	}
//	@usableFromInline
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//		switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
//		case.some(let kernel as @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void):
//			return kernel
//		case.some:
//			throw Error.resourceConflict
//		case.none:
//			let status = Mutex<CMTimeRange>(.invalid)
//						let buffer = try target(interval: interval, capacity: capacity, instance: &instance) as Buffer
//						let source = try source(interval: interval, capacity: capacity, instance: &instance)
//						let kernel = { moment, length in
//							status.withLock {
//								let status = CMTimeRange(start: moment, duration: CMTimeMultiply(interval, multiplier: .init(length)))
//								if !status.containsTimeRange($0) {
//									buffer.copy(cursor: moment.samples(for: interval), length: length) {
//										source(moment, length, $0, $1)
//									}
//									$0 = status
//								}
//							}
//						} as Endpoint
//			guard case.none = instance.updateValue(kernel, forKey: .init(interval: interval, capacity: capacity, identity: id)) else {
//				throw Error.invalidContext
//			}
//			ret
//		}
//	}
//}
//extension Buffer.Eager: DSP.Effect {
//	private static let subsystem = OSLog(subsystem: #file, category: .pointsOfInterest)
//	@usableFromInline
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws {
//		switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
//		case.some(is Endpoint):
//			break
//		case.some(id as ObjectIdentifier):
//			os_log(.info, log: type(of: self).subsystem, "%@ Manual releasing will be required", String(describing: id))
//		case.some:
//			throw Error.resourceConflict
//		case.none:
//			let status = Mutex<CMTimeRange>(.invalid)
//			let buffer = try target(interval: interval, capacity: capacity, instance: &instance) as Buffer
//			let source = try source(interval: interval, capacity: capacity, instance: &instance)
//			let kernel = { moment, length in
//				status.withLock {
//					let status = CMTimeRange(start: moment, duration: CMTimeMultiply(interval, multiplier: .init(length)))
//					if !status.containsTimeRange($0) {
//						buffer.copy(cursor: moment.samples(for: interval), length: length) {
//							source(moment, length, $0, $1)
//						}
//						$0 = status
//					}
//				}
//			} as Endpoint
//			guard case.none = instance.updateValue(kernel, forKey: .init(interval: interval, capacity: capacity, identity: id)) else {
//				throw Error.invalidContext
//			}
//		}
//	}
//}
//extension Buffer.Eager: Buffer.Stream {
//	@inlinable
//	var count: Int {
//		target.stream
//	}
//	@inlinable
//	var reference: some Buffer.`Protocol` {
//		self
//	}
//	@usableFromInline
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> Buffer {
//		try target(interval: interval, capacity: capacity, instance: &instance)
//	}
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
////public func buffer(_ source: Stream, capacity: Duration = 0 as Samples) -> some Buffer.Stream & Effect {
////	Buffer.Eager(upstream: source, capacity: capacity)
////}
