//
//  Utils+Kernel.swift
//  MUTE
//
//  Created by Kota on 8/27/R7.
//
import Accelerate
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Numerics.Complex128
@inlinable
public func fit(response: some AccelerateBuffer<Complex128>, frequency: some AccelerateBuffer<Float64>, with kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
	assert(frequency.count == response.count)
	let m = response.count
	let n = 1 + kernel.b + kernel.a
	return withUnsafeTemporaryAllocation(byteCount: MemoryLayout<Complex128>.stride * (m * n + 2 * max(m, n) + n),
										 alignment: MemoryLayout<Complex128>.alignment) {
		let A = $0.assumingMemoryBound(to: Complex128.self).extracting(0 * m * n ..< 1 * m * n)
		let b = $0.assumingMemoryBound(to: Complex128.self).extracting(1 * m * n ..< 1 * m * n + max(m, n))
		let work = $0.assumingMemoryBound(to: Complex128.self).extracting((1 * m * n + max(m, n))...)
		assert(m < work.count)
		var edx = $0.assumingMemoryBound(to: Float64.self).extracting(0 * m ..< 1 * m)
		var edy = $0.assumingMemoryBound(to: Float64.self).extracting(1 * m ..< 2 * m)
		response.withUnsafeBufferPointer {
			b.baseAddress?.initialize(from: $0.baseAddress.unsafelyUnwrapped, count: m)
		}
		for index in 0..<max(kernel.b, kernel.a) {
			vDSP.multiply(.init(-2*index-2), frequency, result: &edy)
			vForce.cosPi(edy, result: &edx)
			vForce.sinPi(edy, result: &edy)
			vDSP_ztocD(withUnsafePointer(to: DSPDoubleSplitComplex(realp: edx.baseAddress.unsafelyUnwrapped,
																   imagp: edy.baseAddress.unsafelyUnwrapped), \.self), 1,
					   work.withMemoryRebound(to: DSPDoubleComplex.self, \.baseAddress.unsafelyUnwrapped), 2, .init(m))
			if index < kernel.b {
				zcopy_(withUnsafePointer(to: m, \.self),
					   .init(work.baseAddress), withUnsafePointer(to: 1, \.self),
					   .init(A.baseAddress?.advanced(by: m * (1 + index))), withUnsafePointer(to: 1, \.self))
			}
			if index < kernel.a {
				zgbmv_("N",
					   withUnsafePointer(to: m, \.self), withUnsafePointer(to: m, \.self),
					   withUnsafePointer(to: 0, \.self), withUnsafePointer(to: 0, \.self),
					   .init(withUnsafePointer(to: -1 as Complex128, \.self)),
					   .init(work.baseAddress), withUnsafePointer(to: 1, \.self),
					   .init(b.baseAddress), withUnsafePointer(to: 1, \.self),
					   .init(withUnsafePointer(to:  0 as Complex128, \.self)),
					   .init(A.baseAddress?.advanced(by: m * (1 + index + kernel.b))), withUnsafePointer(to: 1, \.self))
			}
		}
		$0.assumingMemoryBound(to: Complex128.self).prefix(m).initialize(repeating: 1)
		// LS
		var info = 0 as __LAPACK_int
		zgels_("N",
			   withUnsafePointer(to: m, \.self), withUnsafePointer(to: n, \.self), withUnsafePointer(to: 1, \.self),
			   .init(A.baseAddress), withUnsafePointer(to: m, \.self),
			   .init(b.baseAddress), withUnsafePointer(to: max(m, n), \.self),
			   .init(work.baseAddress.unsafelyUnwrapped), withUnsafePointer(to: work.count, \.self),
			   &info)
		assert(info == 0)
		return(
			Array<Float64>(unsafeUninitializedCapacity: 1 + kernel.b) {
				let b = b.prefix(1 + kernel.b).withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)
				$0[0] = b.pointee
				dcopy_(withUnsafePointer(to: kernel.b, \.self),
					   b, withUnsafePointer(to: 2, \.self),
					   $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), withUnsafePointer(to: 1, \.self))
				$1 = $0.count
			},
			Array<Float64>(unsafeUninitializedCapacity: 1 + kernel.a) {
				let a = b.dropFirst(1 + kernel.b).withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)
				$0[0] = 1
				dcopy_(withUnsafePointer(to: kernel.a, \.self),
					   a, withUnsafePointer(to: 2, \.self),
					   $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), withUnsafePointer(to: 1, \.self))
				$1 = $0.count
			}
		)
	}
}
@inlinable
public func fit(response: Array<Complex128>, with kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
	fit(response: response, frequency: Array<Float64>(unsafeUninitializedCapacity: response.count) {
		vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
		vDSP.divide($0, .init($0.count), result: &$0)
		$1 = $0.count
	}, with: kernel)
}
