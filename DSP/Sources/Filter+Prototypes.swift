//
//  Filter+Prototypes.swift
//  MUTE
//
//  Created by Kota on 8/8/R7.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Accelerate.Quadrature
import func Accelerate.vecLib.dgemm_
import simd
import os.log
@preconcurrency import protocol Combine.Publisher
public enum Prototype {
	@usableFromInline
	struct ZP {
		
	}
	@usableFromInline
	struct SOS {
		@usableFromInline let ω₀: Frequency
		@usableFromInline let H₁: Array<(SIMD2<Float64>, SIMD2<Float64>)> // odds
		@usableFromInline let H₂: Array<(SIMD3<Float64>, SIMD3<Float64>)> // even
	}
	@usableFromInline
	struct Poly {
		@usableFromInline let ω₀: Frequency
		@usableFromInline let Bₛ: Array<Float64>
		@usableFromInline let Aₛ: Array<Float64>
	}
	@usableFromInline
	struct Kr<D: Publisher<Array<Float64>, Never> & Sendable, C: Publisher<Frequency, Never> & Sendable> {
		@usableFromInline let design: D
		@usableFromInline let cutoff: C
	}
	@usableFromInline
	struct Ar {
		@usableFromInline let design: Stream
		@usableFromInline let cutoff: Stream
	}
}
extension Prototype {
	@inlinable
	static func Matrix(_ n: Int) -> Array<Float64> {
		vDSP.integerToFloatingPoint(Array<Int32>(unsafeUninitializedCapacity: n * n * 3) {
			let lhs = $0.extracting(1 * n * n ..< 2 * n * n)
			let rhs = $0.extracting(2 * n * n ..< 3 * n * n)
			$0.initialize(repeating: .zero)
			lhs[0] = 1
			rhs[0] = 1
			for (k, j) in stride(from: 0, to: n * n, by: n).dropLast().enumerated() {
				for i in j...j+k {
					lhs[i+n+0] += lhs[i]
					rhs[i+n+0] += rhs[i]
				}
				for i in j...j+k {
					lhs[i+n+1] += lhs[i]
					rhs[i+n+1] -= rhs[i]
				}
			}
			for (p, q) in (0..<n).reversed().enumerated() {
				let lhs = lhs[p*n...p*n+p]
				let rhs = rhs[q*n...q*n+q]
				for (s, t) in lhs.enumerated() {
					for (u, v) in rhs.enumerated() {
						$0[p*n+s+u] += t * v
					}
				}
			}
			$1 = n * n
		}, floatingPointType: Float64.self)
	}
}
extension Prototype.Poly {
	@inlinable
	static func Matrix(_ n: Int) -> Array<Float64> {
		Array<Int>(unsafeUninitializedCapacity: n * n * 3) {
			let lhs = $0.extracting(1 * n * n ..< 2 * n * n)
			let rhs = $0.extracting(2 * n * n ..< 3 * n * n)
			$0.initialize(repeating: .zero)
			lhs[0] = 1
			rhs[0] = 1
			for (k, j) in stride(from: 0, to: n * n, by: n).dropLast().enumerated() {
				for i in j...j+k {
					lhs[i+n+0] += lhs[i]
					rhs[i+n+0] += rhs[i]
				}
				for i in j...j+k {
					lhs[i+n+1] += lhs[i]
					rhs[i+n+1] -= rhs[i]
				}
			}
			for (p, q) in (0..<n).reversed().enumerated() {
				let lhs = lhs[p*n...p*n+p]
				let rhs = rhs[q*n...q*n+q]
				for (s, t) in lhs.enumerated() {
					for (u, v) in rhs.enumerated() {
						$0[p*n+s+u] += t * v
					}
				}
			}
			$1 = n * n
		}.map(Float64.init)
	}
}
extension Prototype.Kr {
	
}
extension Prototype.Ar: Stream {
	@inlinable
	var count: Int {
		design.count
	}
	@inlinable @inline(__always)
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let factor = -interval.seconds
		guard cutoff.count == 1 else { throw Error.invalidChannel }
		let cutoff = try cutoff(interval: interval, capacity: capacity, instance: &instance)
		let degree = design.count
		let design = try design(interval: interval, capacity: capacity, instance: &instance)
		let matrix = Prototype.Matrix(degree)
		return { moment, length, target, stride in
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( degree + 2 ) * length) {
				var scale = $0.extracting(degree*length+0*length..<degree*length+1*length)
				var accum = $0.extracting(degree*length+1*length..<degree*length+2*length)
				design(moment, length, $0.baseAddress.unsafelyUnwrapped, length)
				cutoff(moment, length, scale.baseAddress.unsafelyUnwrapped, length)
				vDSP.add(multiplication: (scale, factor), 0.5, result: &scale)
				vForce.tanPi(scale, result: &scale)
				vDSP.fill(&accum, with: 1)
				for offset in Swift.stride(from: 0, to: degree * length - length, by: length).reversed() {
					vDSP.multiply(accum, scale, result: &accum)
					vDSP.multiply(accum, $0[offset..<offset+length], result: &$0[offset..<offset+length])
				}
				var m = length
				var n = degree
				var k = degree
				var α = 1.0
				var β = 0.0
				var lda = length
				var ldb = degree
				var ldc = stride
				dgemm_("N", "T",
					   &m, &n, &k,
					   &α,
					   $0.baseAddress, &lda,
					   matrix, &ldb,
					   &β,
					   target, &ldc)
			}
		}
	}
}
// MARK: Bessel
//public func filter(_ source: Stream, lpf ω₀: Stream, bessel order: Int) -> some Stream {
//	let θ = sequence(state: (Array(repeating: 1.0, count: 1), Array(repeating: 1.0, count: 2))) { s in
//		defer {
//			s.0.append(contentsOf: repeatElement(0, count: 2))
//			vDSP.add(multiplication: (s.1, .init(s.1.count * 2 - 1)), s.0[1...], result: &s.0[1...])
//			(s.0, s.1) = (s.1, s.0)
//		}
//		return.some(s.0)
//	}
//	let x = Array<Float64>(unsafeUninitializedCapacity: order + 1) {
//		$0.initialize(repeating: .zero)
//		$0[order] = .init(sequence(first: 1, next: 2.advanced(by:)).prefix(order).reduce(1, *))
//		$1 = $0.count
//	}
//	let y = θ.dropFirst(order).prefix(1).map(\.self).first.unsafelyUnwrapped
//	let cutoff = buffer(ω₀)
//	return filter(source, b: Prototype.Ar(design: const(x), cutoff: cutoff), a: Prototype.Ar(design: const(y), cutoff: cutoff))
//}
//public func filter(_ source: Stream, hpf ω₀: Stream, bessel order: Int) -> some Stream {
//	let θ = sequence(state: (Array(repeating: 1.0, count: 1), Array(repeating: 1.0, count: 2))) { s in
//		defer {
//			s.0.append(contentsOf: repeatElement(0, count: 2))
//			vDSP.add(multiplication: (s.1, .init(s.1.count * 2 - 1)), s.0[1...], result: &s.0[1...])
//			(s.0, s.1) = (s.1, s.0)
//		}
//		return.some(s.0)
//	}
//	let x = Array<Float64>.init(unsafeUninitializedCapacity: order + 1) {
//		$0.initialize(repeating: .zero)
//		$0[0] = 1
//		$1 = $0.count
//	}
//	let y = θ.dropFirst(order).prefix(1).map(\.self).first.unsafelyUnwrapped
//	let cutoff = buffer(ω₀)
//	return filter(source, b: Prototype.Ar(design: const(x), cutoff: cutoff), a: Prototype.Ar(design: const(y), cutoff: cutoff))
//}
// MARK: Butterworth
@inlinable // SOS
func butterworth(lpf n: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let H₁ = n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(0, 1), SIMD2<Float64>(1, 1))
	]
	let H₂ = (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let α = 2 * __cospi(θ)
		return (SIMD3<Float64>(0, 0, 1), SIMD3<Float64>(1, α, 1))
	}
	return (H₁, H₂)
}
@inlinable // SOS
func butterworth(hpf n: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let H₁ = n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(1, 0), SIMD2<Float64>(1, 1))
	]
	let H₂ = (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let α = 2 * __cospi(θ)
		return (SIMD3<Float64>(1, 0, 0), SIMD3<Float64>(1, α, 1))
	}
	return (H₁, H₂)
}
@inlinable // SOS
func butterworth(bpf n: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let H₁ = n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(1, 0), SIMD2<Float64>(1, 1))
	]
	let H₂ = (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let α = 2 * __cospi(θ)
		return (SIMD3<Float64>(0, α, 0), SIMD3<Float64>(1, α, 1))
	}
	return (H₁, H₂)
}
@inlinable // SOS
func butterworth(bsf n: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let H₁ = n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(0, 1), SIMD2<Float64>(1, 1))
	]
	let H₂ = (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let α = 2 * __cospi(θ)
		return (SIMD3<Float64>(1, 0, 1), SIMD3<Float64>(1, α, 1))
	}
	return (H₁, H₂)
}
@inlinable // SOS
func butterworth(apf n: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
	let H₁ = n.isMultiple(of: 2) ? [] : [
		(SIMD2<Float64>(1, -1), SIMD2<Float64>(1, 1))
	]
	let H₂ = (0..<n/2).map {
		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
		let α = 2 * __cospi(θ)
		return (SIMD3<Float64>(1, -α, 1), SIMD3<Float64>(1, α, 1))
	}
	return (H₁, H₂)
}
@usableFromInline
enum Butterworth {
	@inlinable
	static func series(count: Int) -> Array<Float64> {
		Array<Float64>(unsafeUninitializedCapacity: count / 2) {
			vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
			vDSP.add(multiplication: ($0, -2), .init(count - 1), result: &$0)
			vDSP.divide($0, .init(2 * count), result: &$0)
			vForce.cosPi($0, result: &$0)
			$1 = $0.count
		}
	}
//	@usableFromInline
//	struct LPF {
//		@usableFromInline let even: Bool
//		@usableFromInline let ω₀: Frequency
//		@usableFromInline let αₖ: Array<Float64>
//	}
//	@usableFromInline
//	struct HPF {
//		@usableFromInline let even: Bool
//		@usableFromInline let ω₀: Frequency
//		@usableFromInline let αₖ: Array<Float64>
//	}
}
//extension Butterworth.LPF: DSP.SOS {
//	@inlinable
//	init(ω₀ cutoff: Frequency, order: Int) {
//		even = order.isMultiple(of: 2)
//		ω₀ = cutoff
//		αₖ = Butterworth.series(count: order)
//	}
//	@inlinable
//	func coefficients(for Ts: CMTime) -> Array<Float64> {
//		let e = __sincospi_stret(2.0 * ω₀.increment(for: Ts))
//		return αₖ.reduce(into: .init(unsafeUninitializedCapacity: 5) {
//			let a₀ = e.__sinval + e.__cosval + 1
//			let ab = SIMD2<Float64>(e.__sinval - e.__cosval - 1, e.__sinval) / a₀
//			$0[$0.initialize(fromContentsOf: [ab.y, ab.y, 0, ab.x, 0])...].initialize(repeating: .zero)
//			$1 = even ? 0 : $0.count
//		}) { y, x in
//			let a₀ = fma(e.__sinval,  x, 1)
//			let ab = SIMD4<Float64>(fma(e.__sinval, -x, 1), -2 * e.__cosval, fma(e.__cosval, -1.0, 1.0), fma(e.__cosval, -0.5, 0.5)) / a₀
//			y.append(ab.w)
//			y.append(ab.z)
//			y.append(ab.w)
//			y.append(ab.y)
//			y.append(ab.x)
//		}
//	}
//}
//extension Butterworth.HPF: DSP.SOS {
//	@inlinable
//	init(ω₀ cutoff: Frequency, order: Int) {
//		even = order.isMultiple(of: 2)
//		ω₀ = cutoff
//		αₖ = Butterworth.series(count: order)
//	}
//	@inlinable
//	func coefficients(for Ts: CMTime) -> Array<Float64> {
//		let e = __sincospi_stret(2.0 * ω₀.increment(for: Ts))
//		return αₖ.reduce(into: .init(unsafeUninitializedCapacity: 5) {
//			let a₀ = e.__sinval + e.__cosval + 1
//			let ab = SIMD2<Float64>(e.__sinval - e.__cosval - 1, e.__cosval + 1) / a₀
//			$0[$0.initialize(fromContentsOf: [ab.y, -ab.y, 0, ab.x, 0])...].initialize(repeating: .zero)
//			$1 = even ? 0 : $0.count
//		}) { y, x in
//			let a₀ = fma(e.__sinval,  x, 1)
//			let ab = SIMD4<Float64>(fma(e.__sinval, -x, 1), -2 * e.__cosval, fma(e.__cosval, -1.0, -1.0), fma(e.__cosval, 0.5, 0.5)) / a₀
//			y.append(ab.w)
//			y.append(ab.z)
//			y.append(ab.w)
//			y.append(ab.y)
//			y.append(ab.x)
//		}
//	}
//}
//public func filter(_ source: Stream, lpf ω₀: Stream, butterworth order: Int) -> some Stream {
//	let α = Butterworth.series(count: order)
//	let x = Array<Float64>(unsafeUninitializedCapacity: order + 1) {
//		$0.initialize(repeating: .zero)
//		$0[order] = 1
//		$1 = $0.count
//	}
//	let y = α.reduce(Array<Float64>(repeating: 1, count: 1 + order % 2)) { y, α in
//		Array<Float64>(unsafeUninitializedCapacity: y.count + 2) {
//			$0[$0.initialize(fromContentsOf: y)...].initialize(repeating: .zero)
//			vDSP.add(y, $0[2..<$0.endIndex], result: &$0[2..<$0.endIndex])
//			vDSP.add(multiplication: (y, 2 * α), $0[1..<$0.endIndex-1], result: &$0[1..<$0.endIndex-1])
//			$1 = $0.count
//		}
//	}
//	let cutoff = buffer(ω₀)
//	return filter(source, b: Prototype.Ar(design: const(x), cutoff: cutoff), a: Prototype.Ar(design: const(y), cutoff: cutoff))
//}
//public func filter(_ source: Stream, hpf ω₀: Stream, butterworth order: Int) -> some Stream {
//	let α = Butterworth.series(count: order)
//	let x = Array<Float64>(unsafeUninitializedCapacity: order + 1) {
//		$0.initialize(repeating: .zero)
//		$0[0] = 1
//		$1 = $0.count
//	}
//	let y = α.reduce(Array<Float64>(repeating: 1, count: 1 + order % 2)) { y, α in
//		Array<Float64>(unsafeUninitializedCapacity: y.count + 2) {
//			$0[$0.initialize(fromContentsOf: y)...].initialize(repeating: .zero)
//			vDSP.add(y, $0[2..<$0.endIndex], result: &$0[2..<$0.endIndex])
//			vDSP.add(multiplication: (y, 2 * α), $0[1..<$0.endIndex-1], result: &$0[1..<$0.endIndex-1])
//			$1 = $0.count
//		}
//	}
//	let cutoff = buffer(ω₀)
//	return filter(source, b: Prototype.Ar(design: const(x), cutoff: cutoff), a: Prototype.Ar(design: const(y), cutoff: cutoff))
//}
//// LPF
//public func filter(_ source: Stream, lpf ω₀: some Publisher<(Int, Frequency), Never>, butterworth order: Int) -> some Stream {
//	let (H₁, H₂) = butterworth(lpf: order)
//	return filter(source, sos: ω₀.map {
//		($0, Prototype.SOS(ω₀: $1, H₁: H₁, H₂: H₂))
//	}, length: order)
//}
//public func filter(_ source: Stream, lpf ω₀: some Sequence<Frequency>, butterworth order: Int) -> some Stream {
//	filter(source, lpf: ω₀.prefix(count: source.count), butterworth: order)
//}
//public func filter(_ source: Stream, lpf ω₀: some Publisher<Frequency, Never>, butterworth order: Int) -> some Stream {
//	filter(source, lpf: ω₀.repeat(count: source.count), butterworth: order)
//}
//public func filter(_ source: Stream, lpf ω₀: Frequency, butterworth order: Int) -> some Stream {
//	filter(source, lpf: `repeat`(ω₀, count: source.count), butterworth: order)
//}
//// HPF
//public func filter(_ source: Stream, hpf ω₀: some Publisher<(Int, Frequency), Never>, butterworth order: Int) -> some Stream {
//	let (H₁, H₂) = butterworth(hpf: order)
//	return filter(source, sos: ω₀.map {
//		($0, Prototype.SOS(ω₀: $1, H₁: H₁, H₂: H₂))
//	}, length: order)
//}
//public func filter(_ source: Stream, hpf ω₀: some Sequence<Frequency>, butterworth order: Int) -> some Stream {
//	filter(source, hpf: ω₀.prefix(count: source.count), butterworth: order)
//}
//public func filter(_ source: Stream, hpf ω₀: some Publisher<Frequency, Never>, butterworth order: Int) -> some Stream {
//	filter(source, hpf: ω₀.repeat(count: source.count), butterworth: order)
//}
//public func filter(_ source: Stream, hpf ω₀: Frequency, butterworth order: Int) -> some Stream {
//	filter(source, hpf: `repeat`(ω₀, count: source.count), butterworth: order)
//}
//// BPF
//public func filter(_ source: Stream, bpf ω₀: some Publisher<(Int, Frequency), Never>, butterworth order: Int) -> some Stream {
//	let (H₁, H₂) = butterworth(bpf: order)
//	return filter(source, sos: ω₀.map {
//		($0, Prototype.SOS(ω₀: $1, H₁: H₁, H₂: H₂))
//	}, length: order)
//}
//public func filter(_ source: Stream, bpf ω₀: some Sequence<Frequency>, butterworth order: Int) -> some Stream {
//	filter(source, bpf: ω₀.prefix(count: source.count), butterworth: order)
//}
//public func filter(_ source: Stream, bpf ω₀: some Publisher<Frequency, Never>, butterworth order: Int) -> some Stream {
//	filter(source, bpf: ω₀.repeat(count: source.count), butterworth: order)
//}
//public func filter(_ source: Stream, bpf ω₀: Frequency, butterworth order: Int) -> some Stream {
//	filter(source, bpf: `repeat`(ω₀, count: source.count), butterworth: order)
//}
//// APF
//public func filter(_ source: Stream, apf ω₀: some Publisher<(Int, Frequency), Never>, butterworth order: Int) -> some Stream {
//	let (H₁, H₂) = butterworth(apf: order)
//	return filter(source, sos: ω₀.map {
//		($0, Prototype.SOS(ω₀: $1, H₁: H₁, H₂: H₂))
//	}, length: order)
//}
//public func filter(_ source: Stream, apf ω₀: some Sequence<Frequency>, butterworth order: Int) -> some Stream {
//	filter(source, apf: ω₀.prefix(count: source.count), butterworth: order)
//}
//public func filter(_ source: Stream, apf ω₀: some Publisher<Frequency, Never>, butterworth order: Int) -> some Stream {
//	filter(source, apf: ω₀.repeat(count: source.count), butterworth: order)
//}
//public func filter(_ source: Stream, apf ω₀: Frequency, butterworth order: Int) -> some Stream {
//	filter(source, apf: `repeat`(ω₀, count: source.count), butterworth: order)
//}
// MARK: Chebyshev 1
//@inlinable // SOS
//func chebyshev1(lpf n: Int, ε: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
//	let β = sinh(asinh(recip(ε)) / .init(n))
//	let H₁ = n.isMultiple(of: 2) ? [] : [
//		(SIMD2<Float64>(0, β), SIMD2<Float64>(1, β))
//	]
//	let H₂ = (0..<n/2).map {
//		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
//		let e = __sincospi_stret(θ)
//		let αₖ = 2 * β * e.__cosval
//		let βₖ = length_squared(SIMD2(β, e.__sinval))
//		return (SIMD3<Float64>(0, 0, βₖ), SIMD3<Float64>(1, αₖ, βₖ))
//	}
//	return (H₁, H₂)
//	
//}
//@inlinable // SOS
//func chebyshev1(hpf n: Int, ε: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
//	let β = sinh(asinh(recip(ε)) / .init(n))
//	let H₁ = n.isMultiple(of: 2) ? [] : [
//		(SIMD2<Float64>(β, 0), SIMD2<Float64>(β, 1))
//	]
//	let H₂ = (0..<n/2).map {
//		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
//		let e = __sincospi_stret(θ)
//		let αₖ = 2 * β * e.__cosval
//		let βₖ = length_squared(SIMD2(β, e.__sinval))
//		return (SIMD3<Float64>(βₖ, 0, 0), SIMD3<Float64>(βₖ, αₖ, 1))
//	}
//	return (H₁, H₂)
//}
//public func filter(_ source: Stream, lpf ω₀: some Publisher<(Int, Frequency), Never>, chebyshev1 order: Int, ε: Float64) -> some Stream {
//	let (H₁, H₂) = chebyshev1(lpf: order, ε: ε)
//	return filter(source, sos: ω₀.map {
//		($0, Prototype.SOS(ω₀: $1, H₁: H₁, H₂: H₂))
//	}, length: order)
//}
//public func filter(_ source: Stream, lpf ω₀: some Sequence<Frequency>, chebyshev1 order: Int, ε: Float64) -> some Stream {
//	filter(source, lpf: ω₀.prefix(count: source.count), chebyshev1: order, ε: ε)
//}
//public func filter(_ source: Stream, lpf ω₀: some Publisher<Frequency, Never>, chebyshev1 order: Int, ε: Float64) -> some Stream {
//	filter(source, lpf: ω₀.repeat(count: source.count), chebyshev1: order, ε: ε)
//}
//public func filter(_ source: Stream, lpf ω₀: Frequency, chebyshev1 order: Int, ε: Float64) -> some Stream {
//	filter(source, lpf: `repeat`(ω₀, count: source.count), chebyshev1: order, ε: ε)
//}
//public func filter(_ source: Stream, hpf ω₀: some Publisher<(Int, Frequency), Never>, chebyshev1 order: Int, ε: Float64) -> some Stream {
//	let (H₁, H₂) = chebyshev1(hpf: order, ε: ε)
//	return filter(source, sos: ω₀.map {
//		($0, Prototype.SOS(ω₀: $1, H₁: H₁, H₂: H₂))
//	}, length: order)
//}
//public func filter(_ source: Stream, hpf ω₀: some Sequence<Frequency>, chebyshev1 order: Int, ε: Float64) -> some Stream {
//	filter(source, hpf: ω₀.prefix(count: source.count), chebyshev1: order, ε: ε)
//}
//public func filter(_ source: Stream, hpf ω₀: some Publisher<Frequency, Never>, chebyshev1 order: Int, ε: Float64) -> some Stream {
//	filter(source, hpf: ω₀.repeat(count: source.count), chebyshev1: order, ε: ε)
//}
//public func filter(_ source: Stream, hpf ω₀: Frequency, chebyshev1 order: Int, ε: Float64) -> some Stream {
//	filter(source, hpf: `repeat`(ω₀, count: source.count), chebyshev1: order, ε: ε)
//}
// MARK: Chebyshev 2
//@inlinable // SOS
//func chebyshev2(lpf n: Int, ε: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
//	let β = sinh(asinh(recip(ε)) / .init(n))
//	let H₁ = n.isMultiple(of: 2) ? [] : [
//		(SIMD2<Float64>(0, 1), SIMD2<Float64>(β, 1))
//	]
//	let H₂ = (0..<n/2).map {
//		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
//		let e = __sincospi_stret(θ)
//		let αₖ = 2 * β * e.__cosval
//		let γₖ = e.__sinval * e.__sinval
//		let βₖ = fma(β, β, γₖ)
//		return (SIMD3<Float64>(γₖ, 0, 1), SIMD3<Float64>(βₖ, αₖ, 1))
//	}
//	return (H₁, H₂)
//}
//@inlinable // SOS
//func chebyshev2(hpf n: Int, ε: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
//	let β = sinh(asinh(recip(ε)) / .init(n))
//	let H₁ = n.isMultiple(of: 2) ? [] : [
//		(SIMD2<Float64>(1, 0), SIMD2<Float64>(1, β))
//	]
//	let H₂ = (0..<n/2).map {
//		let θ = Float64(n - 2 * $0 - 1) / Float64(2 * n)
//		let e = __sincospi_stret(θ)
//		let αₖ = 2 * β * e.__cosval
//		let γₖ = e.__sinval * e.__sinval
//		let βₖ = fma(β, β, γₖ)
//		return (SIMD3<Float64>(1, 0, γₖ), SIMD3<Float64>(1, αₖ, βₖ))
//	}
//	return (H₁, H₂)
//}
//public func filter(_ source: Stream, lpf ω₀: some Publisher<(Int, Frequency), Never>, chebyshev2 order: Int, ε: Float64) -> some Stream {
//	let (H₁, H₂) = chebyshev2(lpf: order, ε: ε)
//	return filter(source, sos: ω₀.map {
//		($0, Prototype.SOS(ω₀: $1, H₁: H₁, H₂: H₂))
//	}, length: order)
//}
//public func filter(_ source: Stream, lpf ω₀: some Sequence<Frequency>, chebyshev2 order: Int, ε: Float64) -> some Stream {
//	filter(source, lpf: ω₀.prefix(count: source.count), chebyshev2: order, ε: ε)
//}
//public func filter(_ source: Stream, lpf ω₀: some Publisher<Frequency, Never>, chebyshev2 order: Int, ε: Float64) -> some Stream {
//	filter(source, lpf: ω₀.repeat(count: source.count), chebyshev2: order, ε: ε)
//}
//public func filter(_ source: Stream, lpf ω₀: Frequency, chebyshev2 order: Int, ε: Float64) -> some Stream {
//	filter(source, lpf: `repeat`(ω₀, count: source.count), chebyshev2: order, ε: ε)
//}
//public func filter(_ source: Stream, hpf ω₀: some Publisher<(Int, Frequency), Never>, chebyshev2 order: Int, ε: Float64) -> some Stream {
//	let (H₁, H₂) = chebyshev2(hpf: order, ε: ε)
//	return filter(source, sos: ω₀.map {
//		($0, Prototype.SOS(ω₀: $1, H₁: H₁, H₂: H₂))
//	}, length: order)
//}
//public func filter(_ source: Stream, hpf ω₀: some Sequence<Frequency>, chebyshev2 order: Int, ε: Float64) -> some Stream {
//	filter(source, hpf: ω₀.prefix(count: source.count), chebyshev2: order, ε: ε)
//}
//public func filter(_ source: Stream, hpf ω₀: some Publisher<Frequency, Never>, chebyshev2 order: Int, ε: Float64) -> some Stream {
//	filter(source, hpf: ω₀.repeat(count: source.count), chebyshev2: order, ε: ε)
//}
//public func filter(_ source: Stream, hpf ω₀: Frequency, chebyshev2 order: Int, ε: Float64) -> some Stream {
//	filter(source, hpf: `repeat`(ω₀, count: source.count), chebyshev2: order, ε: ε)
//}
// MARK: Elliptic
//@inlinable
//func elliptic(k: Float64) -> Float64 {
//	0.5 * .pi / sequence(first: (1.0, sqrt(fma(-k, k, 1)))) {
//		if .ulpOfOne < ($0 - $1).magnitude {
//			.some((0.5 * ($0 + $1), sqrt($0 * $1)))
//		} else {
//			.none
//		}
//	}.suffix(1).last.unsafelyUnwrapped.0
//}
//@inlinable
//func elliptic(u: Float64, k: Float64) -> (sn: Float64, cn: Float64, dn: Float64) {
//	switch k {
//	case 0.0:
//		let e = __sincos_stret(u)
//		return (e.__sinval, e.__cosval, 1.0)
//	case 1.0:
//		let sech = recip(cosh(u))
//		return (tanh(u), sech, sech)
//	default:
//		func yₙ(aₖ: Float64, bₖ: Float64) -> Float64 {
//			let aₙ = 0.5 * (aₖ + bₖ)
//			let bₙ = sqrt(aₖ * bₖ)
//			let cₙ = 0.5 * (aₖ - bₖ)
//			let yₙ = if .ulpOfOne < cₙ.magnitude {
//				yₙ(aₖ: aₙ, bₖ: bₙ)
//			} else {
//				aₙ / sin(aₙ * u)
//			}
//			return yₙ + aₙ * cₙ / yₙ
//		}
//		let a₀ = 1.0
//		let b₀ = sqrt(1 - k * k)
//		let y₁ = yₙ(aₖ: 0.5 * (a₀ + b₀), bₖ: sqrt(a₀ * b₀))
//		let sn = y₁ / length_squared(.init(y₁, 0.5 * k))
//		let cn = sqrt(fma(-sn, sn, 1))
//		let dn = sqrt(fma(-sn*k, sn*k, 1))
//		return (sn, cn, dn)
//	}
//}
//@inlinable
//func asn(x: Float64, k: Float64) -> Float64 {
//	switch k {
//	case 0:
//		return asin(x)
//	case 1:
//		return atanh(x)
//	default:
//		let y = switch x.magnitude {
//		case let x where x * x < 0.5:
//			Quadrature(integrator: .qng).integrate(over: 0 ... x) {
//				vDSP.evaluatePolynomial(usingCoefficients: [k * k, 0, -fma(k, k, 1), 0, 1],
//										withVariables: $0,
//										result: &$1[$1.startIndex..<$1.endIndex])
//				vForce.rsqrt($1, result: &$1[$1.startIndex..<$1.endIndex])
//			}
//		case let x:
//			Quadrature(integrator: .qng).integrate(over: 0 ... asin(x)) {
//				vForce.sin($0, result: &$1[$1.startIndex..<$1.endIndex])
//				vDSP.square($1, result: &$1[$1.startIndex..<$1.endIndex])
//				vDSP.add(multiplication: ($1, -k*k), 1, result: &$1[$1.startIndex..<$1.endIndex])
//				vForce.rsqrt($1, result: &$1[$1.startIndex..<$1.endIndex])
//			}
//		}
//		switch y {
//		case.success(let s):
//			return copysign(s.integralResult, x)
//		case.failure(let e):
//			os_log(.error, log: .default, "%{public}@", e.errorDescription)
//			return.nan
//		}
//	}
//}
//@inlinable
//func acn(y: Float64, k: Float64) -> Float64 {
//	asn(x: sqrt(fma(-y, y, 1)), k: k)
//}
//@inlinable
//func adn(z: Float64, k: Float64) -> Float64 {
//	asn(x: sqrt(fma( z, z, 1))/k, k: k)
//}
//@inlinable
//func asc(w: Float64, k: Float64) -> Float64 {
//	asn(x: w / hypot(w, 1), k: k)
//}
//@inlinable
//func elliptic(prime target: Float64) -> Float64 {
//	let πv = -target * .pi
//	let ng = (0...).lazy.map {
//		exp(πv * Float64($0 * $0 + $0))
//	}
//	let dg = (1...).lazy.map {
//		exp(πv * Float64($0 * $0))
//	}
//	let nv = ng.prefix {
//		.ulpOfOne < $0
//	}.reduce(0) {
//		$0 + $1
//	}
//	let dv = dg.prefix {
//		.ulpOfOne < $0
//	}.reduce(1) {
//		fma(2, $1, $0)
//	}
//	return exp(0.5 * πv) * (2*nv/dv) * (2*nv/dv)
//}
//@inlinable
//func cauer(lpf n: Int, ε: Float64, η: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
//	let k₁́ = ε / η
//	let K₁́ = elliptic(k: k₁́)
//	let k₁ = elliptic(prime: elliptic(k: sqrt(1 - k₁́ * k₁́)) / K₁́ / .init(n))
//	let K₁ = elliptic(k: k₁)
//	let v₀ = asc(w: 1 / ε, k: k₁) / .init(n)
//	let (snₖ́, cnₖ́, dnₖ́) = elliptic(u: v₀ * K₁ / K₁́, k: sqrt(1 - k₁ * k₁))
//	let H₁ = n.isMultiple(of: 2) ? [] : [
//		(SIMD2<Float64>(0, 1), SIMD2<Float64>(fma(-snₖ́, snₖ́, 1) / (snₖ́ * cnₖ́), 1))
//	]
//	let H₂ = (0..<n/2).map {
//		let uₖ = Float64(n - 2 * $0 - 1) / Float64(n) * K₁
//		let (snₖ, cnₖ, dnₖ) = elliptic(u: uₖ, k: k₁)
//		let zᵣ = 0.0
//		let zᵢ = recip(k₁ * snₖ)
//		let pᵣ = (cnₖ * dnₖ * snₖ́ * cnₖ́) / fma(-dnₖ * dnₖ, snₖ́ * snₖ́, 1)
//		let pᵢ = (snₖ * dnₖ́) / fma(-dnₖ * dnₖ, snₖ́ * snₖ́, 1)
//		let βₖ = length_squared(.init(zᵣ, zᵢ))
//		let αₖ = length_squared(.init(pᵣ, pᵢ))
//		return (SIMD3<Float64>(recip(βₖ), 0, 1), SIMD3<Float64>(recip(αₖ), 2.0 * pᵣ / αₖ, 1))
//	}
//	return (H₁, H₂)
//}
//@inlinable
//func cauer(hpf n: Int, ε: Float64, η: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
//	let k₁́ = ε / η
//	let K₁́ = elliptic(k: k₁́)
//	let k₁ = elliptic(prime: elliptic(k: sqrt(1 - k₁́ * k₁́)) / K₁́ / .init(n))
//	let K₁ = elliptic(k: k₁)
//	let v₀ = asc(w: 1 / ε, k: k₁) / .init(n)
//	let (snₖ́, cnₖ́, dnₖ́) = elliptic(u: v₀ * K₁ / K₁́, k: sqrt(1 - k₁ * k₁))
//	let H₁ = n.isMultiple(of: 2) ? [] : [
//		(SIMD2<Float64>(1, 0), SIMD2<Float64>(1, fma(-snₖ́, snₖ́, 1) / (snₖ́ * cnₖ́)))
//	]
//	let H₂ = (0..<n/2).map {
//		let uₖ = Float64(n - 2 * $0 - 1) / Float64(n) * K₁
//		let (snₖ, cnₖ, dnₖ) = elliptic(u: uₖ, k: k₁)
//		let zᵣ = 0.0
//		let zᵢ = recip(k₁ * snₖ)
//		let pᵣ = (cnₖ * dnₖ * snₖ́ * cnₖ́) / fma(-dnₖ * dnₖ, snₖ́ * snₖ́, 1)
//		let pᵢ = (snₖ * dnₖ́) / fma(-dnₖ * dnₖ, snₖ́ * snₖ́, 1)
//		let βₖ = length_squared(.init(zᵣ, zᵢ))
//		let αₖ = length_squared(.init(pᵣ, pᵢ))
//		return (SIMD3<Float64>(1, 0, recip(βₖ)), SIMD3<Float64>(1, 2.0 * pᵣ / αₖ, recip(αₖ)))
//	}
//	return (H₁, H₂)
//}
//public func filter(_ source: Stream, lpf ω₀: some Publisher<(Int, Frequency), Never>, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
//	let (H₁, H₂) = cauer(lpf: order, ε: ε, η: η)
//	return filter(source, sos: ω₀.map {
//		($0, Prototype.SOS(ω₀: $1, H₁: H₁, H₂: H₂))
//	}, length: order)
//}
//public func filter(_ source: Stream, lpf ω₀: some Sequence<Frequency>, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
//	filter(source, lpf: ω₀.prefix(count: source.count), cauer: order, ε: ε, η: η)
//}
//public func filter(_ source: Stream, lpf ω₀: some Publisher<Frequency, Never>, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
//	filter(source, lpf: ω₀.repeat(count: source.count), cauer: order, ε: ε, η: η)
//}
//public func filter(_ source: Stream, lpf ω₀: Frequency, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
//	filter(source, lpf: `repeat`(ω₀, count: source.count), cauer: order, ε: ε, η: η)
//}
//public func filter(_ source: Stream, hpf ω₀: some Publisher<(Int, Frequency), Never>, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
//	let (H₁, H₂) = cauer(hpf: order, ε: ε, η: η)
//	return filter(source, sos: ω₀.map {
//		($0, Prototype.SOS(ω₀: $1, H₁: H₁, H₂: H₂))
//	}, length: order)
//}
//public func filter(_ source: Stream, hpf ω₀: some Sequence<Frequency>, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
//	filter(source, hpf: ω₀.prefix(count: source.count), cauer: order, ε: ε, η: η)
//}
//public func filter(_ source: Stream, hpf ω₀: some Publisher<Frequency, Never>, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
//	filter(source, hpf: ω₀.repeat(count: source.count), cauer: order, ε: ε, η: η)
//}
//public func filter(_ source: Stream, hpf ω₀: Frequency, cauer order: Int, ε: Float64, η: Float64) -> some Stream {
//	filter(source, hpf: `repeat`(ω₀, count: source.count), cauer: order, ε: ε, η: η)
//}
// MARK: Optimum "L" filter / Legendre–Papoulis
// MARK: Linkwitz–Riley filter
