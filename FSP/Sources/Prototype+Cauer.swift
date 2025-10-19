//
//  Prototype+Cauer.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Accelerate.Quadrature
import func simd.copysign
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
@inlinable
func elliptic(k: Float64) -> Float64 {
	0.5 * .pi / sequence(first: (1.0, sqrt(fma(-k, k, 1)))) {
		if .ulpOfOne < ($0 - $1).magnitude {
			.some((0.5 * ($0 + $1), sqrt($0 * $1)))
		} else {
			.none
		}
	}.suffix(1).last.unsafelyUnwrapped.0
}
@inlinable
func elliptic(u: Float64, k: Float64) -> (sn: Float64, cn: Float64, dn: Float64) {
	switch k {
	case 0.0:
		let e = __sincos_stret(u)
		return (e.__sinval, e.__cosval, 1.0)
	case 1.0:
		let sech = recip(cosh(u))
		return (tanh(u), sech, sech)
	default:
		func yₙ(aₖ: Float64, bₖ: Float64) -> Float64 {
			let aₙ = 0.5 * (aₖ + bₖ)
			let bₙ = sqrt(aₖ * bₖ)
			let cₙ = 0.5 * (aₖ - bₖ)
			let yₙ = if .ulpOfOne < cₙ.magnitude {
				yₙ(aₖ: aₙ, bₖ: bₙ)
			} else {
				aₙ / sin(aₙ * u)
			}
			return yₙ + aₙ * cₙ / yₙ
		}
		let a₀ = 1.0
		let b₀ = sqrt(1 - k * k)
		let y₁ = yₙ(aₖ: 0.5 * (a₀ + b₀), bₖ: sqrt(a₀ * b₀))
		let sn = y₁ / length_squared(.init(y₁, 0.5 * k))
		let cn = sqrt(fma(-sn, sn, 1))
		let dn = sqrt(fma(-sn*k, sn*k, 1))
		return (sn, cn, dn)
	}
}
@inlinable
func asn(x: Float64, k: Float64) -> Float64 {
	switch k {
	case 0:
		return asin(x)
	case 1:
		return atanh(x)
	default:
		let y = switch x.magnitude {
		case let x where x * x < 0.5:
			Quadrature(integrator: .qng).integrate(over: 0 ... x) {
				vDSP.evaluatePolynomial(usingCoefficients: [k * k, 0, -fma(k, k, 1), 0, 1],
										withVariables: $0,
										result: &$1[$1.startIndex..<$1.endIndex])
				vForce.rsqrt($1, result: &$1[$1.startIndex..<$1.endIndex])
			}
		case let x:
			Quadrature(integrator: .qng).integrate(over: 0 ... asin(x)) {
				vForce.sin($0, result: &$1[$1.startIndex..<$1.endIndex])
				vDSP.square($1, result: &$1[$1.startIndex..<$1.endIndex])
				vDSP.add(multiplication: ($1, -k*k), 1, result: &$1[$1.startIndex..<$1.endIndex])
				vForce.rsqrt($1, result: &$1[$1.startIndex..<$1.endIndex])
			}
		}
		switch y {
		case.success(let s):
			return copysign(s.integralResult, x)
		case.failure(let e):
			os_log(.error, log: .default, "%{public}@", e.errorDescription)
			return.nan
		}
	}
}
@inlinable
func acn(y: Float64, k: Float64) -> Float64 {
	asn(x: sqrt(fma(-y, y, 1)),   k: k)
}
@inlinable
func adn(z: Float64, k: Float64) -> Float64 {
	asn(x: sqrt(fma( z, z, 1))/k, k: k)
}
@inlinable
func asc(w: Float64, k: Float64) -> Float64 {
	asn(x: w / hypot(w, 1), k: k)
}
@inlinable
func elliptic(prime target: Float64) -> Float64 {
	let π = -target * .pi
	let g = (0...).lazy.map {
		SIMD2<Float64>(.init($0 * $0 + $0), .init($0 * $0 + 2 * $0 + 1))
	}
	let a = g.map {
		exp(π * $0)
	}.prefix {
		.ulpOfOne < $0.max()
	}.reduce(SIMD2<Float64>(0, 1)) {
		fma(.init(1, 2), $1, $0)
	}
	return exp(0.5 * π) * (2*a.x/a.y) * (2*a.x/a.y)
}
@inlinable
func cauer(lpf n: Int, ε: Float64, η: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let k₁́ = ε / η
	let K₁́ = elliptic(k: k₁́)
	let k₁ = elliptic(prime: elliptic(k: sqrt(1 - k₁́ * k₁́)) / K₁́ / .init(n))
	let K₁ = elliptic(k: k₁)
	let v₀ = asc(w: 1 / ε, k: k₁) / .init(n)
	let (snₖ́, cnₖ́, dnₖ́) = elliptic(u: v₀ * K₁ / K₁́, k: sqrt(1 - k₁ * k₁))
	let H₁ = n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(0, 1), SIMD2<Float64>(fma(-snₖ́, snₖ́, 1) / (snₖ́ * cnₖ́), 1))
	]
	let H₂ = (0..<n/2).map {
		let uₖ = Float64(n - 2 * $0 - 1) / Float64(n) * K₁
		let (snₖ, cnₖ, dnₖ) = elliptic(u: uₖ, k: k₁)
		let zᵣ = 0.0
		let zᵢ = recip(k₁ * snₖ)
		let pᵣ = (cnₖ * dnₖ * snₖ́ * cnₖ́) / fma(-dnₖ * dnₖ, snₖ́ * snₖ́, 1)
		let pᵢ = (snₖ * dnₖ́) / fma(-dnₖ * dnₖ, snₖ́ * snₖ́, 1)
		let βₖ = length_squared(.init(zᵣ, zᵢ))
		let αₖ = length_squared(.init(pᵣ, pᵢ))
		return (SIMD3<Float64>(recip(βₖ), 0, 1), SIMD3<Float64>(recip(αₖ), 2.0 * pᵣ / αₖ, 1))
	}
	return (H₁, H₂)
}
@inlinable
func cauer(hpf n: Int, ε: Float64, η: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let k₁́ = ε / η
	let K₁́ = elliptic(k: k₁́)
	let k₁ = elliptic(prime: elliptic(k: sqrt(1 - k₁́ * k₁́)) / K₁́ / .init(n))
	let K₁ = elliptic(k: k₁)
	let v₀ = asc(w: 1 / ε, k: k₁) / .init(n)
	let (snₖ́, cnₖ́, dnₖ́) = elliptic(u: v₀ * K₁ / K₁́, k: sqrt(1 - k₁ * k₁))
	let H₁ = n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(1, 0), SIMD2<Float64>(1, fma(-snₖ́, snₖ́, 1) / (snₖ́ * cnₖ́)))
	]
	let H₂ = (0..<n/2).map {
		let uₖ = Float64(n - 2 * $0 - 1) / Float64(n) * K₁
		let (snₖ, cnₖ, dnₖ) = elliptic(u: uₖ, k: k₁)
		let zᵣ = 0.0
		let zᵢ = recip(k₁ * snₖ)
		let pᵣ = (cnₖ * dnₖ * snₖ́ * cnₖ́) / fma(-dnₖ * dnₖ, snₖ́ * snₖ́, 1)
		let pᵢ = (snₖ * dnₖ́) / fma(-dnₖ * dnₖ, snₖ́ * snₖ́, 1)
		let βₖ = length_squared(.init(zᵣ, zᵢ))
		let αₖ = length_squared(.init(pᵣ, pᵢ))
		return (SIMD3<Float64>(1, 0, recip(βₖ)), SIMD3<Float64>(1, 2.0 * pᵣ / αₖ, recip(αₖ)))
	}
	return (H₁, H₂)
}
// LPF
public func filter(_ source: Stream, lpf ω₀: some Publisher<(Int, Frequency), Never> & Sendable, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
	let (H₁, H₂) = cauer(lpf: order, ε: ε, η: η)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Kr(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, lpf ω₀: some Sequence<Frequency>, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
	filter(source, lpf: ω₀.prefix(count: source.count), cauer: order, ε: ε, η: η)
}
public func filter(_ source: Stream, lpf ω₀: some Publisher<Frequency, Never>, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
	filter(source, lpf: ω₀.repeat(count: source.count), cauer: order, ε: ε, η: η)
}
public func filter(_ source: Stream, lpf ω₀: Frequency, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
	filter(source, lpf: `repeat`(ω₀, count: source.count), cauer: order, ε: ε, η: η)
}
public func filter(_ source: Stream, lpf ω₀: Stream, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
	let (H₁, H₂) = cauer(lpf: order, ε: ε, η: η)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Ar(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
// HPF
public func filter(_ source: Stream, hpf ω₀: some Publisher<(Int, Frequency), Never> & Sendable, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
	let (H₁, H₂) = cauer(hpf: order, ε: ε, η: η)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Kr(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, hpf ω₀: some Sequence<Frequency>, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
	filter(source, hpf: ω₀.prefix(count: source.count), cauer: order, ε: ε, η: η)
}
public func filter(_ source: Stream, hpf ω₀: some Publisher<Frequency, Never>, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
	filter(source, hpf: ω₀.repeat(count: source.count), cauer: order, ε: ε, η: η)
}
public func filter(_ source: Stream, hpf ω₀: Frequency, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
	filter(source, hpf: `repeat`(ω₀, count: source.count), cauer: order, ε: ε, η: η)
}
public func filter(_ source: Stream, hpf ω₀: Stream, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
	let (H₁, H₂) = cauer(hpf: order, ε: ε, η: η)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Ar(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
