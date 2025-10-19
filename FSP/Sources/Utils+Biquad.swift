//
//  Utils+Biquad.swift
//  MUTE
//
//  Created by Kota on 8/26/R7.
//
import typealias Foundation.KeyPathComparator
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
//import func simd.__sincospi_stret
import typealias Numerics.Complex128
import typealias Dense.MatBuf
import typealias Optimise.Graph
import func simd.log
import func simd.atan2
import func simd.length
public func fit(response: some AccelerateBuffer<Complex128>, frequency: some AccelerateBuffer<Float64>, with sos: Int) -> Array<(SIMD3<Float64>, SIMD3<Float64>)> {
	let (b, a) = fit(response: response, frequency: frequency, with: (2 * sos, 2 * sos))
	let zeros = roots(poly: b).sorted(using: KeyPathComparator(\.imag.magnitude, order: .reverse))
	let poles = roots(poly: a).sorted(using: KeyPathComparator(\.imag.magnitude, order: .reverse))
	assert(zeros.count.isMultiple(of: 2))
	assert(poles.count.isMultiple(of: 2))
	let z = stride(from: 0, to: zeros.count, by: 2).map {
		switch (zeros[$0], zeros[$0+1]) {
		case (let z0, let z1) where z0.imag < z1.imag:
			(z1, z0)
		case (let z0, let z1):
			(z0, z1)
		}
	}
	let p = stride(from: 0, to: poles.count, by: 2).map {
		switch (poles[$0], poles[$0+1]) {
		case (let p0, let p1) where p0.imag < p1.imag:
			(p1, p0)
		case (let p0, let p1):
			(p0, p1)
		}
	}
	assert(z.count == sos)
	assert(p.count == sos)
	let c = min(z.prefix { ($0 - $1.conjugate).magnitude < .ulpOfOne }.count,
				p.prefix { ($0 - $1.conjugate).magnitude < .ulpOfOne }.count)
	var table = MatBuf<Float64>(shape: (c, c), for: .rowMajor, with: .zero)
	for (j, p) in p.prefix(c).enumerated() {
		for (k, z) in z.prefix(c).enumerated() {
			assert(p.0.imag.sign == z.0.imag.sign)
			let p = SIMD2<Float64>(log(p.0.magnitude), atan2(p.0.imag, p.0.real))
			let z = SIMD2<Float64>(log(z.0.magnitude), atan2(z.0.imag, z.0.real))
			table[j, k] = length(p - z)
		}
	}
	let pair = zip(z.dropFirst(c), p.dropFirst(c)) + Graph.Match(table: table).map {
		(z[$0.y], p[$0.x])
	}
	return pair.map {(
		SIMD3<Float64>(1, -($0.0 + $0.1).real, ($0.0 * $0.1).real),
		SIMD3<Float64>(1, -($1.0 + $1.1).real, ($1.0 * $1.1).real)
	)}
}
public func fit(response: some AccelerateBuffer<Complex128>, with sos: Int) -> Array<(SIMD3<Float64>, SIMD3<Float64>)> {
	fit(response: response,
		frequency: Array(unsafeUninitializedCapacity: response.count) {
		vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
		vDSP.divide($0, .init($0.count), result: &$0)
		$1 = $0.count
	}, with: sos)
}
