//
//  Generators+Phasor.swift
//  MUTE
//
//  Created by Kota on 5/9/R7.
//
import func simd.fma
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias Accelerate.vDSP
@preconcurrency import Combine
@usableFromInline
enum Phasor {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Frequency), Never> & Sendable> {
		@usableFromInline let freqs: Signal
		@usableFromInline let count: Int
	}
	@usableFromInline
	struct Ar {
		@usableFromInline let freqs: Stream
	}
}
extension Phasor.Kr: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch count {
		case ..<1:
			throw Error.invalidChannel
		case 1:
			let factor = Atomic<Float64>(.zero)
			let cancel = freqs.sink {
				switch $0 {
				case 0:
					factor.store($1.increment(for: interval), ordering: .releasing)
				default:
					assertionFailure("out of range")
				}
			}
			return { moment, length, target, stride in
				let source = withExtendedLifetime(cancel) { factor.load(ordering: .acquiring) }
				var result = UnsafeMutableBufferPointer(start: target, count: length)
				vDSP.formRamp(withInitialValue: .init(moment.samples(for: interval)), increment: 1, result: &result)
				vDSP.multiply(source, result, result: &result)
				vDSP.trunc(result, result: &result)
				vDSP.add(1, result, result: &result)
				vDSP.trunc(result, result: &result)
			}
		default:
			let factor = Mutex<Array<Float64>>(.init(repeating: .zero, count: count))
			let cancel = freqs.sink { index, value in
				factor.withLock {
					switch index {
					case $0.indices:
						$0[index] = value.increment(for: interval)
					default:
						assertionFailure("out of range")
					}
				}
			}
			return {
				let source = withExtendedLifetime(cancel) { factor.withLock(\.self) }
				var phasor = UnsafeMutableBufferPointer(start: $2, count: $1)
				vDSP.formRamp(withInitialValue: .init($0.samples(for: interval)), increment: 1, result: &phasor)
				for (offset, factor) in source.enumerated().reversed() {
					var result = UnsafeMutableBufferPointer(start: $2.advanced(by: offset * $3), count: $1)
					vDSP.multiply(factor, phasor, result: &result)
					vDSP.trunc(result, result: &result)
					vDSP.add(1, result, result: &result)
					vDSP.trunc(result, result: &result)
				}
			}
		}
	}
}
extension Phasor.Ar: Stream {
	@inlinable
	var count: Int {
		freqs.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try freqs(interval: interval, capacity: capacity, resource: &resource)
		let factor = interval.seconds
		switch freqs.count {
		case ..<1:
			throw Error.invalidChannel
		case 1:
			let latest = Atomic<Float64>(.zero)
			return { moment, length, target, stride in
				kernel(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: length) {
					var memory = $0
					var result = UnsafeMutableBufferPointer(start: target, count: length)
					vDSP.multiply(factor, result, result: &memory)
					let head = (memory.first ?? .zero).truncatingRemainder(dividingBy: 1)
					let tail = (memory.last ?? .zero).truncatingRemainder(dividingBy: 1)
					vDSP.integrate(memory, using: .trapezoidal, result: &result)
					vDSP.trunc(result, result: &result)
					vDSP.add(fma(0.5, head, latest.load(ordering: .acquiring)).advanced(by: 1), result, result: &result)
					vDSP.trunc(result, result: &result)
					latest.store(fma(0.5, tail, result.last ?? .zero), ordering: .releasing)
				}
			}
		case let stream: assert(2<=stream)
			let latest = Mutex<Array<Float64>>(.init(repeating: .zero, count: stream))
			return { moment, length, target, stride in
				kernel(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: length) {
					var memory = $0
					latest.withLock {
						for (offset, element) in $0.indices.enumerated() {
							var result = UnsafeMutableBufferPointer(start: target.advanced(by: offset * stride), count: length)
							vDSP.multiply(factor, result, result: &memory)
							let head = (memory.first ?? .zero).truncatingRemainder(dividingBy: 1).advanced(by: 1)
							let tail = (memory.last ?? .zero).truncatingRemainder(dividingBy: 1).advanced(by: 1)
							vDSP.integrate(memory, using: .trapezoidal, result: &result)
							vDSP.trunc(result, result: &result)
							vDSP.add(fma(0.5, head, $0[element]), result, result: &result)
							vDSP.trunc(result, result: &result)
							$0[element] = fma(0.5, tail, result.last ?? .zero)
						}
					}
				}
			}
		}
	}
}
public func phasor(freqs: some Publisher<(Int, Frequency), Never> & Sendable, count: Int) -> some Stream {
	Phasor.Kr(freqs: freqs, count: count)
}
public func phasor(freqs: some Publisher<Frequency, Never>) -> some Stream {
	phasor(freqs: freqs.map{(0, $0)}, count: 1)
}
public func phasor(freqs: some AsyncSequence<(Int, Frequency), Never> & Sendable, count: Int) -> some Stream {
	phasor(freqs: freqs.publisher, count: count)
}
public func phasor(freqs: some AsyncSequence<Frequency, Never> & Sendable) -> some Stream {
	phasor(freqs: freqs.publisher)
}
public func phasor(freqs: some Collection<Frequency>) -> some Stream {
	phasor(freqs: freqs.enumerated().publisher.map(\.self), count: freqs.count)
}
@_disfavoredOverload
public func phasor(freqs: Frequency...) -> some Stream {
	phasor(freqs: freqs)
}
public func phasor(freqs: Stream) -> some Stream {
	Phasor.Ar(freqs: freqs)
}
