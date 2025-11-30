//
//  Edge+Rise.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Combine.Subscriber
@preconcurrency import typealias Combine.PassthroughSubject
@preconcurrency import protocol Dispatch.DispatchSourceUserDataReplace
@preconcurrency import typealias Dispatch.DispatchSource
@preconcurrency import typealias Dispatch.dispatch_source_t
import typealias Synchronization.Mutex
import func CoreMedia.CMTimeMultiply
import func NSP.edge_rise
extension Edge {
	@usableFromInline
	enum Rise {
		@usableFromInline
		struct Xe {
			@usableFromInline let signal: Stream
			@usableFromInline let notify: PassthroughSubject<CMTime, Never>
		}
	}
}
extension Edge.Rise.Xe: Stream {
	@inlinable
	var count: Int {
		signal.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let stream = signal.count
		let kernel = try signal(interval: interval, capacity: capacity, instance: &instance)
		let status = Mutex<Array<Bool>>(.init(repeating: false, count: stream))
		let source = DispatchSource.makeUserDataReplaceSource()
		source.setEventHandler { [unowned source] in
			notify.send(CMTimeMultiply(interval, multiplier: .init(source.data)))
		}
		source.resume()
		return { moment, length, result, stride in
			kernel(moment, length, result, stride)
			status.withLock {
				edge_rise(result, stride,
						  result, stride,
						  &$0,
						  unsafeDowncast(source, to: dispatch_source_t.self), moment.samples(for: interval),
						  stream, length)
			}
		}
	}
}
extension Edge.Rise.Xe: Effect {
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws {
		guard case.none = instance[.init(interval: interval, capacity: capacity, identity: .init(notify))] else { return }
		let stream = count
		let kernel = try callAsFunction(interval: interval, capacity: capacity, instance: &instance) as @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void
		guard case.none = instance.updateValue({ moment, length in
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: stream * length) {
				guard let memory = $0.baseAddress else { return }
				kernel(moment, length, memory, length)
			}
		} as Commit.Element, forKey: .init(interval: interval, capacity: capacity, identity: .init(notify))) else {
			throw Error.invalidContext
		}
	}
}
extension Edge.Rise.Xe: Publisher {
	@usableFromInline typealias Output = CMTime
	@usableFromInline typealias Failure = Never
	@inlinable
	func receive(subscriber: some Subscriber<Output, Failure>) {
		notify.receive(subscriber: subscriber)
	}
}
public func edge(rise source: Stream) -> some Stream & Effect & Publisher<CMTime, Never> {
	Edge.Rise.Xe(signal: source, notify: .init())
}
