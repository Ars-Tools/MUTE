//
//  Route+Dup.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@usableFromInline
enum Dup {
    @usableFromInline
    enum Per: Sendable {
        case channel
        case cluster
        static let`default`: Self = .cluster
    }
	@usableFromInline
	struct Ne {
		@usableFromInline let source: Stream
		@usableFromInline let`repeat`: Int
        @usableFromInline let layout: Per = .default
	}
}
extension Dup.Ne: Stream {
	@inlinable
	var count: Int {
		source.count * `repeat`
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let number = source.count
        return switch layout {
        case.cluster:
            {
                /*
                 [0 ch]
                 [1 ch]
                 [2 ch]
                 [3 ch]
                 [0 ch]
                 [1 ch]
                 [2 ch]
                 [3 ch]
                 */
                kernel($0, $1, $2, $3)
                for to in stride(from: $3 * number, to: $3 * number * `repeat`, by: $3 * number).lazy.map($2.advanced(by:)) {
                    copy(x: $2, ldx: $3,
                         y: to, ldy: $3,
                         rows: number, cols: $1)
                }
            }
        case.channel:
            {
                /*
                 [0 ch]
                 [0 ch]
                 [0 ch]
                 [0 ch]
                 [1 ch]
                 [1 ch]
                 [1 ch]
                 [1 ch]
                 [2 ch]
                 [2 ch]
                 [2 ch]
                 [2 ch]
                 */
                kernel($0, $1, $2, $3 * `repeat`)
                for to in stride(from: $3, to: $3 * `repeat`, by: $3)
                    .lazy.map($2.advanced(by:)) {
                    copy(x: $2, ldx: $3 * `repeat`,
                         y: to, ldy: $3 * `repeat`,
                         rows: number, cols: $1)
                }
            }
        }
	}
}
public func `repeat`(_ source: Stream, count: Int) -> some Stream {
	Dup.Ne(source: source, repeat: count)
}
public func dup(_ source: Stream, count: Int) -> some Stream {
    Dup.Ne(source: source, repeat: count)
}
