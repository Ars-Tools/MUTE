//
//  Calculus.swift
//  MUTE
//
//  Created by Kota on 11/22/R6.
//
import Testing
import NSP
@Suite
struct Calculus {
	@Test
	func integration() {
		let z = Array<Float64>(repeating: 0, count: 8)
		let x = (0..<8).map(Float64.init)
		var y = Array<Float64>(repeating: 0, count: 8)
		var w = SIMD2<Float64>(0, 0)
		calculus_integration(x, z, &y, &w, 8)
		print(y)
	}
	
	@Test
	func differentiation() {
		let z = Array<Float64>(repeating: 0, count: 8)
		let y = (0..<8).map(Float64.init)//(0..<8).map { Float64($0*$0) * 0.5 }
		var x = Array<Float64>(repeating: 0, count: 8)
		var w = SIMD2<Float64>(0, 0)
		calculus_differentiation(y, z, &x, &w, 8)
		print(x)
	}
}
