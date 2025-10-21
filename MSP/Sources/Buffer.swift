//
//  Buffer.swift
//  MUTE
//
//  Created by Kota on 5/11/R7.
//
import typealias Accelerate.vDSP
import func NSP.periodic_lookup_with_static
public enum Buffer {
	public protocol Instance: Stream {
		typealias Ground = @Sendable (CMTime, Int) -> Array<Float64>
		var count: Int { get }
		func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> (Object, Ground)
	}
}
extension Buffer.Instance {
	public func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch try callAsFunction(interval: interval, capacity: capacity, resource: &resource) as (Buffer.Object, Ground) {
		case (let object, let ground) where object.period < capacity:
			{ moment, length, target, stride in
				let lower = UInt(moment.samples(for: interval))
				let upper = lower + UInt(ground(moment, length).count)
				let limit = UInt(object.period)
				let slice = (lower..<upper).map { $0 % limit }
				object.withUnsafePointer {
					for offset in 0..<object.stream {
						var result = UnsafeMutableBufferPointer(start: target.advanced(by: offset * stride), count: length)
						vDSP.gather(UnsafeBufferPointer(start: $0.advanced(by: offset * object.period), count: object.period), indices: slice, result: &result)
					}
				}
			}
		case (let object, let ground):
			{
				object.copy(cursor: $0.samples(for: interval),
							length: ground($0, $1).count,
							target: $2,
							stride: $3)
			}
		}
	}
}
