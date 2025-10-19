//
//  Biquad.swift
//  MUTE
//
//  Created by Kota on 8/26/R7.
//
import typealias Accelerate.vDSP
import Accelerate.vecLib
import Testing
import simd
import DSP
import CoreMedia
@testable import FSP
@Suite
struct BiquadTestCase {
	@Test
	func fitSOS() {
		let response = Array<Float64>(unsafeUninitializedCapacity: 256) {
			vDSP.formRamp(withInitialValue: -128, increment: 1, result: &$0)
			vDSP.divide($0, 32, result: &$0)
			vForce.cosPi($0, result: &$0)
//			vDSP.formRamp(withInitialValue: -32, increment: 1, result: &$0)
//			vDSP.divide($0, 32, result: &$0)
//			vDSP.square($0, result: &$0)
			vDSP.evaluatePolynomial(usingCoefficients: [3, 0.0, -0.01, 0.0, 0.2, 0, -0.03, 0, 0.12, 0, 0.12], withVariables: $0, result: &$0)
			$1 = $0.count
		}
		print(response)
		print(fit(response: minimum(mag: response), with: 24).map { ($0.x, $0.y, $0.z, $1.x, $1.y, $1.z) })
	}
}
