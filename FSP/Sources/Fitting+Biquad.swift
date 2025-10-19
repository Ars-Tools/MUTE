//
//  Fitting+Biquad.swift
//  MUTE
//
//  Created by Kota on 8/26/R7.
//
import Accelerate
// fit
public func fit(power target: some AccelerateBuffer<Float64>, source: Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let count = target.count
	let (e0, e1, e2) = withUnsafeTemporaryAllocation(of: Float64.self, capacity: count) {
		vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0[$0.startIndex..<$0.endIndex])
		vDSP.divide($0, .init($0.count), result: &$0[$0.startIndex..<$0.endIndex])
		let c0 = Array<Float64>(repeating: 1, count: $0.count)
		let s0 = Array<Float64>(repeating: 0, count: $0.count)
		let c1 = vForce.cosPi($0)
		let s1 = vForce.sinPi($0)
		vDSP.multiply(2, $0, result: &$0[$0.startIndex..<$0.endIndex])
		let c2 = vForce.cosPi($0)
		let s2 = vForce.sinPi($0)
		return ((r: c0, i: s0), (r: c1, i: s1), (r: c2, i: s2))
	}
	// forward
	let powers = source.map { b, a in
		let B = Array<Float64>(unsafeUninitializedCapacity: 3 * count) {
			var r = $0.extracting(0 * count ..< 1 * count)
			var i = $0.extracting(1 * count ..< 2 * count)
			// B
			vDSP.add(multiplication: (e1.i, b.y), multiplication: (e2.i, b.z), result: &i)
			vDSP.add(multiplication: (e1.r, b.y), multiplication: (e2.r, b.z), result: &r)
			vDSP.add(b.x, r, result: &r)
			vDSP.add(multiplication: (r, r), multiplication: (i, i), result: &r)
			$1 = count
		}
		let A = Array<Float64>(unsafeUninitializedCapacity: 3 * count) {
			var r = $0.extracting(0 * count ..< 1 * count)
			var i = $0.extracting(1 * count ..< 2 * count)
			// B
			vDSP.add(multiplication: (e1.i, a.y), multiplication: (e2.i, a.z), result: &i)
			vDSP.add(multiplication: (e1.r, a.y), multiplication: (e2.r, a.z), result: &r)
			vDSP.add(a.x, r, result: &r)
			vDSP.add(multiplication: (r, r), multiplication: (i, i), result: &r)
			$1 = count
		}
		return (b: B, a: A)
	}
	// error = log(target) - Σlog(B) + Σlog(A)
	let error = powers.reduce(into: vForce.log(target)) { z, x in
		withUnsafeTemporaryAllocation(of: Float64.self, capacity: count) {
			vForce.log(x.b, result: &$0[$0.startIndex..<$0.endIndex])
			vDSP.subtract($0, z, result: &z)
			vForce.log(x.a, result: &$0[$0.startIndex..<$0.endIndex])
			vDSP.add($0, z, result: &z)
		}
	}
	let ε = 0.01
	let Δ = error // weighted
	// backward
	
	
}
