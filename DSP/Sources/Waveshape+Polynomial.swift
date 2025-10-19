//
//  Waveshape+Polynomial.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
import struct Synchronization.Mutex
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
@usableFromInline
enum Polynomial {
	@usableFromInline
	struct Kr<Output: Sequence<Float64>, Signal: Publisher<(Int, Output), Never> & Sendable> {
		@usableFromInline let source: Stream
		@usableFromInline let signal: Signal
	}
}
extension Polynomial.Kr: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let weight = Mutex<Array<Array<Float64>>>(.init(repeating: .init(), count: source.count))
		let cancel = signal.sink { index, value in
			weight.withLock {
				switch index {
				case $0.indices:
					$0[index] = .init(value)
				default:
					assertionFailure("out of range")
				}
			}
		}
		return {
			kernel($0, $1, $2, $3)
			let factor = withExtendedLifetime(cancel) { weight.withLock(\.self) }
			for (offset, weight) in factor.enumerated() {
				var result = UnsafeMutableBufferPointer(start: $2.advanced(by: offset * $3), count: $1)
				vDSP.evaluatePolynomial(usingCoefficients: weight, withVariables: result, result: &result)
			}
		}
	}
}
public func polynomial(_ source: Stream, coefficients: some Publisher<(Int, some Sequence<Float64>), Never> & Sendable) -> some Stream {
	Polynomial.Kr(source: source, signal: coefficients)
}
public func polynomial(_ source: Stream, coefficients: some Publisher<some Sequence<Float64>, Never>) -> some Stream {
	polynomial(source, coefficients: coefficients.repeat(count: source.count))
}
public func polynomial(_ source: Stream, coefficients: some Sequence<some Sequence<Float64>>) -> some Stream {
	polynomial(source, coefficients: coefficients.prefix(count: source.count))
}
public func polynomial(_ source: Stream, coefficients: some Sequence<Float64>) -> some Stream {
	polynomial(source, coefficients: `repeat`(coefficients, count: source.count))
}
@_disfavoredOverload
public func polynomial(_ source: Stream, coefficients: Float64...) -> some Stream {
	polynomial(source, coefficients: `repeat`(coefficients, count: source.count))
}
// MARK: Harmonics (Chebyshev Polynomial)
public func harmonics(_ source: Stream, coefficients: some Publisher<(Int, some Sequence<Float64>), Never>) -> some Stream {
	let chebyshev = sequence(state: (Array<Float64>(arrayLiteral: 1), Array<Float64>(arrayLiteral: 1, 0))) { state in
		defer {
			state = (state.1, Array<Float64>(unsafeUninitializedCapacity: state.1.count + 1) {
				$0[state.1.count] = 0
				vDSP.multiply(2, state.1, result: &$0[..<state.1.count])
				vDSP.subtract($0[2...], state.0, result: &$0[2...])
				$1 = $0.count
			})
		}
		return state.0
	}
	return Polynomial.Kr(source: source, signal: coefficients.map {
		($0, zip(chebyshev, $1).reduce(into: Array<Float64>()) {
			$0.insert(0, at: 0)
			vDSP.add(multiplication: $1, $0, result: &$0)
		})
	})
}
public func harmonics(_ source: Stream, coefficients: some Publisher<some Sequence<Float64>, Never>) -> some Stream {
	harmonics(source, coefficients: coefficients.repeat(count: source.count))
}
public func harmonics(_ source: Stream, coefficients: some Sequence<some Sequence<Float64>>) -> some Stream {
	harmonics(source, coefficients: coefficients.prefix(count: source.count))
}
public func harmonics(_ source: Stream, coefficients: some Sequence<Float64>) -> some Stream {
	harmonics(source, coefficients: `repeat`(coefficients, count: source.count))
}
@_disfavoredOverload
public func harmonics(_ stream: Stream, coefficients: Float64...) -> some Stream {
	harmonics(stream, coefficients: coefficients)
}
