//
//  Kernel.swift
//  MUTE
//
//  Created by Kota on 9/6/R7.
//
import Testing
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Numerics.Complex128
@testable import FSP
@Suite
struct KernelTestCases {
	@Test
	func kernel() {
//		let (b, a) = fit(frequency: vDSP.ramp(in: 0...1, count: 9),
//						 response: minimumPhase(mag: [1, 0.25, 0.5, 0.25, 0.125, 0.25, 0.5, 0.125, 0.25]), with: (4, 4))
		
		let response = Array<Float64>(unsafeUninitializedCapacity: 64) {
			vDSP.formRamp(withInitialValue: -32, increment: 1, result: &$0)
			vDSP.divide($0, 8, result: &$0)
			vForce.cosPi($0, result: &$0)
//			vDSP.formRamp(withInitialValue: -128, increment: 1, result: &$0)
//			vDSP.divide($0, 128, result: &$0)
//			vDSP.square($0, result: &$0)
			vDSP.add(multiplication: ($0, 0.40), 0.5, result: &$0)
			$1 = $0.count
		}
		print("response=", response)
		print("mpx=", exp(hilbert(freq: vForce.log(response))))
		print("mpy=", minimum(mag: response))
		let (b, a) = fit(response: minimum(mag: response), with: (6, 6))
		print("b=", b)
		print("a=", a)
		
	}
}
