//
//  Lattice.swift
//  MUTE
//
//  Created by Kota on 8/16/R7.
//
import typealias Accelerate.vDSP
import Accelerate.vecLib
import Testing
import simd
import NSP
@testable import FSP
@Suite
struct Lattice {
	func gen(count: Int, r: Float64, θ: Float64) -> Array<Float64> {
		.init(unsafeUninitializedCapacity: count) {
			let c = __cospi(θ)
			let a = [1, -2.0 * r * c, r * r]
			for n in 2..<$0.count {
				$0[n] = Float64.random(in: -1 ... 1) - a[1] * $0[n-1] - a[2] * $0[n-2]
			}
			$1 = $0.count
		}
	}
	@Test
	func lpcCoef() {
		let r = 0.99
		let θ = Float64.random(in: 0.2 ... 0.8)
		let y = gen(count: 1024, r: r, θ: θ)
		let a = [1, -2.0 * r * __cospi(θ), r * r]
		let á = ar(signal: y, order: 2)
		#expect(vDSP.rootMeanSquare(vDSP.subtract(á, a).dropFirst()) < 1e-1)
	}
	@Test
	func parcorConv() {
		let r = 0.99
		let θ = 0.25 * .pi
		let y = gen(count: 2048, r: r, θ: θ)
		let a = [1, -2.0 * r * __cospi(θ), r * r]
		let rls = lsl_create(2)
		defer { lsl_destroy(rls) }
		lsl_lambda(rls, 0.99)
		let P = Array<Float64>(unsafeUninitializedCapacity: y.count * 3) {
			$0.initialize(repeating: .zero)
			lsl_p(rls, y, $0.baseAddress.unsafelyUnwrapped, y.count, y.count)
			$1 = $0.count
		}
		let c = stride(from: 0, to: 2 * y.count, by: y.count).map {
			P[$0 + y.count - 1]
		}
		print(a, c)
		print(ar(signal: y, order: 2), "<- Levinson-Durbin")
		print(parcor(ar: ar(signal: y, order: 2)), "<- Analytical PARCOR")
		
		print(ar(parcor: parcor(ar: ar(signal: y, order: 2))), "<- Analytical AR")
		print(ar(parcor: c))
		print(parcor(ar: ar(parcor: c)))
	}
}
