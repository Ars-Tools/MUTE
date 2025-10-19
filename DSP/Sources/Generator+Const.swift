//
//  Generator+Const.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
import typealias Accelerate.vDSP
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
@preconcurrency import Combine
@usableFromInline
enum Const {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline let signal: Signal
		@usableFromInline let count: Int
	}
}
extension Const.Kr: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch count {
		case ..<1:
			throw Error.invalidChannel
		case 1:
			let factor = Atomic<Float64>(0)
			let cancel = signal.sink {
				switch $0 {
				case 0:
					factor.store($1, ordering: .releasing)
				default:
					assertionFailure()
				}
			}
			return { moment, length, result, ignore in
				let source = withExtendedLifetime(cancel) { factor.load(ordering: .acquiring) }
				var result = UnsafeMutableBufferPointer(start: result, count: length)
				vDSP.fill(&result, with: source)
			}
		default:
			let factor = Mutex<Array<Float64>>(.init(repeating: 0, count: count))
			let cancel = signal.sink { index, value in
				factor.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return {
				let source = withExtendedLifetime(cancel) { factor.withLock(\.self) }
				for (factor, var target) in zip(source, fold(start: $2, count: $1, stream: count, period: $3)) {
					vDSP.fill(&target, with: factor)
				}
			}
		}
	}
}
public func const(_ signal: some Publisher<(Int, Float64), Never> & Sendable, count: Int) -> some Stream {
	Const.Kr(signal: signal, count: count)
}
public func const(_ signal: some Publisher<Float64, Never>) -> some Stream {
	const(signal.map{(0, $0)}, count: 1)
}
//public func const(_ stream: some AsyncSequence<(Int, Float64), Never> & Sendable, count: Int) -> some Stream {
//	const(stream.publisher, count: count)
//}
//public func const(_ stream: some AsyncSequence<Float64, Never> & Sendable) -> some Stream {
//	const(stream.publisher)
//}
public func const(_ array: some Sequence<Float64>, count: Int) -> some Stream {
	const(array.prefix(count: count), count: count)
}
public func const(_ array: some Collection<Float64>) -> some Stream {
	const(array, count: array.count)
}
@_disfavoredOverload
public func const(_ array: Float64...) -> some Stream {
	const(array)
}
