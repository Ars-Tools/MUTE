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
        // Fixed LPF coefficients: frequency 0.125, Q = sqrt(2), a₀ = 1.
        let (b₀, b₁, b₂, a₁, a₂) = (0.11715728752538097, 0.23431457505076195, 0.11715728752538097, -1.131370849898476, 0.59999999999999998)
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
        // Fixed PEQ coefficients, normalized to a₀ = 1.
        let sos = [
            (0.93471994184178353, -1.2291342103124261, 0.80353832835879369, -1.2291342103124261, 0.73825827020057699),
            (1.1945165889964391, -0.71542625056051934, 0.67498229716904379, -0.71542625056051934, 0.86949888616548276),
            (0.83715873786243511, 0.5989253369528984, 0.72790859011508868, 0.5989253369528984, 0.56506732797752379),
            (1.0390540273286204, 1.7752531216780254, 0.88246610512039869, 1.7752531216780254, 0.92152013244901887),
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
