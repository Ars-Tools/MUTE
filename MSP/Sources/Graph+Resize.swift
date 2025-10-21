//
//  Graph+Resize.swift
//  MUTE
//
//  Created by Kota on 6/25/R7.
//
import CLK
import typealias Synchronization.Mutex
@usableFromInline
enum Resize {
	@usableFromInline
	struct Ne {
		@usableFromInline let source: Stream
		@usableFromInline let resize: Duration
	}
}
extension Resize.Ne: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let number = source.count
		let period = resize.samples(for: interval)
		let kernel = try source(interval: interval, capacity: period, resource: &resource)
		let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: number * period))
		return { moment, length, result, stride in
			buffer.withLock {
				$0.withUnsafeMutablePointer {
					let remain = switch moment.times(of: interval, rounding: .some(.roundHalfAwayFromZero)).quotient % period {
					case let remain:
						period * remain.signum() - remain
					}
					copy(x: $0.advanced(by: period - remain), ldx: period,
						 y: result, ldy: stride,
						 rows: number, cols: min(length, remain))
					for offset in Swift.stride(from: remain, to: length, by: period) {
						assert(offset < length)
						kernel(CMTimeAdd(moment, CMTimeMultiply(interval, multiplier: .init(offset))), period, $0, period)
						copy(x: $0, ldx: period,
							 y: result.advanced(by: offset), ldy: stride,
							 rows: number, cols: min(length - offset, period))
					}
				}
			}
		}
	}
}
public func resize(_ source: Stream, resize: Duration) -> some Stream {
	Resize.Ne(source: source, resize: resize)
}
