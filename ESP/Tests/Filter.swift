//
//  Filter.swift
//  MUTE
//
//  Created by Kota on 9/2/26.
//
import Testing
import KSP
@testable import typealias ESP.Filter
@Suite
struct FilterTestCases {
    @Test
    func biquad_gain() {
        let object = Filter.Biquad.PEQ(ω₀: 0.125, Q: 0.5.squareRoot(), dB: 12)
        print(object.b, object.a)
        print(object.Gₚ)
        print(object.Gₛ)
    }
    @Test(
        arguments: [4096]
    )
    func cascade(count: Int) {
        let (b0, a0) = switch Filter.Biquad.PEQ(ω₀: 2/16.0, Q: 6.0, dB: 12) {
        case let object:
            (object.b, object.a)
        }
        let (b1, a1) = switch Filter.Biquad.PEQ(ω₀: 4/16.0, Q: 6.0, dB: 12) {
        case let object:
            (object.b, object.a)
        }
        let (b2, a2) = switch Filter.Biquad.PEQ(ω₀: 6/16.0, Q: 6.0, dB: 12) {
        case let object:
            (object.b, object.a)
        }
        var y = Array<Float64>(unsafeUninitializedCapacity: count) {
            $1 = $0.count
            rng_uniform($0.baseAddress.unsafelyUnwrapped, $1, -1, 1, 1, $1)
        }
        var s = Array<SIMD4<Float64>>(repeating: .zero, count: 3)
        biquad_filter_convolve_static([b0, b1, b2],
                                      [a0, a1, a2],
                                      y,
                                      &y,
                                      &s, s.count,
                                      y.count)
    }
}
