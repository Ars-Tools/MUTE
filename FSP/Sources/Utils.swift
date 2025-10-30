//
//  Utils.swift
//  MUTE
//
//  Created by Kota on 8/26/R7.
//
import typealias Foundation.KeyPathComparator
import typealias Accelerate.__LAPACK_int
import typealias Accelerate.vDSP
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import func Accelerate.vecLib.vDSP_vclrD
import func Accelerate.vecLib.vDSP_vsdivD
import func Accelerate.vecLib.vDSP_vfillD
import func Accelerate.vecLib.dgeev_
import func Accelerate.vecLib.zgels_
import let simd.M_LN10
import func simd.sqrt
import func simd.expm1
import func simd.pow
import func simd.simd_precise_recip
import typealias Numerics.Complex128
import NSP
public enum Utils {}
extension Utils {
	public static func ripple(dB: Float64) -> Float64 {
		sqrt(expm1(0.1 * M_LN10 * dB))
	}
	public static func forget(factor: Float64, per sample: Int) -> Float64 {
		pow(factor, simd_precise_recip(.init(sample)))
	}
}
@inlinable@_transparent
func solve(m: Int, n: Int,
		   A: UnsafePointer<Complex128>, ldA: Int,
		   b: UnsafePointer<Complex128>) -> Array<Complex128> {
	.init(unsafeUninitializedCapacity: max(m, n) + 2 * n) {
		var info = 0 as __LAPACK_int
		$0.baseAddress?.initialize(from: b, count: m)
		zgels_("N",
			   withUnsafePointer(to: m, \.self), withUnsafePointer(to: n, \.self), withUnsafePointer(to: 1, \.self),
			   .init(A), withUnsafePointer(to: ldA, \.self),
			   .init($0.baseAddress), withUnsafePointer(to: max(m,n), \.self),
			   .init($0.baseAddress.unsafelyUnwrapped.advanced(by: max(m,n))), withUnsafePointer(to: 2 * n, \.self),
			   &info)
		assert(info == 0)
		$1 = n
	}
}
@inlinable@_transparent
func solve(m: Int, n: Int,
		   A: some AccelerateBuffer<Complex128>, ldA: Int,
		   b: some AccelerateBuffer<Complex128>) -> Array<Complex128> {
	A.withUnsafeBufferPointer { A in
		b.withUnsafeBufferPointer { b in
			solve(m: m, n: n, A: A.baseAddress.unsafelyUnwrapped, ldA: ldA, b: b.baseAddress.unsafelyUnwrapped)
		}
	}
}
// Roots to Poly
//@inlinable
//func roots(poly: Array<Float64>) -> Array<SIMD2<Float64>> {
//	var n = poly.count - 1
//	return withUnsafeTemporaryAllocation(of: Float64.self, capacity: n * ( n + 5 )) {
//		let z = $0.baseAddress.unsafelyUnwrapped
//		let r = z.advanced(by: n * n)
//		let i = r.advanced(by: n)
//		let w = i.advanced(by: n)
//		var work = 3 * n as __LAPACK_int
//		var info = 1 as __LAPACK_int
//		vDSP_vclrD(z, 1, .init(n * n))
//		r.pointee = -poly[0]
//		vDSP_vsdivD(poly, 1, r, z + n * n, -1, .init(poly.count))
//		r.pointee = 1
//		vDSP_vfillD(r, z + 1, n + 1, .init(n - 1))
//		dgeev_("N", "N",
//			   &n,
//			   z, &n,
//			   r, i,
//			   .none, &n,
//			   .none, &n,
//			   w, &work,
//			   &info)
//		assert(info == .zero)
//		return (0..<n).lazy.map {
//			SIMD2(r[$0], i[$0])
//		}.sorted(using: KeyPathComparator(\.y.magnitude))
//	}
//}
@inlinable
func roots(poly: Array<Float64>) -> Array<Complex128> {
	var n = poly.count - 1
	return withUnsafeTemporaryAllocation(of: Float64.self, capacity: n * ( n + 5 )) {
		let z = $0.baseAddress.unsafelyUnwrapped
		let r = z.advanced(by: n * n)
		let i = r.advanced(by: n)
		let w = i.advanced(by: n)
		var work = 3 * n as __LAPACK_int
		var info = 1 as __LAPACK_int
		vDSP_vclrD(z, 1, .init(n * n))
		r.pointee = -poly[0]
		vDSP_vsdivD(poly, 1, r, z + n * n, -1, .init(poly.count))
		r.pointee = 1
		vDSP_vfillD(r, z + 1, n + 1, .init(n - 1))
		dgeev_("N", "N",
			   &n,
			   z, &n,
			   r, i,
			   .none, &n,
			   .none, &n,
			   w, &work,
			   &info)
		assert(info == .zero)
		return (0..<n).lazy.map {
			Complex128(real: r[$0], imag: i[$0])
		}.sorted(using: KeyPathComparator(\.imag.magnitude))
	}
}
// Poly to Roots
@inlinable
func poly(roots: Array<SIMD2<Float64>>) -> Array<Float64> {
	.init(unsafeUninitializedCapacity: roots.count * 3 + 1) {
		let A = $0.extracting(1+roots.count*1..<1+roots.count*2)
		let B = $0.extracting(1+roots.count*2..<1+roots.count*3)
		$0.initialize(repeating: .zero)
		$0[0] = 1
		$1 = 1
		var roots = roots.sorted(using: KeyPathComparator(\.y.magnitude))
		while !roots.isEmpty {
			let c = roots.popLast()
			let c̅ = roots.popLast()
			if let c̅, let c {
				assert((c.y + c̅.y).magnitude < .ulpOfOne.squareRoot())
				let a = c.x + c̅.x
				let b = c.x * c̅.x - c.y * c̅.y
				vDSP.multiply(a, $0[0..<$1], result: &A[0..<$1])
				vDSP.multiply(b, $0[0..<$1], result: &B[0..<$1])
				vDSP.subtract($0[1..<$1+1], A[0..<$1], result: &$0[1..<$1+1])
				vDSP.add($0[2..<$1+2], B[0..<$1], result: &$0[2..<$1+2])
				$1 += 2
			} else if let c {
				let a = c.x
				vDSP.multiply(a, $0[0..<$1], result: &A[0..<$1])
				vDSP.subtract($0[1..<$1+1], A[0..<$1], result: &$0[1..<$1+1])
				$1 += 1
			}
		}
	}
}
@inlinable
func poly(roots: Array<Complex128>) -> Array<Float64> {
    .init(unsafeUninitializedCapacity: roots.count * 3 + 1) {
        let A = $0.extracting(1+roots.count*1..<1+roots.count*2)
        let B = $0.extracting(1+roots.count*2..<1+roots.count*3)
        $0.initialize(repeating: .zero)
        $0[0] = 1
        $1 = 1
        var roots = roots.sorted(using: KeyPathComparator(\.imag.magnitude))
        while !roots.isEmpty {
            let c = roots.popLast()
            let c̅ = roots.popLast()
            if let c̅, let c {
                assert((c.imag + c̅.imag).magnitude < .ulpOfOne.squareRoot())
                let a = c.real + c̅.real
                let b = c.real * c̅.real - c.imag * c̅.imag
                vDSP.multiply(a, $0[0..<$1], result: &A[0..<$1])
                vDSP.multiply(b, $0[0..<$1], result: &B[0..<$1])
                vDSP.subtract($0[1..<$1+1], A[0..<$1], result: &$0[1..<$1+1])
                vDSP.add($0[2..<$1+2], B[0..<$1], result: &$0[2..<$1+2])
                $1 += 2
            } else if let c {
                let a = c.real
                vDSP.multiply(a, $0[0..<$1], result: &A[0..<$1])
                vDSP.subtract($0[1..<$1+1], A[0..<$1], result: &$0[1..<$1+1])
                $1 += 1
            }
        }
    }
}
// SOS to Poly
@inlinable@inline(__always)
func poly(x: Array<Float64>, k: SIMD2<Float64>) -> Array<Float64> {
	.init(unsafeUninitializedCapacity: x.count + 1) {
		$0[x.count...].initialize(repeating: .zero)
		vDSP.multiply(k.x, x, result: &$0[0..<x.count])
		vDSP.add(multiplication: (x, k.y), $0[1..<x.count+1], result: &$0[1..<x.count+1])
		$1 = $0.count
	}
}
@inlinable @inline(__always)
func poly(x: Array<Float64>, k: SIMD3<Float64>) -> Array<Float64> {
	.init(unsafeUninitializedCapacity: x.count + 2) {
		$0[x.count...].initialize(repeating: .zero)
		vDSP.multiply(k.x, x, result: &$0[0..<x.count])
		vDSP.add(multiplication: (x, k.y), $0[1..<x.count+1], result: &$0[1..<x.count+1])
		vDSP.add(multiplication: (x, k.z), $0[2..<x.count+2], result: &$0[2..<x.count+2])
		$1 = $0.count
	}
}
@inlinable @inline(__always)
func poly(sos: (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>)) -> (Array<Float64>, Array<Float64>) {
	sos.1.reduce(sos.0.reduce(([1], [1])) {
		(poly(x: $0.0, k: $1.0), poly(x: $0.1, k: $1.1))
	}) {
		(poly(x: $0.0, k: $1.0), poly(x: $0.1, k: $1.1))
	}
}
@inlinable
func hilbert(time signal: some AccelerateBuffer<Complex128>, bias: Float64 = 1.0) -> Array<Complex128> {
	.init(unsafeUninitializedCapacity: 2 * signal.count) {
		let head = $0.extracting(0 * signal.count ..< 1 * signal.count)
		let tail = $0.extracting(1 * signal.count ..< 2 * signal.count)
		signal.withUnsafeBufferPointer {
			let dft = ddft_create(signal.count)
			defer { ddft_destroy(dft) }
			var count = ( signal.count - 1 ) / 2
			var inc = 1
			ddft_forward(dft, .init($0.baseAddress.unsafelyUnwrapped), .init(tail.baseAddress.unsafelyUnwrapped))
			head[0] = .init(floatLiteral: 2)
			tail[0] *= .init(real: bias, imag: 0)
			zscal_(&count, .init(head.baseAddress.unsafelyUnwrapped), .init(tail.baseAddress.unsafelyUnwrapped.advanced(by: 1)), &inc)
			tail[(signal.count/2+1)...].initialize(repeating: .zero)
			ddft_inverse(dft, .init(tail.baseAddress.unsafelyUnwrapped), .init(head.baseAddress.unsafelyUnwrapped))
		}
		$1 = signal.count
	}
}
@inlinable
func hilbert(time signal: some AccelerateBuffer<Float64>, bias: Float64 = 1.0) -> Array<Complex128> {
	withUnsafeComplex128(of: signal) {
		hilbert(time: $0, bias: bias)
	}
}
@inlinable
func hilbert(freq signal: some AccelerateBuffer<Complex128>, bias: Float64 = 0.0) -> Array<Complex128> {
	.init(unsafeUninitializedCapacity: 2 * signal.count) {
		let head = $0.extracting(0 * signal.count ..< 1 * signal.count)
		let tail = $0.extracting(1 * signal.count ..< 2 * signal.count)
		signal.withUnsafeBufferPointer {
			let dft = ddft_create(signal.count)
			defer { ddft_destroy(dft) }
			ddft_inverse(dft, .init($0.baseAddress.unsafelyUnwrapped), .init(tail.baseAddress.unsafelyUnwrapped))
			head[0] = .init(floatLiteral: 2)
			tail[0] *= .init(real: bias, imag: 0)
			zscal_(withUnsafePointer(to: (signal.count-1)/2, \.self),
				   .init(head.baseAddress.unsafelyUnwrapped),
				   .init(tail.baseAddress.unsafelyUnwrapped.advanced(by: 1)),
				   withUnsafePointer(to: 1, \.self))
			tail[(signal.count/2+1)...].initialize(repeating: .zero)
			ddft_forward(dft, .init(tail.baseAddress.unsafelyUnwrapped), .init(head.baseAddress.unsafelyUnwrapped))
		}
		$1 = signal.count
	}
}
@inlinable
func hilbert(freq signal: some AccelerateBuffer<Float64>, bias: Float64 = 1.0) -> Array<Complex128> {
	withUnsafeComplex128(of: signal) {
		hilbert(freq: $0, bias: bias)
	}
}
@inlinable @inline(__always)
func withUnsafeComplex128<E, R>(of signal: some AccelerateBuffer<Float64>, body: (UnsafeMutableBufferPointer<Complex128>) throws (E) -> R) rethrows -> R {
	try withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * signal.count) {
		if case.some(let target) = $0.baseAddress {
			signal.withUnsafeBufferPointer {
				cblas_dcopy($0.count, $0.baseAddress, 1, target, 2)
				vDSP_vclrD(target.advanced(by: 1), 2, .init($0.count))
			}
		}
		return try $0.withMemoryRebound(to: Complex128.self, body)
	}
}
@inlinable @inline(__always)
func log(_ x: some AccelerateBuffer<Complex128>) -> Array<Complex128> {
	.init(unsafeUninitializedCapacity: x.count) {
		$0.baseAddress?.initialize(from: x.withUnsafeBufferPointer(\.baseAddress).unsafelyUnwrapped, count: x.count)
		var buffer = $0.withMemoryRebound(to: Float64.self, \.self)
		vDSP.convert(rectangularCoordinates: buffer, toPolarCoordinates: &buffer)
		vDSP_vswapD(buffer.baseAddress.unsafelyUnwrapped.advanced(by: $0.count), 2,
					buffer.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2, .init($0.count))
		withUnsafePointer(to: Int32($0.count)) {
			vvlog(buffer.baseAddress.unsafelyUnwrapped,
				  buffer.baseAddress.unsafelyUnwrapped,
				  $0)
		}
		vDSP_vswapD(buffer.baseAddress.unsafelyUnwrapped.advanced(by: $0.count), 2,
					buffer.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2, .init($0.count))
		$1 = $0.count
	}
}
@inlinable @inline(__always)
func exp(_ x: some AccelerateBuffer<Complex128>) -> Array<Complex128> {
	.init(unsafeUninitializedCapacity: x.count) {
		$0.baseAddress?.initialize(from: x.withUnsafeBufferPointer(\.baseAddress).unsafelyUnwrapped, count: x.count)
		var buffer = $0.withMemoryRebound(to: Float64.self, \.self)
		vDSP_vswapD(buffer.baseAddress.unsafelyUnwrapped.advanced(by: $0.count), 2,
					buffer.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2, .init($0.count))
		withUnsafePointer(to: Int32($0.count)) {
			vvexp(buffer.baseAddress.unsafelyUnwrapped,
				  buffer.baseAddress.unsafelyUnwrapped,
				  $0)
		}
		vDSP_vswapD(buffer.baseAddress.unsafelyUnwrapped.advanced(by: $0.count), 2,
					buffer.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2, .init($0.count))
		vDSP.convert(polarCoordinates: buffer, toRectangularCoordinates: &buffer)
		$1 = $0.count
	}
}
@inlinable@inline(__always)
public func minimumPhase(log response: some AccelerateBuffer<Float64>) -> Array<Complex128> {
	let N = response.count * 2 - response.count % 2 - 1
	return.init(unsafeUninitializedCapacity: 2 * N) {
		$1 = response.count
		let dft = ddft_create(N)
		defer { ddft_destroy(dft) }
		$0.initialize(repeating: .zero)
		let head = $0.extracting(0 * N ..< 1 * N)
		let tail = $0.extracting(1 * N ..< 2 * N)
		response.withUnsafeBufferPointer {
			dcopy_(withUnsafePointer(to: $0.count, \.self),
				   $0.baseAddress.unsafelyUnwrapped,
				   withUnsafePointer(to: 1, \.self),
				   .init(mutating: head.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)),
				   withUnsafePointer(to: 2, \.self))
		}
		zcopy_(withUnsafePointer(to: N - $1, \.self),
			   .init(head.baseAddress.unsafelyUnwrapped.advanced(by: 1)), withUnsafePointer(to: 1, \.self),
			   .init(head.baseAddress.unsafelyUnwrapped.advanced(by: response.count)), withUnsafePointer(to: -1, \.self))
		ddft_inverse(dft, .init(head.baseAddress.unsafelyUnwrapped), .init(tail.baseAddress.unsafelyUnwrapped))
		vDSP_vclrD(.init(mutating: tail.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped).advanced(by: 1)), 2, .init(response.count))
		dscal_(withUnsafePointer(to: N - $1, \.self),
			   withUnsafePointer(to: 2 as Float64, \.self),
			   .init(mutating: tail.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped).advanced(by: 2)),
			   withUnsafePointer(to: 2, \.self))
		tail.dropFirst($1).initialize(repeating: .zero)
		ddft_forward(dft, .init(tail.baseAddress.unsafelyUnwrapped), .init(head.baseAddress.unsafelyUnwrapped))
		dcopy_(withUnsafePointer(to: $1, \.self),
			   head.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped), withUnsafePointer(to: 2, \.self),
			   .init(mutating: tail.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)), withUnsafePointer(to: 1, \.self))
		vvexp(.init(mutating: tail.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)),
			  tail.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped),
			  withUnsafePointer(to: Int32($1), \.self))
		dcopy_(withUnsafePointer(to: $1, \.self),
			   tail.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped), withUnsafePointer(to: 1, \.self),
			   .init(mutating: head.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)), withUnsafePointer(to: 2, \.self))
		vDSP_rectD(head.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped), 2,
				   .init(mutating: head.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)), 2,
				   .init($1))
	}
}
@inlinable@inline(__always)
public func minimumPhase(mag response: some AccelerateBuffer<Float64>) -> Array<Complex128> {
	minimumPhase(log: vForce.log(response))
}
@inlinable@inline(__always)
public func minimum(mag response: some AccelerateBuffer<Float64>) -> Array<Complex128> {
	.init(unsafeUninitializedCapacity: 2 * response.count) {
		$0.initialize(repeating: .zero)
		$1 = response.count
		let head = $0.extracting(0 * $1 ..< 1 * $1).withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)
		let tail = $0.extracting(1 * $1 ..< 2 * $1).withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)
		let dft = ddft_create($1)
		defer { ddft_destroy(dft) }
		response.withUnsafeBufferPointer {
			vvlog(tail, $0.baseAddress.unsafelyUnwrapped, withUnsafePointer(to: Int32($0.count), \.self))
		}
		dcopy_(withUnsafePointer(to: $1, \.self),
			   tail, withUnsafePointer(to: 1, \.self),
			   head, withUnsafePointer(to: 2, \.self))
		ddft_inverse(dft, .init(head), .init(tail))
		vDSP_vclrD(tail.advanced(by: 1), 2, .init($1))
		dscal_(withUnsafePointer(to: ($1-1)/2, \.self),
			   withUnsafePointer(to: 2 as Float64, \.self),
			   tail.advanced(by: 2), withUnsafePointer(to: 2, \.self))
		tail.advanced(by: (($1/2+1))*2).initialize(repeating: .zero, count: (($1-1)/2)*2)
		ddft_forward(dft, .init(tail), .init(head))
		dcopy_(withUnsafePointer(to: $1, \.self),
			   head, withUnsafePointer(to: 2, \.self),
			   tail, withUnsafePointer(to: 1, \.self))
		vvexp(tail, tail, withUnsafePointer(to: Int32($1), \.self))
		dcopy_(withUnsafePointer(to: $1, \.self),
			   tail, withUnsafePointer(to: 1, \.self),
			   head, withUnsafePointer(to: 2, \.self))
		vDSP_rectD(head, 2, head, 2, .init($1))
	}
}
@inlinable
public func`dB/oct.`(frequency: some AccelerateBuffer<Float64> & Sequence<Float64>,
                     magnitude: some AccelerateBuffer<Float64>,
                     bandwidth: some RangeExpression<Float64>) -> (Float64, Float64) {
    precondition(frequency.count == magnitude.count)
    let range = frequency.enumerated().compactMap { bandwidth.contains($1) ? .some(UInt($0 + 1)) : .none }
    let count = range.count
    var info = 0
    var size = 0 as Float64
    dgels_("N",
           withUnsafePointer(to: count, \.self), withUnsafePointer(to: 2, \.self),
           withUnsafePointer(to: 1, \.self),
           .none, withUnsafePointer(to: count, \.self),
           .none, withUnsafePointer(to: count, \.self),
           &size,
           withUnsafePointer(to: -1, \.self),
           &info)
    assert(info == 0)
    return withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * count + max(2, count) + .init(size)) {
        // A
        vDSP.gather(frequency, indices: range, result: &$0[0*count..<1*count])
        vForce.log2($0[0*count..<1*count], result: &$0[0*count..<1*count])
        vDSP.fill(&$0[1*count..<2*count], with: 1)
        // B
        vDSP.gather(magnitude, indices: range, result: &$0[2*count..<3*count])
        vForce.log10($0[2*count..<3*count], result: &$0[2*count..<3*count])
        vDSP.multiply(20, $0[2*count..<3*count], result: &$0[2*count..<3*count])
        // solve
        dgels_("N",
               withUnsafePointer(to: count, \.self), withUnsafePointer(to: 2, \.self),
               withUnsafePointer(to: 1, \.self),
               $0.baseAddress.unsafelyUnwrapped.advanced(by: 0 * count), withUnsafePointer(to: count, \.self),
               $0.baseAddress.unsafelyUnwrapped.advanced(by: 2 * count), withUnsafePointer(to: count, \.self),
               $0.baseAddress.unsafelyUnwrapped.advanced(by: 2 * count + max(2, count)),
               withUnsafePointer(to: .init(size), \.self), &info)
        assert(info == 0)
        return ($0[2*count+0], $0[2*count+1])
    }
}
@inlinable
public func lnslope(frequency: some AccelerateBuffer<Float64> & Sequence<Float64>,
                    magnitude: some AccelerateBuffer<Float64>,
                    bandwidth: some RangeExpression<Float64>) -> Array<Float64> {
    let (α, β) = `dB/oct.`(frequency: frequency, magnitude: magnitude, bandwidth: bandwidth)
    return.init(unsafeUninitializedCapacity: frequency.count) {
        vForce.log2(frequency, result: &$0)
        vDSP.invertedClip($0, to: 0...0, result: &$0)
        vDSP.add(multiplication: ($0, 0.05 * M_LN10 * α), 0.05 * M_LN10 * β, result: &$0)
        $1 = $0.count
    }
}
@inlinable@_transparent
func logspace(in range: ClosedRange<Float64>, count: Int) -> Array<Float64> {
    .init(unsafeUninitializedCapacity: count) {
        let range = log2(SIMD2<Float64>(range.lowerBound, range.upperBound))
        vDSP.formRamp(withInitialValue: range.x, increment: (range.y - range.x) / .init($0.count), result: &$0)
        vForce.exp2($0, result: &$0)
        $1 = $0.count
    }
}
