//
//  Prototype+Bessel.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
import protocol DSP.Stream
import protocol DSP.Frequency
import func simd.length_squared
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Just
import typealias Numerics.Complex128
@inlinable
func bessel(count: Int) -> Array<Int> {
	sequence(state: (Array(repeating: 1, count: 1), Array(repeating: 1, count: 2))) { s in
		defer {
			s.0.append(contentsOf: repeatElement(0, count: 2))
			for (offset, element) in s.1.enumerated() {
				s.0[1+offset] += ( s.1.count * 2 - 1 ) * element
			}
			(s.0, s.1) = (s.1, s.0)
		}
		return.some(s.0)
	}.dropFirst(count).prefix(1).flatMap(\.self)
}
@inlinable
func bessel(lpf order: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let r = roots(poly: bessel(count: order).map(Float64.init))
	let q = order.isMultiple(of: 2) ? 0 : 1
    assert(r.prefix(q).allSatisfy { $0.imag.magnitude < .ulpOfOne })
	return (r.prefix(q).map {
		(SIMD2<Float64>(0, -$0.real), SIMD2<Float64>(1, -$0.real))
	}, r.dropFirst(q).filter { $0.imag.sign == .plus }.map {
        (SIMD3<Float64>(0, 0, $0.magnitudeSquared), SIMD3<Float64>(1, -2*$0.real, $0.magnitudeSquared))
	})
}
@inlinable
func bessel(hpf order: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let r = roots(poly: bessel(count: order).map(Float64.init))
	let q = order.isMultiple(of: 2) ? 0 : 1
    assert(r.prefix(q).allSatisfy { $0.imag.magnitude < .ulpOfOne })
    return (r.prefix(q).map {
        (SIMD2<Float64>(-$0.real, 0), SIMD2<Float64>(-$0.real, 1))
    }, r.dropFirst(q).filter { $0.imag.sign == .plus }.map {
        (SIMD3<Float64>($0.magnitudeSquared, 0, 0), SIMD3<Float64>($0.magnitudeSquared, -2*$0.real, 1))
    })
}
public func filter(_ source: Stream, lpf ω₀: some Publisher<(Int, Frequency), Never> & Sendable, bessel order: Int) -> some Stream {
	let (H₁, H₂) = bessel(lpf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Kr(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, lpf ω₀: some Publisher<Frequency, Never>, bessel order: Int) -> some Stream {
	filter(source, lpf: ω₀.repeat(count: source.count), bessel: order)
}
public func filter(_ source: Stream, lpf ω₀: some Sequence<Frequency>, bessel order: Int) -> some Stream {
	filter(source, lpf: ω₀.prefix(count: source.count), bessel: order)
}
public func filter(_ source: Stream, lpf ω₀: Frequency, bessel order: Int) -> some Stream {
	filter(source, lpf: `repeat`(ω₀, count: source.count), bessel: order)
}
public func filter(_ source: Stream, lpf ω₀: Stream, bessel order: Int) -> some Stream {
	let (H₁, H₂) = bessel(lpf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Ar(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, hpf ω₀: some Publisher<(Int, Frequency), Never> & Sendable, bessel order: Int) -> some Stream {
	let (H₁, H₂) = bessel(hpf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Kr(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, hpf ω₀: some Publisher<Frequency, Never>, bessel order: Int) -> some Stream {
	filter(source, hpf: ω₀.repeat(count: source.count), bessel: order)
}
public func filter(_ source: Stream, hpf ω₀: some Sequence<Frequency>, bessel order: Int) -> some Stream {
	filter(source, hpf: ω₀.prefix(count: source.count), bessel: order)
}
public func filter(_ source: Stream, hpf ω₀: Frequency, bessel order: Int) -> some Stream {
	filter(source, hpf: `repeat`(ω₀, count: source.count), bessel: order)
}
public func filter(_ source: Stream, hpf ω₀: Stream, bessel order: Int) -> some Stream {
	let (H₁, H₂) = bessel(hpf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Ar(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
