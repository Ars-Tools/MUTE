//
//  Buffer.swift
//  MUTE
//
//  Created by Kota on 7/16/R7.
//
import Testing
import AVFoundation
import DSP
import BSP
import FSP
@testable import ASP
@Suite
struct BufferTestCases {
    func ambient() throws -> DSP.Stream {
        let (fs, source) = try Buffer.Import(from: .init(filePath: "/tmp/audio.wav"))
        source.reverse()
        var stretched = Buffer(stream: source.stream,
                               period: 60 * source.period)
        source.stretch(to: &stretched)
        
        let dry = filter(filter(stretched, apf: (lag: 0.2, gain: 0.9)),
                         lpf: 18000, chebyshev1: 50, ε: 0.05)
        let low = filter(filter(pitchshift(stretched, rate: 2.0 / 3.0),
                                apf: (lag: 0.3, gain: 0.8)),
                         lpf: 8000, chebyshev1: 50, ε: 0.05)
        let high = filter(filter(pitchshift(stretched, rate: 1.5),
                                 apf: (lag: 0.5, gain: 0.7)),
                          lpf: 12000, chebyshev1: 50, ε: 0.05)
        return dry + low + high
    }
	@Test
	func pv() throws {
        let (fs, source) = try Buffer.Import(from: .init(filePath: "/tmp/audio.wav"))
        source.reverse()
//        try Buffer.Export(into: .init(filePath: "/tmp/step1-rev.wav"), rate: fs, data: source)
//        var target = try Buffer(stream: source.stream, period: 60 * source.period, backing: "/tmp/pv.raw", release: false)
//        source.stretch(to: &target, log2n: 16)
//        target.maximize()
//        try Buffer.Export(into: .init(filePath: "/tmp/output7.wav"), rate: fs, data: target)
        let x = try Buffer.Import(from: .init(filePath: "/tmp/output5.wav")).1
        
//        let x = try buffer(Playback(path: .init(filePath: "/tmp/output5.wav"), loop: true))
//        let y = filter(filter(x, apf: (lag: 0.2, gain: 0.9)), lpf: 18000, chebyshev1: 50, ε: 0.05)
//        let z = filter(filter(pitchshift(x, rate: 2.0 / 3.0), apf: (lag: 0.3, gain: 0.8)), lpf: 8000, chebyshev1: 50, ε: 0.05)
//        let w = filter(filter(pitchshift(x, rate: 1.5), apf: (lag: 0.5, gain: 0.7)), lpf: 12000, chebyshev1: 50, ε: 0.05)
        
//        let target = Buffer(stream: x.stream, period: x.period)
//        try target.import(stream: y + z + w, interval: .init(value: 1, timescale: .init(fs)))
//        target.maximize()
        try Buffer.Export(into: .init(filePath: "/tmp/step-3.wav"), rate: fs, data: x)
	}
}
