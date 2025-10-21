//
//  Buffer+Lookup.swift
//  MUTE
//
//  Created by Kota on 7/15/R7.
//
import func Layout.broadcast
import func Layout.zip
import func NSP.periodic_lookup_with_static
import typealias Accelerate.vDSP
extension Buffer {
	public protocol Reference {
		associatedtype Target: Protocol
		@inlinable
		var target: Target { get }
	}
	@usableFromInline
	struct Elapse<Target: Protocol> {
		@usableFromInline let target: Target
		@usableFromInline let second: DSP.Stream
	}
}
extension Buffer: Buffer.Reference {
    public var target: some `Protocol` {
        self
    }
}
extension Buffer.Elapse: DSP.Stream {
	@inlinable
	var count: Int {
		broadcast(x: target.count, y: second.count)
	}
	@inlinable@_transparent
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let source = try target(interval: interval, capacity: capacity, instance: &instance)
		let kernel = try second(interval: interval, capacity: capacity, instance: &instance)
		let factor = Float64(interval.timescale) / Float64(interval.value)
		let xc = target.count
		let yc = second.count
		let zc = broadcast(x: xc, y: yc)
		return {
			let buffer = source($0, $1)
			let xp = buffer.period
			let xm = buffer.start
			let xs = broadcast(target: zc, source: xc, stride: xp)
			let ys = broadcast(target: zc, source: yc, stride: $3)
			kernel($0, $1, $2, $3)
			for var target in fold(start: $2, count: $1, stream: yc, period: $3) {
				vDSP.multiply(factor, target, result: &target)
			}
			for offset in (0..<zc).reversed() {
				periodic_lookup_with_static(xm.advanced(by: offset * xs),
											$2.advanced(by: offset * ys),
											$2.advanced(by: offset * $3),
											xp, $1)
			}
		}
	}
}
extension Buffer.Reference {
	public subscript(second: DSP.Stream) -> some DSP.Stream {
		Buffer.Elapse(target: target, second: second)
	}
}
