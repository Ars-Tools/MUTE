//
//  Prototype+Papoulis.swift
//  MUTE
//
//  Created by Kota on 8/14/R7.
//
import typealias Accelerate.vDSP
import protocol DSP.Stream
import protocol DSP.Frequency
import simd
@preconcurrency import Combine
@inlinable
func legendre(count: Int) -> Array<Float64> {
	sequence(state: ([1.0], [1.0, 0.0])) { s in
		defer {
			(s.0, s.1) = (s.1, Array<Float64>(unsafeUninitializedCapacity: s.1.count + 1) {
				$0[s.1.count] = 0
				vDSP.multiply(.init(2 * s.1.count - 1), s.1, result: &$0[0..<s.1.count])
				vDSP.add(multiplication: (s.0, .init(1-s.1.count)), $0[2..<2+s.0.count], result: &$0[2..<2+s.0.count])
				vDSP.divide($0, .init(s.1.count), result: &$0)
				$1 = $0.count
			})
		}
		return.some(s.0)
	}.dropFirst(count).prefix(1).flatMap(\.self)
}
// TODO: https://www.mathscinotes.com/2011/06/the-papoulis-filter-aka-optimum-l-filter/
