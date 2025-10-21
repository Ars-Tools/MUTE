//
//  Edge+Fall.swift
//  MUTE
//
//  Created by Kota on 6/25/R7.
//
@preconcurrency import Dispatch
import typealias Synchronization.Mutex
import func NSP.edge_fall
//@usableFromInline
//enum Fall {
//	@usableFromInline
//	struct Rn {
//		@usableFromInline let signal: Stream
//		@usableFromInline let notify: Optional<DispatchSourceUserDataAdd>
//	}
//}
//extension Fall.Rn: Stream {
//	@inlinable
//	var count: Int {
//		signal.count
//	}
//	@inlinable
//	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//		let stream = signal.count
//		let kernel = try signal(interval: interval, capacity: capacity, resource: &resource)
//		let status = Mutex<Array<Bool>>(.init(repeating: false, count: stream))
//		let notify = notify.map {
//			unsafeDowncast($0, to: dispatch_source_t.self)
//		}
//		return { moment, length, result, stride in
//			kernel(moment, length, result, stride)
//			status.withLock {
//				edge_fall(result, stride,
//						  result, stride,
//						  &$0,
//						  notify,
//						  stream, length)
//			}
//		}
//	}
//}
//public func edge(of source: Stream, fall target: Optional<DispatchSourceUserDataAdd>) -> some Stream {
//	Rise.Rn(signal: source, notify: target)
//}
