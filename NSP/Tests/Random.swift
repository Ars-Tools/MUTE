//
//  Random.swift
//  MUTE
//
//  Created by Kota on 8/17/R7.
//
import Accelerate
import Testing
@testable import NSP
@Suite
struct RNG {
	@Test
	func cauchy() {
		let r = Array<Float64>(unsafeUninitializedCapacity: 16) {
			var x = 0.0
			var g = 1.0
			cauchy_rng($0.baseAddress.unsafelyUnwrapped, $0.count,
					   &x, 0,
					   &g, 0,
					   1, $0.count)
			$1 = $0.count
		}
		print(r)
	}
	@Test
	func gauss() {
		let y = Array<Float64>(unsafeUninitializedCapacity: 65536) {
			var u = 1.0
			var s = 4.0
			gauss_rng($0.baseAddress.unsafelyUnwrapped, $0.count,
					  &u, 0,
					  &s, 0,
					  1, $0.count)
			$1 = $0.count
		}
		var u = 0.0
		var s = 0.0
		vDSP_normalizeD(y, 1, .none, 0, &u, &s, .init(y.count))
		print(u, s)
	}
}
