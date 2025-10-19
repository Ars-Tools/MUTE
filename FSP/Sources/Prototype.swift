//
//  Prototype.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func Accelerate.vecLib.dgemm_
import func Accelerate.vecLib.dgemv_
import func Accelerate.vecLib.vvpows
import typealias CoreMedia.CMTime
import protocol DSP.Stream
import protocol DSP.Frequency
import protocol DSP.Kernel
import typealias DSP.Instance
import func simd.__tanpi
@preconcurrency import protocol Combine.Publisher
@usableFromInline
enum Prototype {
	@usableFromInline
	struct Kernel {
		@usableFromInline let ω₀: Frequency
		@usableFromInline let Kₛ: Array<Float64>
	}
	@usableFromInline
	struct BLT {
		@usableFromInline let ω₀: Stream
		@usableFromInline let Bₛ: Array<Float64>
		@usableFromInline let Aₛ: Array<Float64>
	}
}
extension Prototype.Kernel: DSP.Kernel {
	@inlinable
	func coefficients(for Tₛ: CMTime) -> Array<Float64> {
		var n = Kₛ.count
		let K = __tanpi(ω₀.increment(for: Tₛ))
		return.init(unsafeUninitializedCapacity: 3 * n * n + 2 * n) {
			let y = $0.extracting(0 * n ..< 1 * n)
			let x = $0.extracting(1 * n ..< 2 * n)
			let z = $0.extracting(2 * n + 0 * n * n ..< 2 * n + 1 * n * n)
			let l = $0.extracting(2 * n + 1 * n * n ..< 2 * n + 2 * n * n)
			let r = $0.extracting(2 * n + 2 * n * n ..< 2 * n + 3 * n * n)
			$0.initialize(repeating: .zero)
			x[0] = 1
			l[0] = 1
			r[0] = 1
			for (k, j) in stride(from: 0, to: n * n, by: n).dropLast().enumerated() {
				x[k+1] = x[k] * K
				l[l[n+j..<n+j+k+1].initialize(fromContentsOf: l[j..<j+k+1])] = .zero
				r[r[n+j..<n+j+k+1].initialize(fromContentsOf: r[j..<j+k+1])] = .zero
				vDSP.add(     l[n+j+1..<n+j+k+2], l[j..<j+k+1], result: &l[n+j+1..<n+j+k+2])
				vDSP.subtract(r[n+j+1..<n+j+k+2], r[j..<j+k+1], result: &r[n+j+1..<n+j+k+2])
			}
			for (p, q) in (0..<n).reversed().enumerated() {
				let l = l[p*n...p*n+p]
				let r = r[q*n...q*n+q]
				for (s, t) in l.enumerated() {
					for (u, v) in r.enumerated() {
						z[p*n+s+u] += t * v
					}
				}
			}
			vDSP.multiply(x, Kₛ, result: &x[x.startIndex..<x.endIndex])
			var α = 1.0
			var β = 0.0
			var k = 1
			dgemv_("N",
				   &n, &n,
				   &α,
				   z.baseAddress, &n,
				   x.baseAddress, &k,
				   &β,
				   y.baseAddress, &k)
			$1 = n
		}
	}
	@inlinable
	var count: Int {
		Kₛ.count
	}
}
extension Prototype.BLT: DSP.Stream {
	@inlinable
	var count: Int {
		2 * max(Bₛ.count, Aₛ.count)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		guard ω₀.count == 1 else { throw Error.invalidChannel }
		guard Bₛ.count == Aₛ.count else { throw Error.unmatchChannel }
		switch max(Bₛ.count, Aₛ.count) {
		case 1:
			return {
				for var target in zip(stride(from: 0, to: $3, by: $3).lazy.map($2.advanced(by:)), CollectionOfOne($1)).map(UnsafeMutableBufferPointer.init) {
					vDSP.fill(&target, with: 1)
				}
			}
		case let n:
			let xₖ = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let Tₛ = interval.seconds
			let Mₛ = withUnsafeTemporaryAllocation(of: Int32.self, capacity: 3 * n * n) {
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
				return vDSP.integerToFloatingPoint($0.prefix(n * n), floatingPointType: Float64.self)
			}
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: n * length) {
					guard let source = $0.baseAddress else { return }
					xₖ(moment, length, source, length)
					vDSP.multiply(Tₛ, $0[0..<length], result: &$0[0..<length])
					vForce.tanPi($0[0..<length], result: &$0[0..<length])
					for offset in (0..<n).reversed() {
						var count = Int32(length)
						var power = Float64(offset)
						vvpows(source.advanced(by: offset * length), &power, source, &count)
					}
					var m = length
					var n = n
					var k = n
					var α = 1.0
					var β = 0.0
					for (bₖ, bₛ) in Bₛ.enumerated() {
						vDSP.multiply(bₛ,
									  $0[(bₖ) * length ..< (bₖ + 1) * length],
									  result: &UnsafeMutableBufferPointer(start: target.advanced(by: (n+bₖ) * stride), count: length)[0..<length])
					}
					do {
						var lda = stride
						var ldb = n
						var ldc = stride
						dgemm_("N", "T",
							   &m, &n, &k,
							   &α,
							   target.advanced(by: n * stride), &lda,
							   Mₛ, &ldb,
							   &β,
							   target, &ldc)
					}
					for (aₖ, aₛ) in Aₛ.enumerated() {
						vDSP.multiply(aₛ,
									  $0[(aₖ) * length ..< (aₖ + 1) * length],
									  result: &UnsafeMutableBufferPointer(start: source.advanced(by: aₖ * length), count: length)[0..<length])
					}
					do {
						var lda = length
						var ldb = n
						var ldc = stride
						dgemm_("N", "T",
							   &m, &n, &k,
							   &α,
							   source, &lda,
							   Mₛ, &ldb,
							   &β,
							   target.advanced(by: n * stride), &ldc)
					}
				}
			}
		}
	}
}
