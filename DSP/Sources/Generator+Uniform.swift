//
//  Generator+Uniform.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
@preconcurrency import protocol Combine.Publisher
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import func NSP.uniform_rng
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
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch count {
		case ...0:
			throw Error.invalidChannel
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
				uniform_rng($2, $3,
							&l, 0, &h, 0,
							1, $1)
			}
		default:
			let adjust = Mutex<(lo: Array<Float64>, hi: Array<Float64>)>((.init(repeating: 0, count: count), .init(repeating: 0, count: count)))
			let cancel = range.sink { index, value in
				adjust.withLock {
					switch (index, index) {
					case ($0.lo.indices, $0.hi.indices):
						$0.0[index] = value.lowerBound
						$0.1[index] = value.upperBound
					default:
						assertionFailure("out of range")
					}
				}
			}
			return {
				let (lo, hi) = withExtendedLifetime(cancel) { adjust.withLock(\.self) }
				uniform_rng($2, $3,
							lo, 1, hi, 1,
							count, $1)
			}
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
