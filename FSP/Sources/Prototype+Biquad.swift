//
//  Prototype+Biquad.swift
//  MUTE
//
//  Created by Kota on 8/14/R7.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func Accelerate.vecLib.dgemm_
import func Accelerate.vecLib.vDSP_biquadm_CreateSetupD
import func Accelerate.vecLib.vDSP_biquadm_DestroySetupD
import func Accelerate.vecLib.vDSP_biquadm_SetCoefficientsDoubleD
import func Accelerate.vecLib.vDSP_biquadmD
import typealias CoreMedia.CMTime
import protocol DSP.Stream
import protocol DSP.Frequency
import typealias DSP.Instance
import typealias Auxiliary.Autorelease
import func NSP.biquad_filter_create
import func NSP.biquad_filter_destroy
import func NSP.biquad_filter_active
import simd
@preconcurrency import protocol Combine.Publisher
extension Prototype {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Frequency), Never> & Sendable> {
		@usableFromInline let x₀: Stream
		@usableFromInline let ω₀: Signal
		@usableFromInline let H₁: Array<(SIMD2<Float64>, SIMD2<Float64>)>
		@usableFromInline let H₂: Array<(SIMD3<Float64>, SIMD3<Float64>)>
	}
	@usableFromInline
	struct Ar {
		@usableFromInline let x₀: Stream
		@usableFromInline let ω₀: Stream
		@usableFromInline let H₁: Array<(SIMD2<Float64>, SIMD2<Float64>)>
		@usableFromInline let H₂: Array<(SIMD3<Float64>, SIMD3<Float64>)>
	}
}
extension Prototype.Kr: Stream {
	@inlinable
	var count: Int {
		x₀.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xₖ = try x₀(interval: interval, capacity: capacity, instance: &instance)
		let stream = x₀.count
        let object = switch vDSP_biquadm_CreateSetupD(repeatElement([1,0,0,0,0], count: x₀.count * (H₁.count + H₂.count)).flatMap(\.self), .init(H₁.count + H₂.count), .init(stream)) {
        case.some(let opaque):
            Autorelease.Opaque(pointer: opaque, release: vDSP_biquadm_DestroySetupD)
        case.none:
            throw Error.failedToAllocate(OpaquePointer.self)
        }
		let cancel = ω₀.sink {
			switch $0 {
			case 0..<stream:
				let K = __tanpi($1.increment(for: interval))
				let Z₁ = simd_double2x2(columns: (.init(1, -1), .init(K, K)))
				let Z₂ = simd_double3x3(columns: (.init(1, -2, 1), .init(K, 0, -K), .init(1, 2, 1) * K * K))
				let Zₛ = H₂.reduce(into: H₁.flatMap {
					let a = Z₁ * $1
					let b = Z₁ * $0 / a.x
					return [b.x, b.y, 0, a.y / a.x, 0]
				}) {
					let b = Z₂ * $1.0
					let a = Z₂ * $1.1
					let b̕ = b / a.x
					let a̕ = a / a.x
					$0.append(b̕.x)
					$0.append(b̕.y)
					$0.append(b̕.z)
					assert((a̕.x - 1).magnitude < .ulpOfOne)
					$0.append(a̕.y)
					$0.append(a̕.z)
				} as Array<Float64>
				assert(Zₛ.count.isMultiple(of: 5))
				vDSP_biquadm_SetCoefficientsDoubleD(object.pointer,
													Zₛ,
													0, .init($0),
													.init(Zₛ.count / 5), 1)
			default:
				assertionFailure("out of range")
			}
		}
		return { [cancel] in
			xₖ($0, $1, $2, $3)
			var x = stride(from: 0, to: stream * $3, by: $3).map(UnsafePointer($2).advanced(by:))
			var y = stride(from: 0, to: stream * $3, by: $3).map($2.advanced(by:))
			vDSP_biquadmD(object.pointer,
						  &x, 1,
						  &y, 1,
						  .init($1))
		}
	}
}
extension Prototype.Ar: Stream {
	@inlinable
	var count: Int {
		x₀.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		guard ω₀.count == 1 else { throw Error.invalidChannel }
		let Tₛ = interval.seconds
		let xₖ = try x₀(interval: interval, capacity: capacity, instance: &instance)
		let ωₖ = try ω₀(interval: interval, capacity: capacity, instance: &instance)
		let f₁ = repeatElement(x₀.count, count: H₁.count).map {
			Autorelease.Object(object: biquad_filter_create($0)) {
				biquad_filter_destroy($0)
			}
		}
		let f₂ = repeatElement(x₀.count, count: H₂.count).map {
			Autorelease.Object(object: biquad_filter_create($0)) {
				biquad_filter_destroy($0)
			}
		}
		let Z₁ = [1, -1, 1, 1] as Array<Float64>
		let Z₂ = [1, -2, 1, 1, 0, -1, 1, 2, 1] as Array<Float64>
		return { moment, length, target, stride in
			// X
			xₖ(moment, length, target, stride)
			// Y
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: 11 * length) {
				let B = $0.extracting(0*length..<3*length)
				let A = $0.extracting(3*length..<6*length)
				let W = $0.extracting(6*length..<9*length)
				let Z = $0.extracting(9*length..<$0.count)
				var β = 0.0
				var α = 1.0
				// Z
				ωₖ(moment, length, Z.baseAddress.unsafelyUnwrapped, length)
				vDSP.multiply(Tₛ, Z[0..<length], result: &Z[0..<length])
				vForce.tanPi(Z[0..<length], result: &Z[0..<length])
				vDSP.square(Z[0..<length], result: &Z[length..<2*length])
				// H1
				do {
					var m = length
					var n = 2
					var k = 2
					var lda = length
					var ldb = 2
					var ldc = length
					vDSP.clear(&B[2*length..<3*length])
					vDSP.clear(&A[2*length..<3*length])
					for (f, h) in zip(f₁, H₁) {
						// B
						vDSP.fill(&W[0..<length], with: h.0.x)
						vDSP.multiply(h.0.y, Z[0..<length], result: &W[length..<2*length])
						dgemm_("N", "T",
							   &m, &n, &k,
							   &α,
							   W.baseAddress, &lda,
							   Z₁, &ldb,
							   &β,
							   B.baseAddress, &ldc)
						// A
						vDSP.fill(&W[0..<length], with: h.1.x)
						vDSP.multiply(h.1.y, Z[0..<length], result: &W[length..<2*length])
						dgemm_("N", "T",
							   &m, &n, &k,
							   &α,
							   W.baseAddress, &lda,
							   Z₁, &ldb,
							   &β,
							   A.baseAddress, &ldc)
						// Y
						biquad_filter_active(f.reference,
											 B.baseAddress.unsafelyUnwrapped, length,
											 A.baseAddress.unsafelyUnwrapped, length,
											 target, stride,
											 target, stride,
											 length)
					}
				}
				// H2
				do {
					var m = length
					var n = 3
					var k = 3
					var lda = length
					var ldb = 3
					var ldc = length
					for (f, h) in zip(f₂, H₂) {
						vDSP.fill(&W[0..<length], with: h.0.x)
						vDSP.multiply(h.0.y, Z[0*length..<1*length], result: &W[1*length..<2*length])
						vDSP.multiply(h.0.z, Z[1*length..<2*length], result: &W[2*length..<3*length])
						dgemm_("N", "T",
							   &m, &n, &k,
							   &α,
							   W.baseAddress, &lda,
							   Z₂, &ldb,
							   &β,
							   B.baseAddress, &ldc)
						vDSP.fill(&W[0..<length], with: h.1.x)
						vDSP.multiply(h.1.y, Z[0*length..<1*length], result: &W[1*length..<2*length])
						vDSP.multiply(h.1.z, Z[1*length..<2*length], result: &W[2*length..<3*length])
						dgemm_("N", "T",
							   &m, &n, &k,
							   &α,
							   W.baseAddress, &lda,
							   Z₂, &ldb,
							   &β,
							   A.baseAddress, &ldc)
						biquad_filter_active(f.reference,
											 B.baseAddress.unsafelyUnwrapped, length,
											 A.baseAddress.unsafelyUnwrapped, length,
											 target, stride,
											 target, stride,
											 length)
					}
				}
			}
		}
	}
}
public func filter(_ source: Stream, alt ω₀: some Publisher<(Int, Frequency), Never> & Sendable, Hₛ: some Sequence<(SIMD3<Float64>, SIMD3<Float64>)>) -> some Stream {
	Prototype.Kr(x₀: source, ω₀: ω₀, H₁: .init(), H₂: .init(Hₛ))
}
public func filter(_ source: Stream, alt ω₀: some Publisher<(Int, Frequency), Never> & Sendable, Hₛ: (SIMD3<Float64>, SIMD3<Float64>)...) -> some Stream {
	Prototype.Kr(x₀: source, ω₀: ω₀, H₁: .init(), H₂: Hₛ)
}
public func filter(_ source: Stream, alt ω₀: some Publisher<Frequency, Never>, Hₛ: some Sequence<(SIMD3<Float64>, SIMD3<Float64>)>) -> some Stream {
	Prototype.Kr(x₀: source, ω₀: ω₀.repeat(count: source.count), H₁: .init(), H₂: .init(Hₛ))
}
public func filter(_ source: Stream, alt ω₀: some Publisher<Frequency, Never>, Hₛ: (SIMD3<Float64>, SIMD3<Float64>)...) -> some Stream {
	Prototype.Kr(x₀: source, ω₀: ω₀.repeat(count: source.count), H₁: .init(), H₂: Hₛ)
}
public func filter(_ source: Stream, alt ω₀: some Sequence<Frequency>, Hₛ: some Sequence<(SIMD3<Float64>, SIMD3<Float64>)>) -> some Stream {
	Prototype.Kr(x₀: source, ω₀: ω₀.prefix(count: source.count), H₁: .init(), H₂: .init(Hₛ))
}
public func filter(_ source: Stream, alt ω₀: some Sequence<Frequency>, Hₛ: (SIMD3<Float64>, SIMD3<Float64>)...) -> some Stream {
	Prototype.Kr(x₀: source, ω₀: ω₀.prefix(count: source.count), H₁: .init(), H₂: Hₛ)
}
public func filter(_ source: Stream, alt ω₀: Stream, Hₛ: some Collection<(SIMD3<Float64>, SIMD3<Float64>)>) -> some Stream {
	Prototype.Ar(x₀: source, ω₀: ω₀, H₁: .init(), H₂: .init(Hₛ))
}
public func filter(_ source: Stream, alt ω₀: Frequency, Hₛ: some Sequence<(SIMD3<Float64>, SIMD3<Float64>)>) -> some Stream {
	Prototype.Kr(x₀: source, ω₀: `repeat`(ω₀, count: source.count), H₁: .init(), H₂: .init(Hₛ))
}
public func filter(_ source: Stream, alt ω₀: Frequency, Hₛ: (SIMD3<Float64>, SIMD3<Float64>)...) -> some Stream {
	Prototype.Kr(x₀: source, ω₀: `repeat`(ω₀, count: source.count), H₁: .init(), H₂: Hₛ)
}
public func filter(_ source: Stream, alt ω₀: Stream, Hₛ: (SIMD3<Float64>, SIMD3<Float64>)...) -> some Stream {
	Prototype.Ar(x₀: source, ω₀: ω₀, H₁: .init(), H₂: Hₛ)
}
