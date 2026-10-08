//
//  Octave.swift
//  MUTE
//
//  Created by Kota on 8/18/26.
//
import Testing
import typealias Accelerate.vDSP
@testable import ESP
@Suite
struct OctaveTestCases {
    @Test
    func threeband() {
        // Fixed low/high shelf coefficients, normalized to a₀ = 1.
        let cascade = [
            (1.1626972886196816, -1.1077492298773095, 0.65373695198423365, -1.2844997952210218, 0.63968367526020287),
            (0.86006909088707806, 1.1047585711203818, 0.55017215703634748, 0.95274087307143829, 0.56225894597236903)
        ] as Array<(Float64, Float64, Float64, Float64, Float64)>
        let frequency = Ramp.linspace(in: 0.01 ... 0.5, count: 256)
        let response = TransferFunction.response(frequency: frequency, cascade: cascade)
        let slope = Octave.lnslope(frequency: frequency,
                                   response: response.map(\.magnitude),
                                   confidence: frequency.map {
            (0.0...0.2).contains($0) ? 1 : 0
        })
        #expect(slope.count == frequency.count)
        #expect(slope.allSatisfy { $0.isFinite && $0 > 0 })
    }
    @Test
    func DeciBelPerOctave() {
        let αβ = Octave.`dB/oct.`(frequency: vDSP.ramp(from: 100, through: 16000, count: 128),
                                  response: vDSP.ramp(from: 10, through: 1, count: 128))
        #expect(αβ.x.isFinite && αβ.y.isFinite)
    }
}
