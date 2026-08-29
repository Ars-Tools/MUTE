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
        let cascade = [
            BiquadFilter.LSF(ω₀: 1/8.0, Q: 2.0.squareRoot(), dB:  6),
            BiquadFilter.HSF(ω₀: 3/8.0, Q: 2.0.squareRoot(), dB: -6)
        ] as Array<(Float64, Float64, Float64, Float64, Float64)>
        let frequency = Ramp.linspace(in: 0.01 ... 0.5, count: 256)
        let response = TransferFunction.response(frequency: frequency, cascade: cascade)
//        print(response)
        let slope = Octave.lnslope(frequency: frequency,
                                   response: response.map(\.magnitude),
                                   confidence: frequency.map {
            (0.0...0.2).contains($0) ? 1 : 0
        })
        print(slope)
    }
    @Test
    func DeciBelPerOctave() {
        let αβ = Octave.`dB/oct.`(frequency: vDSP.ramp(from: 100, through: 16000, count: 128),
                                  response: vDSP.ramp(from: 10, through: 1, count: 128))
        print(αβ)
    }
}
