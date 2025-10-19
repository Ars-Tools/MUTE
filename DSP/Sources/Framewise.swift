//
//  Framewise.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Accelerate.Quadrature
import typealias Numerics.Rational64
import func NSP.vvi0
import func NSP.i0
public enum Framewise {
	public enum Window: Sendable {
		case rectangular(Duration)
		case bartlett(Duration)
		case jonathan(Duration)
		case hanning(Duration)
		case hamming(Duration)
		case blackman(Duration)
		case kaiser(Duration, Float64)
		case gauss(Int, Float64)
		case sinc(Int, Float64)
		case raw(Array<Float64>)
	}
	public enum Stride: Sendable {
		case absolute(Duration)
		case relative(Rational64)
	}
}
extension Framewise.Window {
	@inlinable
	public func coefficients(for T₀: CMTime) -> Array<Float64> {
		switch self {
		case.rectangular(let duration):
			.init(repeating: 1, count: duration.samples(for: T₀))
		case.bartlett(let duration):
			.init(unsafeUninitializedCapacity: duration.samples(for: T₀)) {
				vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0[..<($0.count/2+1)])
				vDSP.formRamp(withInitialValue: .init(($0.count+1)/2-1), increment: -1, result: &$0[($0.count/2+1)...])
				vDSP.divide($0, .init($0.count/2), result: &$0)
				$1 = $0.count
			}
		case.jonathan(let duration):
			.init(unsafeUninitializedCapacity: duration.samples(for: T₀)) {
				vDSP.formWindow(usingSequence: .hanningDenormalized, result: &$0, isHalfWindow: false)
				vForce.sqrt($0, result: &$0)
				$1 = $0.count
			}
		case.hanning(let duration):
			vDSP.window(ofType: Float64.self, usingSequence: .hanningDenormalized, count: duration.samples(for: T₀), isHalfWindow: false)
		case.hamming(let duration):
			vDSP.window(ofType: Float64.self, usingSequence: .hamming, count: duration.samples(for: T₀), isHalfWindow: false)
		case.blackman(let duration):
			vDSP.window(ofType: Float64.self, usingSequence: .blackman, count: duration.samples(for: T₀), isHalfWindow: false)
		case.kaiser(let duration, let α):
			.init(unsafeUninitializedCapacity: duration.samples(for: T₀)) {
				guard let memory = $0.baseAddress else { return }
				vDSP.formRamp(withInitialValue: -1, increment: 2 / .init($0.count), result: &$0)
				vDSP.square($0, result: &$0)
				vDSP.add(multiplication: ($0, -1), 1, result: &$0)
				vForce.sqrt($0, result: &$0)
				vDSP.multiply(α * .pi, $0, result: &$0)
				vvi0(memory, memory, $0.count)
				vDSP.divide($0, i0(α * .pi), result: &$0)
				$1 = $0.count
			}
		case.gauss(let length, let factor):
			.init(unsafeUninitializedCapacity: length) {
				vDSP.formRamp(withInitialValue: .init(-length/2), increment: 1, result: &$0)
				vDSP.square($0, result: &$0)
				vDSP.multiply(-.pi * (factor * factor) / .init(length), $0, result: &$0)
				vForce.exp($0, result: &$0)
				vDSP.multiply(factor / .pi / .init(length).squareRoot(), $0, result: &$0)
				$1 = $0.count
			}
		case.sinc(let length, let factor):
			.init(unsafeUninitializedCapacity: 2 * length) {
				vDSP.formRamp(withInitialValue: .init(-length/2) * factor * .pi, increment: factor * .pi, result: &$0[..<length])
				vForce.sin($0[..<length], result: &$0[length...])
				vDSP.divide($0[length...], $0[..<length], result: &$0[..<length])
				$0[length/2] = 1
				$1 = length
			}
		case.raw(let coefficients):
			coefficients
		}
	}
}
