//
//  Filters.swift
//  MUTE
//
//  Created by Kota on 7/24/R7.
//
import Testing
import CoreFoundation
import NSP
import simd
@Suite
struct FiltersTestCase {
	@discardableResult
	func measure<R>(name: String = #function, body: () throws -> R) rethrows -> R {
		let start = CFAbsoluteTimeGetCurrent()
		defer {
			let end = CFAbsoluteTimeGetCurrent()
			print(end - start)
		}
		return try body()
	}
	@Test
	func ddot() {
		let x = Array<Float64>(unsafeUninitializedCapacity: 2048 * 1024) {
			var lo = -1.0
			var hi =  1.0
			uniform_rng($0.baseAddress.unsafelyUnwrapped, 2048, &lo, 0, &hi, 0, 1024, 1024)
			$1 = $0.count
		}
		let θ = 0.1
		let c = __cospi(θ)
		let r = 0.5
		let b = [r * r, -2 * r * c, 1] as Array<Float64>
		let a = [1, -2 * r * c, r * r] as Array<Float64>
		let _ = Array<Float64>(unsafeUninitializedCapacity: x.count) {
			let object = universal_filter_create(3, 3, 2048)
			defer {
				universal_filter_destroy(object)
			}
			let y = $0.baseAddress.unsafelyUnwrapped
			for _ in 0..<10 {
				measure {
					universal_filter_matrix(object, b, 1, a, 1, x, 1024, y, 1024, 1024)
				}
			}
			$1 = $0.count
		}
	}
	@Test
	func gemv() {
		let x = Array<Float64>(unsafeUninitializedCapacity: 2048 * 1024) {
			var lo = -1.0
			var hi =  1.0
			uniform_rng($0.baseAddress.unsafelyUnwrapped, 2048, &lo, 0, &hi, 0, 1024, 1024)
			$1 = $0.count
		}
		let θ = 0.1
		let c = __cospi(θ)
		let r = 0.5
		let b = [r * r, -2 * r * c, 1] as Array<Float64>
		let a = [1, -2 * r * c, r * r] as Array<Float64>
		let _ = Array<Float64>(unsafeUninitializedCapacity: x.count) {
			let object = universal_filter_create(3, 3, 2048)
			defer {
				universal_filter_destroy(object)
			}
			let y = $0.baseAddress.unsafelyUnwrapped
			for _ in 0..<10 {
				measure {
					universal_filter_matrix(object, b, 1, a, 1, x, 1024, y, 1024, 1024)
				}
			}
			$1 = $0.count
		}
	}
	@Test
	func svf() {
		let N = 1024
		var noise = Array<Float64>.init(unsafeUninitializedCapacity: N * 3) {
//			var a = -1 as Float64
//			var b =  1 as Float64
//			uniform_f64($0.baseAddress.unsafelyUnwrapped, N, &a, 0, &b, 0, 1, N)
			$0.initialize(repeating: .zero)
			$0[0] = 1
			$1 = $0.count
		}
		var s = SIMD2<Float64>()
		state_variable_filter_static(noise, &noise, N, 0.25, 4, &s, N)
		print(noise)
	}
}
