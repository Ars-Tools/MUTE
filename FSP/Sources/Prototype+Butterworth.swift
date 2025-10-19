//
//  Prototype+Butterworth.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
import func simd.__cospi
import protocol DSP.Stream
import protocol DSP.Frequency
@preconcurrency import protocol Combine.Publisher
import os.log
@inlinable // SOS
func butterworth(lpf n: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	(n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(0, 1), SIMD2<Float64>(1, 1))
	], (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let α = 2 * __cospi(θ)
		return (SIMD3<Float64>(0, 0, 1), SIMD3<Float64>(1, α, 1))
	})
}
@inlinable // SOS
func butterworth(hpf n: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	(n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(1, 0), SIMD2<Float64>(1, 1))
	], (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let α = 2 * __cospi(θ)
		return (SIMD3<Float64>(1, 0, 0), SIMD3<Float64>(1, α, 1))
	})
}
@inlinable // SOS
func butterworth(bpf n: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	(n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(0, 1), SIMD2<Float64>(0, 1))
	], (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let α = 2 * __cospi(θ)
		return (SIMD3<Float64>(0, α, 0), SIMD3<Float64>(1, α, 1))
	})
}
@inlinable // SOS
func butterworth(bsf n: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	(n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(0, 1), SIMD2<Float64>(0, 1))
	], (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let α = 2 * __cospi(θ)
		return (SIMD3<Float64>(1, 0, 1), SIMD3<Float64>(1, α, 1))
	})
}
@inlinable // SOS
func butterworth(apf n: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	(n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(1, -1), SIMD2<Float64>(1, 1))
	], (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let α = 2 * __cospi(θ)
		return (SIMD3<Float64>(1, -α, 1), SIMD3<Float64>(1, α, 1))
	})
}
// LPF
public func filter(_ source: Stream, lpf ω₀: some Publisher<(Int, Frequency), Never> & Sendable, butterworth order: Int) -> some Stream {
	let (H₁, H₂) = butterworth(lpf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Kr(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, lpf ω₀: some Sequence<Frequency>, butterworth order: Int) -> some Stream {
	filter(source, lpf: ω₀.prefix(count: source.count), butterworth: order)
}
public func filter(_ source: Stream, lpf ω₀: some Publisher<Frequency, Never>, butterworth order: Int) -> some Stream {
	filter(source, lpf: ω₀.repeat(count: source.count), butterworth: order)
}
public func filter(_ source: Stream, lpf ω₀: Frequency, butterworth order: Int) -> some Stream {
	filter(source, lpf: `repeat`(ω₀, count: source.count), butterworth: order)
}
public func filter(_ source: Stream, lpf ω₀: Stream, butterwoth order: Int) -> some Stream {
	let (H₁, H₂) = butterworth(lpf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Ar(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
// HPF
public func filter(_ source: Stream, hpf ω₀: some Publisher<(Int, Frequency), Never> & Sendable, butterworth order: Int) -> some Stream {
	let (H₁, H₂) = butterworth(hpf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Kr(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, hpf ω₀: some Sequence<Frequency>, butterworth order: Int) -> some Stream {
	filter(source, hpf: ω₀.prefix(count: source.count), butterworth: order)
}
public func filter(_ source: Stream, hpf ω₀: some Publisher<Frequency, Never>, butterworth order: Int) -> some Stream {
	filter(source, hpf: ω₀.repeat(count: source.count), butterworth: order)
}
public func filter(_ source: Stream, hpf ω₀: Frequency, butterworth order: Int) -> some Stream {
	filter(source, hpf: `repeat`(ω₀, count: source.count), butterworth: order)
}
public func filter(_ source: Stream, hpf ω₀: Stream, butterwoth order: Int) -> some Stream {
	let (H₁, H₂) = butterworth(hpf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Ar(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
// BPF
public func filter(_ source: Stream, bpf ω₀: some Publisher<(Int, Frequency), Never> & Sendable, butterworth order: Int) -> some Stream {
	let (H₁, H₂) = butterworth(bpf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Kr(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, bpf ω₀: some Sequence<Frequency>, butterworth order: Int) -> some Stream {
	filter(source, bpf: ω₀.prefix(count: source.count), butterworth: order)
}
public func filter(_ source: Stream, bpf ω₀: some Publisher<Frequency, Never>, butterworth order: Int) -> some Stream {
	filter(source, bpf: ω₀.repeat(count: source.count), butterworth: order)
}
public func filter(_ source: Stream, bpf ω₀: Frequency, butterworth order: Int) -> some Stream {
	filter(source, bpf: `repeat`(ω₀, count: source.count), butterworth: order)
}
public func filter(_ source: Stream, bpf ω₀: Stream, butterwoth order: Int) -> some Stream {
	let (H₁, H₂) = butterworth(bpf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Ar(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
// APF
public func filter(_ source: Stream, apf ω₀: some Publisher<(Int, Frequency), Never> & Sendable, butterworth order: Int) -> some Stream {
	let (H₁, H₂) = butterworth(apf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Kr(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
public func filter(_ source: Stream, apf ω₀: some Sequence<Frequency>, butterworth order: Int) -> some Stream {
	filter(source, apf: ω₀.prefix(count: source.count), butterworth: order)
}
public func filter(_ source: Stream, apf ω₀: some Publisher<Frequency, Never>, butterworth order: Int) -> some Stream {
	filter(source, apf: ω₀.repeat(count: source.count), butterworth: order)
}
public func filter(_ source: Stream, apf ω₀: Frequency, butterworth order: Int) -> some Stream {
	filter(source, apf: `repeat`(ω₀, count: source.count), butterworth: order)
}
public func filter(_ source: Stream, apf ω₀: Stream, butterworth order: Int) -> some Stream {
	let (H₁, H₂) = butterworth(apf: order)
	assert(H₁.count + 2 * H₂.count == order)
	return Prototype.Ar(x₀: source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
