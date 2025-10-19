//
//  Prototype.swift
//  MUTE
//
//  Created by Kota on 8/9/R7.
//
import Testing
import simd
@testable import DSP
//@Suite
//struct PrototypeTestCases {
//	func to(scipy sos: Array<Float64>) -> Array<Array<Float64>> {
//		stride(from: 0, to: sos.count, by: 5).map {
//			let w = sos[$0..<$0+5]
//			let b = w.prefix(3)
//			let a = [1] + w.suffix(2)
//			return b + a
//		}
//	}
//	@Test
//	func butterworth_bpf() {	
//		let (H₁, H₂) = DSP.butterworth(bpf: 32)
//		let sos = Prototype.SOS(ω₀: 1, H₁: H₁, H₂: H₂).coefficients(for: .init(value: 1, timescale: 8))
//		print(to(scipy: sos))
//	}
//	@Test
//	func chebyshev1_lpf() {
//		let (H₁, H₂) = DSP.chebyshev1(lpf: 6, ε: 0.25) // / sqrt(1 + ε^ 2)
//		let sos = Prototype.SOS(ω₀: 5, H₁: H₁, H₂: H₂).coefficients(for: .init(value: 1, timescale: 16))
//		print(to(scipy: sos))
//	}
//	@Test
//	func chebyshev2_lpf() {
//		let (H₁, H₂) = DSP.chebyshev2(lpf: 4, ε: 0.05) // / sqrt(ε^ 2 / (1 + ε^ 2))
//		let sos = Prototype.SOS(ω₀: 5, H₁: H₁, H₂: H₂).coefficients(for: .init(value: 1, timescale: 16))
//		print(to(scipy: sos))
//	}
//	func cauer2(lpf n: Int, Rp: Float64, Rs: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
//		let ε = sqrt(1/Rp/Rp - 1)
//		let k₁ = ε / sqrt(1/Rs/Rs - 1)
//		let k = sqrt(1 - k₁ * k₁)
//		let K = elliptic(k: k)
//		let K₁ = elliptic(k: k₁)
//		let v₀ = asc(w: 1 / ε, k: k₁) / .init(n)
//		let H₁ = n.isMultiple(of: 2) ? [] : [
//			(SIMD2<Float64>(0, 1), SIMD2<Float64>(1, 0))
//		]
//		let H₂ = (0..<n/2).map {
//			let θₖ = Float64(n - 2 * $0 - 1) / Float64(n)
//			let uₖ = θₖ * K
//			let (snₖ, cnₖ, dnₖ) = elliptic(u: uₖ, k: k)
//			let (snₖ́, cnₖ́, dnₖ́) = elliptic(u: v₀ * K / K₁, k: sqrt(1 - k * k))
//			let zᵣ = 0.0
//			let zᵢ = dnₖ / cnₖ / k
//			let β₀ = 1.0
//			let β₁ = 0.0
//			let β₂ = zᵣ * zᵣ + zᵢ * zᵢ
//			let pᵣ = (cnₖ * dnₖ * snₖ́ * cnₖ́) / (1 - dnₖ * dnₖ * snₖ́ * snₖ́)
//			let pᵢ = (snₖ * dnₖ́) / (1 - dnₖ * dnₖ * snₖ́ * snₖ́)
//			let α₀ = 1.0
//			let α₁ = 2.0 * pᵣ
//			let α₂ = pᵣ * pᵣ + pᵢ * pᵢ
//			return (SIMD3<Float64>(β₀, β₁, β₂), SIMD3<Float64>(α₀, α₁, α₂))
//		}
//		return (H₁, H₂)
//	}
//	func cauer(lpf n: Int, Rp: Float64, Rs: Float64) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
//		let ε = sqrt(expm1(0.1 * Rp * M_LN10))
//		let k₁́ = ε / sqrt(expm1(0.1 * Rs * M_LN10))
//		let K₁́ = elliptic(k: k₁́)
//		let k₁ = elliptic(prime: elliptic(k: sqrt(1 - k₁́ * k₁́)) / K₁́ / .init(n))
//		let K₁ = elliptic(k: k₁)
//		let v₀ = asc(w: 1 / ε, k: k₁) / .init(n)
//		let (snₖ́, cnₖ́, dnₖ́) = elliptic(u: v₀ * K₁ / K₁́, k: sqrt(1 - k₁ * k₁))
//		let H₁ = n.isMultiple(of: 2) ? [] : [
//			(SIMD2<Float64>(0, 1), SIMD2<Float64>(fma(-snₖ́, snₖ́, 1) / (snₖ́ * cnₖ́), 1))
//		]
//		let H₂ = (0..<n/2).map {
//			let uₖ = Float64(n - 2 * $0 - 1) / Float64(n) * K₁
//			let (snₖ, cnₖ, dnₖ) = elliptic(u: uₖ, k: k₁)
//			let zᵣ = 0.0
//			let zᵢ = recip(k₁ * snₖ)
//			let pᵣ = (cnₖ * dnₖ * snₖ́ * cnₖ́) / fma(-dnₖ * dnₖ, snₖ́ * snₖ́, 1)
//			let pᵢ = (snₖ * dnₖ́) / fma(-dnₖ * dnₖ, snₖ́ * snₖ́, 1)
//			let βₖ = length_squared(.init(zᵣ, zᵢ))
//			let αₖ = length_squared(.init(pᵣ, pᵢ))
//			return (SIMD3<Float64>(1 / βₖ, 0, 1), SIMD3<Float64>(1 / αₖ, 2.0 * pᵣ / αₖ, 1))
//		}
//		return (H₁, H₂)
//	}
//	@Test
//	func elliptic_lpf() {
//		let (H₁, H₂) = cauer(lpf: 12, Rp: 2, Rs: 20)
//		print(H₁, H₂)
//		let sos = Prototype.SOS(ω₀: 5, H₁: H₁, H₂: H₂).coefficients(for: .init(value: 1, timescale: 16))
//		print(to(scipy: sos))
//	}
//	@Test
//	func matrix() {
//		print(Prototype.Matrix(2))
//		print(Prototype.Poly.Matrix(2))
//		print(Prototype.Matrix(3))
//		print(Prototype.Poly.Matrix(3))
//	}
//}
