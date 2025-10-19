//
//  Generator+Gauss.swift
//  MUTE
//
//  Created by Kota on 8/18/R7.
//
@preconcurrency import protocol Combine.Publisher
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import func NSP.gauss_rng
@usableFromInline
enum Gauss {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, SIMD2<Float64>), Never> & Sendable> {
		@usableFromInline let param: Signal
		@usableFromInline let count: Int
	}
}
extension Gauss.Kr: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch count {
		case ...0:
			throw Error.invalidChannel
		case 1:
			let μ = Atomic<Float64>(0)
			let σ = Atomic<Float64>(0)
			let cancel = param.sink {
				switch $0 {
				case 0:
					μ.store($1.x, ordering: .releasing)
					σ.store($1.y, ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return {
				var (μ, σ) = withExtendedLifetime(cancel) { (μ.load(ordering: .acquiring), σ.load(ordering: .acquiring)) }
				gauss_rng($2, $3,
						  &μ, 0, &σ, 0,
						  1, $1)
			}
		default:
			let adjust = Mutex<(μ: Array<Float64>, σ: Array<Float64>)>((.init(repeating: 0, count: count), .init(repeating: 0, count: count)))
			let cancel = param.sink { index, value in
				adjust.withLock {
					switch (index, index) {
					case ($0.μ.indices, $0.σ.indices):
						$0.0[index] = value.x
						$0.1[index] = value.y
					default:
						assertionFailure("out of range")
					}
				}
			}
			return {
				let (μ, σ) = withExtendedLifetime(cancel) { adjust.withLock(\.self) }
				gauss_rng($2, $3,
						  μ, 1, σ, 1,
						  count, $1)
			}
		}
	}
}
//public func uniform(in range: some Publisher<(Int, ClosedRange<Float64>), Never> & Sendable, count: Int) -> some Stream {
//	Uniform.Kr(range: range, count: count)
//}
//public func uniform(in range: some Publisher<ClosedRange<Float64>, Never> & Sendable) -> some Stream {
//	uniform(in: range.map{(0, $0)}, count: 1)
//}
//public func uniform(in range: some AsyncSequence<(Int, ClosedRange<Float64>), Never> & Sendable, count: Int) -> some Stream {
//	uniform(in: range.publisher, count: count)
//}
//public func uniform(in range: some AsyncSequence<ClosedRange<Float64>, Never> & Sendable) -> some Stream {
//	uniform(in: range.publisher)
//}
//public func uniform(in range: some Collection<ClosedRange<Float64>>) -> some Stream {
//	uniform(in: range.map{(0, $0)}.publisher, count: 1)
//}
//@_disfavoredOverload
//public func uniform(in range: ClosedRange<Float64>...) -> some Stream {
//	uniform(in: range)
//}
