//
//  Comb.swift
//  MUTE
//
//  Created by Kota on 10/15/25.
//
import Testing
import DSP
import BSP
@Suite
struct CombTestCases {
    @Test
    func apf() throws {
        let x = pulse(freqs: 1e-6)
        let y = filter(x, apf: (64 as Samples, 0.9))
        let m = try Buffer(stream: 1, period: 8192, backing: "/tmp/dump.raw", release: false)
        try m.import(stream: y, interval: .init(value: 1, timescale: 1024))
    }
}
