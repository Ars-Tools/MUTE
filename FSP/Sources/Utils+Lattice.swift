//
//  Utils+Lattice.swift
//  MUTE
//
//  Created by Kota on 8/31/R7.
//
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import func Accelerate.vDSP_wienerD
import func simd.fma
public func ar(signal: Array<Float64>, order: Int) -> ArraySlice<Float64> { // index starts with 1 same as a₁, a₂, a₃ …
	Array<Float64>(unsafeUninitializedCapacity: 4 * order + 5) {
		vDSP.correlate(signal, withKernel: signal.dropLast(order + 2), result: &$0[3*order+3 ..< 4*order+5])
		vDSP.negative($0[3*order+4 ..< 4*order+5], result: &$0[2*order+2 ..< 3*order+3])
		var e = 0 as Int32
		vDSP_wienerD(.init(order + 1),
					 $0.baseAddress.unsafelyUnwrapped.advanced(by: 3*order+3),
					 $0.baseAddress.unsafelyUnwrapped.advanced(by: 2*order+2),
					 $0.baseAddress.unsafelyUnwrapped.advanced(by: 1*order+1),
					 $0.baseAddress.unsafelyUnwrapped,
					 0,
					 &e)
		assert(e == 0, "solver exits with \(e)")
		assert($0.first.map { ($0-1).magnitude <= .ulpOfOne } == true, "a₀ should be 1")
		$1 = order + 1
	}.dropFirst()
}
public typealias PARCORcoefficients<T> = BidirectionalCollection<T> & RangeReplaceableCollection<T> & AccelerateMutableBuffer<T>
public func parcor(ar c: some PARCORcoefficients<Float64>) -> Array<Float64> {
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
public typealias ARcoefficients<T> = BidirectionalCollection<T>
public func ar(parcor c: some ARcoefficients<Float64>) -> Array<Float64> {
	c.reversed().reduce([]) { a, k in
		.init(unsafeUninitializedCapacity: a.count + 1) {
			vDSP.add(multiplication: (a, k), a, result: &$0[0..<a.count])
			$0[a.count] = k
			$1 = $0.count
		}
	}
}
