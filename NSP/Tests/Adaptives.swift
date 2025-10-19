//
//  Adaptives.swift
//  MUTE
//
//  Created by Kota on 8/15/R7.
//
import Testing
import Accelerate
@testable import NSP
@Suite
struct ARTestCase {
	func parcor(ar c: Array<Float64>) -> Array<Float64> {
		.init(sequence(state: c) { a in
			switch a.popLast() {
			case.some(let k):
				var r = a
				vDSP.reverse(&r)
				vDSP.add(multiplication: (r, -k), a, result: &r)
				vDSP.divide(r, fma(-k, k, 1), result: &r)
				a = r
				return.some(k)
			case.none:
				return.none
			}
		})
	}
	@Test
	func lattice_filter() {
		let r = 0.99
		let c = __cospi(0.15)
//		let p = parcor(ar: [-2 * r * c, r * r])
		let p = [0.0026985852929478824, -0.069171187971002, 0.9694038895129534, -0.8943405745211235]
		let object = lattice_filter_create(p.count, 1)
		defer { lattice_filter_destroy(object) }
		let x = repeatElement(-1.0 ... 1.0, count: 256).map(Float64.random(in:))
		let y = Array<Float64>(unsafeUninitializedCapacity: x.count) {
			$0.initialize(repeating: .zero)
			lattice_filter_static(object, p, 1, x, 1, $0.baseAddress.unsafelyUnwrapped, 1, $0.count)
			$1 = $0.count
		}
		print(y)
	}
	@Test
	func lattice_sgd_eval() {
		let x = repeatElement(-1.0 ... 1.0, count: 44100).map(Float64.random(in:))
		let y = Array<Float64>(unsafeUninitializedCapacity: x.count) {
			let r = 0.95
			let c = __cospi(0.25)
			let a = -2 * r * c
			let b = r * r
			$0.initialize(repeating: .zero)
			for k in 2..<$0.count {
				$0[k] = x[k] - a * $0[k - 1] - b * $0[k - 2]
			}
			$1 = $0.count
		}
		let object = gal_create(2)
		gal_mu(object, 1e-3)
		defer { gal_destroy(object) }
		withUnsafeTemporaryAllocation(of: Float64.self, capacity: 4 * y.count) { p in
			gal_p(object,
						  y,
						  p.baseAddress.unsafelyUnwrapped, x.count,
						  y.count)
			print(p[y.count-1], p[y.count+y.count-1])
		}
	}
	@Test
	func lattice_rls_eval() {
		let object = lsl_create(4);
		lsl_lambda(object, 0.99)
		defer { lsl_destroy(object) }
		let x = Array<Float64>(repeating: .zero, count: 0) + repeatElement(-1.0 ... 1.0, count: 1536).map(Float64.random(in:))
		let y = Array<Float64>(unsafeUninitializedCapacity: x.count) {
			$0.initialize(repeating: .zero)
			do {
				let r = 0.98
				let c = __cospi(0.15)
				let a = -2 * r * c
				let b = r * r
				for k in 2..<$0.count {
					$0[k] = x[k] - a * $0[k - 1] - b * $0[k - 2]
				}
			}
//			do {
//				let r = 0.95
//				let c = __cospi(0.55)
//				let a = -2 * r * c
//				let b = r * r
//				for k in 2..<$0.count {
//					$0[k] = x[k] - a * $0[k - 1] - b * $0[k - 2]
//				}
//			}
			$1 = $0.count
		}
		withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * y.count) { p in
			p.initialize(repeating: .zero)
			lsl_p(object,
				  y,
				  p.baseAddress.unsafelyUnwrapped, y.count,
				  y.count)
			print(stride(from: y.count-1, to: 7*y.count-1, by: y.count).map { p[$0] })
		}
	}
}
@Suite
struct MATestCase {
	func gen(r: Float64, θ: Float64, ε: Float64, count: Int) -> (ArraySlice<Float64>, Array<Float64>) {
		let x = repeatElement(-1.0 ... 1.0, count: 3 + count).map(Float64.random(in:))
		let y = vDSP.convolve(x, withKernel: [1, -2*r*__cospi(θ), r*r]).map {
			$0 + .random(in: -ε ... ε)
		}
//		print([1, -2.0 * r * __cospi(θ), r * r])
		return (x.dropFirst(2).dropLast(1), y)
	}
	func ma(target y: some AccelerateBuffer<Float64> & RangeReplaceableCollection<Float64>,
			source x: some AccelerateBuffer<Float64> & RangeReplaceableCollection<Float64>,
			order: Int) -> Array<Float64> {
		let xx = vDSP.correlate(x, withKernel: x.dropLast(order + 1))
		let xy = vDSP.correlate(y, withKernel: x.dropLast(order + 1))
		return.init(unsafeUninitializedCapacity: ( order + 1 ) * 2) {
			var e = 0 as Int32
			vDSP_wienerD(.init(order + 1),
						 xx, xy,
						 $0.baseAddress.unsafelyUnwrapped,
						 $0.baseAddress.unsafelyUnwrapped.advanced(by: order + 1),
						 0, &e)
			assert(e == .zero)
			$1 = order + 1
		}
	}
//	@Test
//	func wiener() {
//		let (x, y) = gen(r: 0, θ: 0.5, count: 1024)
//		print(ma(target: y, source: x, order: 3))
//	}
	@Test
	func rls_kernel_test() {
		let filter = rls_filter_create(2)
		defer { rls_filter_destroy(filter) }
		rls_filter_lambda(filter, 0.98)
		let (x, y) = gen(r: 0.9, θ: 0.3333, ε: 0.1, count: 1_000)
		let source = Array(x)
		let target = Array(y)
		#expect(source.count == target.count)
		let w = Array<Float64>(unsafeUninitializedCapacity: 4 * target.count) {
			$0.initialize(repeating: .nan)
			rls_filter_kernel(filter,
							  target,
							  source,
							  $0.baseAddress.unsafelyUnwrapped, target.count,
							  target.count)
			$1 = $0.count
		}
		print(w[target.count-1], w[target.count-1+target.count], w[target.count-1+2*target.count], w[target.count-1+3*target.count])
		print(ma(target: y, source: x, order: 4))
	}
	@Test
	func lms_kernel_test() {
		let filter = lms_filter_create(3)
		defer { lms_filter_destroy(filter) }
		lms_filter_mu(filter, 0.01)
		let (x, y) = gen(r: 0.9, θ: 0.3333, ε: 0.1, count: 1_000)
		let source = Array(x)
		let target = Array(y)
		#expect(source.count == target.count)
		let w = Array<Float64>(unsafeUninitializedCapacity: 4 * target.count) {
			$0.initialize(repeating: .nan)
			lms_filter_kernel(filter,
							  target,
							  source,
							  $0.baseAddress.unsafelyUnwrapped, target.count,
							  target.count)
			$1 = $0.count
		}
		print(w[target.count-1], w[target.count-1+target.count], w[target.count-1+2*target.count], w[target.count-1+3*target.count])
		print(ma(target: y, source: x, order: 4))
	}
	@Test
	func ftf_kernel_test() {
		let (x, y) = gen(r: 0.9, θ: 0.3333, ε: 1e-3, count: 3_000_000) // check numerical stable
//		0.9992044896932714 -0.8993607387877021 0.8250684295177374 nan
		let filter = tfo_filter_create(5)
		defer { tfo_filter_destroy(filter) }
		tfo_filter_lambda(filter, 0.98)
		let source = Array(x)
		let target = Array(y)
		let kernel = Array<Float64>(unsafeUninitializedCapacity: 6 * target.count) {
			$0.initialize(repeating: 0)
			tfo_filter_kernel(filter,
							  target,
							  source,
							  $0.baseAddress.unsafelyUnwrapped, target.count,
							  target.count)
			$1 = $0.count
		}
//		print(kernel)
		print(kernel[target.count-1], kernel[target.count-1+target.count], kernel[target.count-1+2*target.count], kernel[target.count-1+3*target.count])
	}
}
@Suite
struct GSO {
	@Test
	func orthogonal() {
		let count = 8192
		let object = gso_create(4)
		gso_lambda(object, 0.99)
		defer { gso_destroy(object) }
//		let src0 = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:))
//		let src1 = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:))
//		let src2 = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:))
//		let src3 = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:))
		
		let src0 = vForce.sinPi(vDSP.ramp(in: 0.0 ... 256.0, count: count))
		let src1 = vForce.sinPi(vDSP.ramp(in: 0.0 ... 512.0, count: count))
		let src2 = vForce.sinPi(vDSP.ramp(in: 0.0 ... 1024.0, count: count))
		let src3 = vForce.sinPi(vDSP.ramp(in: 0.0 ... 2048.0, count: count))
		
		let source = Array<Float64>(unsafeUninitializedCapacity: 4 * count) {
			var lane0 = $0.extracting(0 * count ..< 1 * count)
			var lane1 = $0.extracting(1 * count ..< 2 * count)
			var lane2 = $0.extracting(2 * count ..< 3 * count)
			var lane3 = $0.extracting(3 * count ..< 4 * count)
			vDSP.clear(&$0)
			vDSP.add(multiplication: (src0, 1.0), lane0, result: &lane0)
			vDSP.add(multiplication: (src1, 2.0), lane0, result: &lane0)
			vDSP.add(multiplication: (src2, 3.0), lane0, result: &lane0)
			vDSP.add(multiplication: (src3, 4.0), lane0, result: &lane0)
			
			vDSP.add(multiplication: (src0, 0.0), lane1, result: &lane1)
			vDSP.add(multiplication: (src1, 1.0), lane1, result: &lane1)
			vDSP.add(multiplication: (src2, 2.0), lane1, result: &lane1)
			vDSP.add(multiplication: (src3, 3.0), lane1, result: &lane1)
			
			vDSP.add(multiplication: (src0, 0.0), lane2, result: &lane2)
			vDSP.add(multiplication: (src1, 0.0), lane2, result: &lane2)
			vDSP.add(multiplication: (src2, 1.0), lane2, result: &lane2)
			vDSP.add(multiplication: (src3, 2.0), lane2, result: &lane2)
			
			vDSP.add(multiplication: (src0, 0.0), lane3, result: &lane3)
			vDSP.add(multiplication: (src1, 0.0), lane3, result: &lane3)
			vDSP.add(multiplication: (src2, 0.0), lane3, result: &lane3)
			vDSP.add(multiplication: (src3, 1.0), lane3, result: &lane3)
			
			$1 = $0.count
		}
		let result = Array<Float64>(unsafeUninitializedCapacity: 4 * count) {
			guard let memory = $0.baseAddress else {
				Issue.record()
				return
			}
			$0[0 * count ..< 1 * count].initialize(repeating: 1)
			$0[1 * count ..< 2 * count].initialize(repeating: 0)
			$0[2 * count ..< 3 * count].initialize(repeating: 0)
			$0[3 * count ..< 4 * count].initialize(repeating: 0)
			gso_weight(object,
					   source, count,
					   memory, count,
					   memory, count,
					   count)
//			gso_residual(object, source, count, memory, count, count)
			print(stride(from: 0, to: 4 * 4, by: 4).map {
				Array(UnsafeBufferPointer(start: object.pointee.A + $0, count: 4))
			})
			$1 = $0.count
		}
		print(result[1*count-1], result[2*count-1], result[3*count-1], result[4*count-1])
//		print(vDSP.dot(source[0*count..<1*count].suffix(64), source[0*count..<1*count].suffix(64)))
//		print(vDSP.dot(source[0*count..<1*count].suffix(64), source[1*count..<2*count].suffix(64)))
//		print(vDSP.dot(result[0*count..<1*count].suffix(64), result[0*count..<1*count].suffix(64)))
//		print(vDSP.dot(result[0*count..<1*count].suffix(64), result[1*count..<2*count].suffix(64)))
	}
}
