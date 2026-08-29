//
//  TransferFunction.swift
//  MUTE
//
//  Created by Kota on 8/29/26.
//
import Testing
@testable import ESP
@Suite
struct TransferFunctionTestCases {
    @Test
    func kernel() {
        let (b₀, b₁, b₂, a₁, a₂) = BiquadFilter.LPF(ω₀: 0.125, Q: 2.0.squareRoot())
        let transformer = TransferFunction.Transformer(count: 256)
        let frequency = Ramp.arange(in: 0...1, count: transformer.count)
        let raw = TransferFunction.response(frequency: frequency,
                                            b: [b₀, b₁, b₂],
                                            a: [1, a₁, a₂])
        let dft = transformer.response(b: [b₀, b₁, b₂],
                                       a: [1, a₁, a₂])
        #expect(zip(raw, dft).map(-).map(\.magnitude).allSatisfy {
            $0.isLess(than: .ulpOfOne.squareRoot())
        })
    }
    @Test
    func cascade() {
        let sos = [
            BiquadFilter.PEQ(ω₀: 2/16.0, Q: 11.0.squareRoot(), dB: -6),
            BiquadFilter.PEQ(ω₀: 3/16.0, Q: 11.0.squareRoot(), dB: 12),
            BiquadFilter.PEQ(ω₀: 5/16.0, Q: 11.0.squareRoot(), dB: -12),
            BiquadFilter.PEQ(ω₀: 7/16.0, Q: 11.0.squareRoot(), dB: 6),
        ] as Array<(Float64, Float64, Float64, Float64, Float64)>
        let transformer = TransferFunction.Transformer(count: 256)
        let frequency = Ramp.arange(in: 0...1, count: transformer.count)
        let raw = TransferFunction.response(frequency: frequency,
                                            cascade: sos)
        let dft = transformer.response(cascade: sos)
        #expect(zip(raw, dft).map(-).map(\.magnitude).allSatisfy {
            $0.isLess(than: .ulpOfOne.squareRoot())
        })
    }
}
