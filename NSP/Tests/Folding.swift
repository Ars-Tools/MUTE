//
//  Folding.swift
//  MUTE
//
//  Created by Kota on 11/22/R6.
//
import Testing
import Accelerate
import NSP
@Test
func folding() {
	let x = Array<Float64>(unsafeUninitializedCapacity: 512) {
		vDSP.formRamp(withInitialValue: 0, increment: 1/256.0, result: &$0)
		vForce.sinPi($0, result: &$0)
		$1 = $0.count
	}
	var a = 0.3
	let y = Array<Float64>(unsafeUninitializedCapacity: x.count) {
		folding_inf(x, $0.baseAddress.unsafelyUnwrapped,
					&a, 0,
					$0.count)
		$1 = $0.count
	}
	print(y)
}
