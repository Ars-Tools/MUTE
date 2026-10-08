//
//  Utils.swift
//  MUTE
//
//  Created by Kota on 8/31/R7.
//
import Testing
import Numerics
import DSP
import ESP
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
@testable import FSP
@Suite
struct UtilTestCases {
//	@Test
//	func ls() {
//		let x = solve(m: 5, n: 4, A: [
//			1, 0, 2, 0, 0 + Complex128(real: 0, imag: 1),
//			0, 1, 0, 1, 1,
//			3, 0, 1, 0, 0,
//			0, 0, 0, 1, 3,
//		], ldA: 5, b: [1, 2, 3, 4, 5])
//		print(x)
//	}
	@Test
	func fitKernel() {
//		let response = repeatElement(0.8 ... 1.25, count: 256).map(Float64.random(in:))
		let response = Array<Float64>(unsafeUninitializedCapacity: 256) {
			vDSP.formRamp(withInitialValue: -128, increment: 1, result: &$0)
			vDSP.divide($0, 128, result: &$0)
			vForce.cosPi($0, result: &$0)
//			vDSP.formRamp(withInitialValue: -128, increment: 1, result: &$0)
//			vDSP.divide($0, 128, result: &$0)
//			vDSP.square($0, result: &$0)
			vDSP.add(multiplication: ($0, 0.40), 0.5, result: &$0)
			$1 = $0.count
		}
		print("response=", response)
//		print("mp=", exp(hilbert(freq: vForce.log(response))))
		
	}
}
