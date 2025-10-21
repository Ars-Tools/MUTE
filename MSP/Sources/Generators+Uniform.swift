//
//  Generators+Uniform.swift
//  MUTE
//
//  Created by Kota on 5/15/R7.
//
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
@preconcurrency import Combine
import func NSP.uniform_f64
@usableFromInline
enum Uniform {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, ClosedRange<Float64>), Never> & Sendable> {
		@usableFromInline let range: Signal
		@usableFromInline let count: Int
	}
}
extension Uniform.Kr: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch count {
		case 1:
			let lo = Atomic<Float64>(0)
			let hi = Atomic<Float64>(0)
			let cancel = range.sink {
				switch $0 {
				case 0:
					lo.store($1.lowerBound, ordering: .releasing)
					hi.store($1.upperBound, ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return {
				var (l, h) = withExtendedLifetime(cancel) { (lo.load(ordering: .acquiring), hi.load(ordering: .acquiring)) }
				uniform_f64($2, $3,
							&l, 0, &h, 0,
							1, $1)
			}
		case 2...:
			let adjust = Mutex<(lo: Array<Float64>, hi: Array<Float64>)>((.init(repeating: 0, count: count), .init(repeating: 0, count: count)))
			let cancel = range.sink { index, value in
				adjust.withLock {
					if $0.lo.indices ~= index, $0.hi.indices ~= index {
						$0.0[index] = value.lowerBound
						$0.1[index] = value.upperBound
					} else {
						assertionFailure("out of range")
					}
				}
			}
			return {
				let (lo, hi) = withExtendedLifetime(cancel) { adjust.withLock(\.self) }
				uniform_f64($2, $3,
							lo, 1, hi, 1,
							count, $1)
			}
		default:
			throw Error.invalidChannel
		}
	}
}
public func uniform(in range: some Publisher<(Int, ClosedRange<Float64>), Never> & Sendable, count: Int) -> some Stream {
	Uniform.Kr(range: range, count: count)
}
public func uniform(in range: some Publisher<ClosedRange<Float64>, Never> & Sendable) -> some Stream {
	uniform(in: range.map{(0, $0)}, count: 1)
}
public func uniform(in range: some AsyncSequence<(Int, ClosedRange<Float64>), Never> & Sendable, count: Int) -> some Stream {
	uniform(in: range.publisher, count: count)
}
public func uniform(in range: some AsyncSequence<ClosedRange<Float64>, Never> & Sendable) -> some Stream {
	uniform(in: range.publisher)
}
public func uniform(in range: some Collection<ClosedRange<Float64>>) -> some Stream {
	uniform(in: range.map{(0, $0)}.publisher, count: 1)
}
@_disfavoredOverload
public func uniform(in range: ClosedRange<Float64>...) -> some Stream {
	uniform(in: range)
}
