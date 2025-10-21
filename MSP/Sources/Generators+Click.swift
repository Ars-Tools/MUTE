//
//  Generators+Click.swift
//  MUTE
//
//  Created by Kota on 6/4/R7.
//
import typealias Synchronization.Mutex
import typealias CoreMedia.CMTimeRange
import func CoreMedia.CMTimeMultiply
import func CoreMedia.CMTimeSubtract
import typealias Accelerate.vDSP
@preconcurrency import protocol Combine.Publisher
import CLK
@usableFromInline
enum Click {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, CMTime), Never> & Sendable> {
		@usableFromInline let trigger: Signal
		@usableFromInline let count: Int
	}
}
extension Click.Kr: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let latest = Mutex<Array<CMTime>>(.init(repeating: .invalid, count: count))
		let cancel = trigger.sink { index, value in
			latest.withLock {
				switch index {
				case $0.indices:
					$0[index] = value
				default:
					assertionFailure("out of range")
				}
			}
		}
		return { moment, length, target, stride in
			let period = CMTimeRange(start: moment, duration: CMTimeMultiply(interval, multiplier: .init(length)))
			withExtendedLifetime(cancel) {
				latest.withLock {
					for (offset, element) in $0.indices.enumerated() {
						var result = UnsafeMutableBufferPointer(start: target.advanced(by: offset * stride), count: length)
						vDSP.clear(&result)
						let cursor = switch $0[element] {
						case.invalid,.indefinite,.negativeInfinity,.positiveInfinity:
							.invalid
						case.zero:
							period.start
						case let cursor:
							period.start.quantise(by: cursor, rounding: .roundTowardPositiveInfinity)
						} as CMTime
						switch cursor {
						case period:
							result[CMTimeSubtract(cursor, period.start).samples(for: interval)] = 1
							$0[offset] = .invalid
						default:
							break
						}
					}
				}
			}
		}
	}
}
public func click(trigger signal: some Publisher<(Int, CMTime), Never> & Sendable, count: Int) -> some Stream {
	Click.Kr(trigger: signal, count: count)
}
public func click(trigger signal: some Publisher<CMTime, Never>) -> some Stream {
	Click.Kr(trigger: signal.map{(0,$0)}, count: 1)
}
public func click(trigger signal: some Publisher<(), Never>) -> some Stream {
	Click.Kr(trigger: signal.map{(0,.zero)}, count: 1)
}
public func click(trigger signal: some AsyncSequence<(Int, CMTime), Never> & Sendable, count: Int) -> some Stream {
	click(trigger: signal.publisher, count: count)
}
public func click(trigger signal: some AsyncSequence<CMTime, Never> & Sendable) -> some Stream {
	click(trigger: signal.publisher)
}
public func click(trigger signal: some AsyncSequence<(), Never> & Sendable) -> some Stream {
	click(trigger: signal.publisher)
}
