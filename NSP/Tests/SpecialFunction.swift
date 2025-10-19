//
//  SpecialFunction.swift
//  MUTE
//
//  Created by Kota on 7/23/R7.
//
import Testing
import NSP
import Accelerate
@Suite
struct SpecialFunction {
	@Test(arguments: [
		0.1, 0.3, 0.7, 1.5, 3.1,
	])
	func I0(x: Float64) { // (1/π)∫_0^π{cosh(zcosθ)}dθ
		let a = Quadrature(integrator: .qng)
			.integrate(over: 0.0 ... .pi) {
				var r = $1
				vForce.cos($0, result: &r)
				vDSP.multiply(x, r, result: &r)
				vForce.cosh(r, result: &r)
			}
		switch a {
		case.success((let r, let e)):
			#expect(e.magnitude < 1e-3)
			#expect((r / .pi - i0(x)).magnitude < 1e-6)
		case.failure(let e):
			Issue.record(.__line(e.errorDescription))
		}
	}
	@Test(arguments: [
		0.1, 0.3, 0.7, 1.5, 3.1,
	])
	func I1(x: Float64) { // (1/π)∫_0^π{exp(xcosθ)cos(nθ)}dθ
		let n = 1.0
		let a = Quadrature(integrator: .qng)
			.integrate(over: 0.0 ... .pi) {
				var s = UnsafeMutableBufferPointer(mutating: $0)
				var t = $1
				vForce.cos(s, result: &t)
				vDSP.multiply(n, s, result: &s)
				vForce.cos(s, result: &s)
				vDSP.multiply(x, t, result: &t)
				vForce.exp(t, result: &t)
				vDSP.multiply(s, t, result: &t)
			}
		switch a {
		case.success((let r, let e)):
			#expect(e.magnitude < 1e-3)
			#expect((r / .pi - NSP.in(1, x)).magnitude < 1e-6)
			print(r / .pi, NSP.in(1, x))
		case.failure(let e):
			Issue.record(.__line(e.errorDescription))
		}
	}
//	@Test
//	func K0() {
//		let x = 0.5
//		let n = 0.0
//		
//		let a = Quadrature(integrator: .qags(maxIntervals: 200))
//			.integrate(over: 0 ... .pi) { // -(1/π)∫_0^π(exp(zcosθ)(γ+ln(2z(sinθ)^2)))dθ
//				
//			}
//	}
}
