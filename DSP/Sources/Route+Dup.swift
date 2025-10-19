//
//  Route+Dup.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@usableFromInline
struct Dup {
	@usableFromInline
	struct Ne {
		@usableFromInline let source: Stream
		@usableFromInline let`repeat`: Int
	}
}
extension Dup.Ne: Stream {
	@inlinable
	var count: Int {
		source.count * `repeat`
	}
	@inlinable
	var dependencies: Array<Stream> {
		.init(arrayLiteral: source)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let number = source.count
		return {
			kernel($0, $1, $2, $3)
			for to in stride(from: $3, to: `repeat` * number * $3, by: number * $3).lazy.map($2.advanced(by:)) {
				copy(x: $2, ldx: $3,
					 y: to, ldy: $3,
					 rows: number, cols: $1)
			}
		}
	}
}
public func dup(_ source: Stream, count: Int) -> some Stream {
	Dup.Ne(source: source, repeat: count)
}
