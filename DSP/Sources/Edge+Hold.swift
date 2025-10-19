//
//  Edge+Hold.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
import typealias Synchronization.Mutex
import func Layout.broadcast
import func NSP.edge_hold
import typealias Auxiliary.Autorelease
@usableFromInline
enum Edge {
	@usableFromInline
	enum Hold {
		@usableFromInline
		struct Ar {
			@usableFromInline let signal: Stream
			@usableFromInline let source: Stream
		}
	}
}
extension Edge.Hold.Ar: Stream {
	@inlinable
	var count: Int {
		broadcast(x: source.count, y: signal.count)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xc = source.count
		let yc = signal.count
		let xk = try source(interval: interval, capacity: capacity, instance: &instance)
		let yk = try signal(interval: interval, capacity: capacity, instance: &instance)
		switch broadcast(x: xc, y: yc) {
		case xc:
			let status = Autorelease.Memory(repeating: .zero as Float64, count: xc)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: yc * length) {
					guard let ym = $0.baseAddress else { return }
					xk(moment, length, result, stride)
					yk(moment, length, ym, length)
					edge_hold(result, stride,
							  ym, broadcast(target: xc, source: yc, stride: length),
							  result, stride,
							  status.start.assumingMemoryBound(to: Float64.self),
							  xc, length)
				}
			}
		case yc:
			let status = Autorelease.Memory(repeating: .zero as Float64, count: yc)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length) {
					guard let xm = $0.baseAddress else { return }
					xk(moment, length, xm, length)
					yk(moment, length, result, stride)
					edge_hold(xm, broadcast(target: yc, source: xc, stride: length),
							  result, stride,
							  result, stride,
							  status.start.assumingMemoryBound(to: Float64.self),
							  yc, length)
				}
			}
		case let zc:
			assertionFailure("supposed not to be reached here")
			let status = Autorelease.Memory(repeating: .zero as Float64, count: zc)
			return { moment, length, result, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( xc + yc ) * length) {
					guard let xm = $0.baseAddress else { return }
					let ym = xm.advanced(by: xc * length)
					xk(moment, length, xm, length)
					yk(moment, length, ym, length)
					edge_hold(xm, broadcast(target: zc, source: xc, stride: length),
							  ym, broadcast(target: zc, source: yc, stride: length),
							  result, stride,
							  status.start.assumingMemoryBound(to: Float64.self),
							  zc, length)
				}
			}
		}
	}
}
public func edge(gate signal: Stream, hold: Stream) -> some Stream {
	Edge.Hold.Ar(signal: signal, source: hold)
}
