//
//  Prototype.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
import Testing
import DSP
import simd
@testable import FSP
@Suite
struct PrototypeTestCase {
	func to(scipy sos: Array<Float64>) -> Array<Array<Float64>> {
		stride(from: 0, to: sos.count, by: 5).map {
			let w = sos[$0..<$0+5]
			let b = w.prefix(3)
			let a = [1] + w.suffix(2)
			return b + a
		}
	}
	@Test
	func blt() {
		let p = legendre(count: 4)
		print(p)
		let r = roots(poly: p)
		print(r)
	}
	@Test
	func polynomial() {
		let c = [1, -3, -5, -3, 1] as Array<Float64>
		let p = roots(poly: c)
		print(p)
		let q = poly(roots: p)
		print(q)
	}
}
