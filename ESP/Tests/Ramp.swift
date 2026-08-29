//
//  Ramp.swift
//  MUTE
//
//  Created by Kota on 8/29/26.
//
import Testing
@testable import ESP
@Suite
struct RampTestCases {
    @Test
    func linchirp() {
        let x = Ramp.chirp(in: 0.2 ... 0.4, linear: 2048)
        print(x)
    }
    @Test
    func logchirp() {
        let x = Ramp.chirp(in: 0.01 ... 0.4, exponential: 2048)
        print(x)
    }
}
