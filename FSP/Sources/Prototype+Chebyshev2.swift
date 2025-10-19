//
//  Prototype+Chebyshev2.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
import func simd.fma
import func simd.sin
import func simd.cos
import func simd.tan
import func simd.asin
import func simd.acos
import func simd.atan
import func simd.sinh
import func simd.cosh
import func simd.tanh
import func simd.asinh
import func simd.acosh
import func simd.atanh
import func simd.exp
import func simd.hypot
import func simd.sqrt
import func simd.recip
import func simd.__sincos_stret
import func simd.length_squared
import protocol DSP.Stream
import protocol DSP.Frequency
@preconcurrency import protocol Combine.Publisher
import os.log
@inlinable // SOS
func chebyshev2(lpf n: Int, ε: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let β = sinh(asinh(recip(ε)) / .init(n))
	let H₁ = n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(0, 1), SIMD2<Float64>(β, 1))
	]
	let H₂ = (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let e = __sincospi_stret(θ)
		let αₖ = 2 * β * e.__cosval
		let γₖ = e.__sinval * e.__sinval
		let βₖ = fma(β, β, γₖ)
		return (SIMD3<Float64>(γₖ, 0, 1), SIMD3<Float64>(βₖ, αₖ, 1))
	}
	return (H₁, H₂)
}
@inlinable // SOS
func chebyshev2(hpf n: Int, ε: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let β = sinh(asinh(recip(ε)) / .init(n))
	let H₁ = n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(1, 0), SIMD2<Float64>(1, β))
	]
	let H₂ = (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let e = __sincospi_stret(θ)
		let αₖ = 2 * β * e.__cosval
		let γₖ = e.__sinval * e.__sinval
		let βₖ = fma(β, β, γₖ)
		return (SIMD3<Float64>(1, 0, γₖ), SIMD3<Float64>(1, αₖ, βₖ))
	}
	return (H₁, H₂)
}
// LPF
public func filter(_ source: Stream, lpf ω₀: some Publisher<(Int, Frequency), Never> & Sendable, chebyshev2 order: Int, ε: Float64) -> some Stream {
	let (H₁, H₂) = chebyshev2(hpf: order, ε: ε)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Kr(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, lpf ω₀: some Sequence<Frequency>, chebyshev2 order: Int, ε: Float64) -> some Stream {
	filter(source, lpf: ω₀.prefix(count: source.count), chebyshev2: order, ε: ε)
}
public func filter(_ source: Stream, lpf ω₀: some Publisher<Frequency, Never>, chebyshev2 order: Int, ε: Float64) -> some Stream {
	filter(source, lpf: ω₀.repeat(count: source.count), chebyshev2: order, ε: ε)
}
public func filter(_ source: Stream, lpf ω₀: Frequency, chebyshev2 order: Int, ε: Float64) -> some Stream {
	filter(source, lpf: `repeat`(ω₀, count: source.count), chebyshev2: order, ε: ε)
}
public func filter(_ source: Stream, lpf ω₀: Stream, chebyshev2 order: Int, ε: Float64) -> some Stream {
	let (H₁, H₂) = chebyshev2(lpf: order, ε: ε)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Ar(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
// HPF
public func filter(_ source: Stream, hpf ω₀: some Publisher<(Int, Frequency), Never> & Sendable, chebyshev2 order: Int, ε: Float64) -> some Stream {
	let (H₁, H₂) = chebyshev2(hpf: order, ε: ε)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Kr(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, hpf ω₀: some Sequence<Frequency>, chebyshev2 order: Int, ε: Float64) -> some Stream {
	filter(source, hpf: ω₀.prefix(count: source.count), chebyshev2: order, ε: ε)
}
public func filter(_ source: Stream, hpf ω₀: some Publisher<Frequency, Never>, chebyshev2 order: Int, ε: Float64) -> some Stream {
	filter(source, hpf: ω₀.repeat(count: source.count), chebyshev2: order, ε: ε)
}
public func filter(_ source: Stream, hpf ω₀: Frequency, chebyshev2 order: Int, ε: Float64) -> some Stream {
	filter(source, hpf: `repeat`(ω₀, count: source.count), chebyshev2: order, ε: ε)
}
public func filter(_ source: Stream, hpf ω₀: Stream, chebyshev2 order: Int, ε: Float64) -> some Stream {
	let (H₁, H₂) = chebyshev2(hpf: order, ε: ε)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Ar(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
