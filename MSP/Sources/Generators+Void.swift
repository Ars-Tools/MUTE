//
//  Generators+Void.swift
//  MUTE
//
//  Created by Kota on 5/11/R7.
//
import typealias Accelerate.vDSP
@usableFromInline
struct Nil {
	@usableFromInline
	struct He {
		@usableFromInline
		let count: Int
	}
}
extension Nil.He: Stream {
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		{
			for offset in stride(from: 0, to: count * $3, by: $3) {
				var result = UnsafeMutableBufferPointer(start: $2.advanced(by: offset), count: $1)
				vDSP.clear(&result)
			}
		}
	}
}
public func φ(count: Int = 1) -> some Stream {
	Nil.He(count: count)
}
