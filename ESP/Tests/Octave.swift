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
    func DeciBelPerOctave() {
        let (α, β) = Octave.`dB/oct.`(frequency: vDSP.ramp(from: 0, through: 16000, count: 128),
                                      magnitude: vDSP.ramp(from: 10, through: 1, count: 128),
                                      bandwidth: 100...10000)
        print(α, β)
    }
}
