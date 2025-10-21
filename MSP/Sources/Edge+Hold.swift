//
//  Edge+Hold.swift
//  MUTE
//
//  Created by Kota on 6/25/R7.
//
import typealias Synchronization.Mutex
import func Layout.broadcast
import func NSP.edge_hold
@usableFromInline
struct Hold {
	@usableFromInline
	struct Ar {
		@usableFromInline let signal: Stream
		@usableFromInline let source: Stream
	}
}
extension Hold.Ar: Stream {
	@inlinable
	var count: Int {
		broadcast(x: source.count, y: signal.count)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xc = source.count
		let yc = signal.count
		let xk = try source(interval: interval, capacity: capacity, resource: &resource)
		let yk = try signal(interval: interval, capacity: capacity, resource: &resource)
		switch broadcast(x: xc, y: yc) {
		case xc:
			let status = Mutex<Array<Float64>>(.init(repeating: .zero, count: xc))
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: yc * length) {
					guard let ym = $0.baseAddress else { return }
					xk(moment, length, result, stride)
					yk(moment, length, ym, length)
					status.withLock {
						edge_hold(result, stride,
								  ym, broadcast(target: xc, source: yc, stride: length),
								  result, stride,
								  &$0,
								  xc, length)
					}
				}
			}
		case yc:
			let status = Mutex<Array<Float64>>(.init(repeating: .zero, count: yc))
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length) {
					guard let xm = $0.baseAddress else { return }
					xk(moment, length, xm, length)
					yk(moment, length, result, stride)
					status.withLock {
						edge_hold(xm, broadcast(target: yc, source: xc, stride: length),
								  result, stride,
								  result, stride,
								  &$0,
								  yc, length)
					}
				}
			}
		case let zc:
			assertionFailure("supposed to be reached here")
			let status = Mutex<Array<Float64>>(.init(repeating: .zero, count: zc))
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( xc + yc ) * length) {
					guard let xm = $0.baseAddress else { return }
					let ym = xm.advanced(by: xc * length)
					xk(moment, length, xm, length)
					yk(moment, length, ym, length)
					status.withLock {
						edge_hold(xm, broadcast(target: zc, source: xc, stride: length),
								  ym, broadcast(target: zc, source: yc, stride: length),
								  result, stride,
								  &$0,
								  zc, length)
					}
				}
			}
		}
	}
}
public func edge(in signal: Stream, hold source: Stream) -> some Stream {
	Hold.Ar(signal: signal, source: source)
}
