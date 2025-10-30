//
//  BSP.swift
//  MUTE
//
//  Created by Kota on 10/14/25.
//
import Testing
import ASP
import DSP
import BSP
import FSP
import Numerics
extension GenTest {
    @Test
    func ps() async throws {
        try await scenario(time: .seconds(120)) {
            let (fs, x) = try Buffer.Import(from: .init(filePath: "/tmp/audio.wav"))
            x.maximize(dB: -6)
            let y = pitchshift(x[t], rate: 0.6)
            let bus = try Output.Direct(sampleRate: fs, source: y)
            $0.append(bus)
        }
    }
    @Test
    func ts() async throws {
        try await scenario(time: .seconds(120)) {
            let (fs, x) = try Buffer.Import(from: .init(filePath: "/tmp/audio.wav"))
            x.maximize(dB: -6)
            let y = timestretch(x, rate: 2.0)
            let bus = try Output.Direct(sampleRate: fs, source: y)
            $0.append(bus)
        }
    }
    @Test
    func realtimestrech() async throws {
        try await scenario(time: .seconds(450)) {
            let (fs, x) = try Buffer.Import(from: .init(filePath: "/tmp/audio.wav"))
            x.maximize(dB: -3)
            x.reverse()
            let y = timestretch(x, rate: 1 / 60.0)
            let z = buffer(filter(y, lpf: fma(sin(freqs: 0.03), 4000, 12000), chebyshev1: 42, ε: 0.1))
//            let a = filter(z, apf: (lag: 0.3, 0.9))
            let s = filter(pitchshift(z, rate: 1 * 1.5), apf: (lag: 0.9, 0.3))
            let a = filter(pitchshift(z, rate: 5 / 4.0), apf: (lag: 0.7, 0.5))
            let t = filter(           z,                 apf: (lag: 0.3, 0.7))
            let b = filter(pitchshift(z, rate: 1 / 1.5), apf: (lag: 0.5, 0.9))
            let bus = try Output.Direct(sampleRate: fs, source: Σ(b, t, a, s, axis: .term))
            $0.append(bus)
        }
    }
    @Test
    func apf() async throws {
        try await scenario(time: .seconds(120)) {
            let x = try Playback(path: .init(filePath: "/tmp/audio.wav"), loop: true)
            let y = filter(buffer(x), apf: (0.6, 0.9))
            let bus = try Output.Direct(sampleRate: 48000, source: y)
            $0.append(bus)
        }
    }
    @Test
    func sr() async throws {
        try await scenario(time: .seconds(60 * 11)) {
            let x = try buffer(Playback(path: .init(filePath: "/tmp/output5.wav"), loop: true))
            let y = filter(filter(x, apf: (lag: 0.2, gain: 0.9)), lpf: 18000, chebyshev1: 50, ε: 0.05)
            let z = filter(filter(pitchshift(x, rate: 2.0 / 3.0), apf: (lag: 0.3, gain: 0.8)), lpf: 8000, chebyshev1: 50, ε: 0.05)
            let w = filter(filter(pitchshift(x, rate: 1.5), apf: (lag: 0.5, gain: 0.7)), lpf: 12000, chebyshev1: 50, ε: 0.05)
//            let x = try buffer(filter(Playback(path: .init(filePath: "/tmp/output3.wav"), loop: true), lpf: 8000, chebyshev1: 40, ε: 0.05))
//            let y = filter(x, apf: (lag: 0.2, gain: 0.9))
//            let z = filter(pitchshift(x, rate: 2.0 / 3.0), apf: (lag: 0.3, gain: 0.8))
//            let w = filter(pitchshift(x, rate: 2.0), apf: (lag: 0.5, gain: 0.7))
            let bus = try Output.Direct(sampleRate: 48000, source: y + z + w)
            $0.append(bus)
        }
    }
    @Test
    func render() throws {
        let (fs, x) = try Buffer.Import(from: .init(filePath: "/tmp/short.mp3"), backing: "/tmp/tmp.raw")
        x.maximize(dB: -6)
//        x.reverse()
        let y = timestretch(x, rate: 30)
        let z = buffer(filter(y, lpf: fma(sin(freqs: 0.06), 4000, 12000), chebyshev1: 60, ε: 0.2))
//            let a = filter(z, apf: (lag: 0.3, 0.9))
        let s = filter(pitchshift(z, rate: 4 / 3.0), apf: (lag: 0.9, 0.4))
        let t = filter(           z,                 apf: (lag: 0.3, 0.8))
        let a = filter(pitchshift(z, rate: 2 / 3.0), apf: (lag: 0.7, 0.6))
        let b = filter(pitchshift(z, rate: 1 / 2.0), apf: (lag: 0.5, 0.9))
        
        let store = Buffer(stream: x.stream, period: x.period * 28)
        try store.import(stream: Σ(b, t, a, s, axis: .term), interval: .init(value: 1, timescale: .init(fs)), capacity: 4096 as Samples)
        store.fade(out: .init(fs * 6), dB: -60)
        try Buffer.Export(into: .init(filePath: "/tmp/amb8.wav"), rate: fs, data: store)
    }
    @Test
    func opus2() throws {
        let (fs, x) = try Buffer.Import(from: .init(filePath: "/tmp/ol.mp3"))
        x.maximize(dB: -6)
        x.reverse()
        let y = timestretch(x, rate: 42)
        let z = buffer(filter(y, lpf: fma(sin(freqs: 0.2), 6000, 12000), chebyshev1: 60, ε: 0.2))
//            let a = filter(z, apf: (lag: 0.3, 0.9))
        let s = filter(pitchshift(z, rate: 7 / 3.0), apf: (lag: 0.9, 0.4))
        let t = filter(           z,                 apf: (lag: 0.3, 0.8))
        let a = filter(pitchshift(z, rate: 2 / 3.0), apf: (lag: 0.7, 0.6))
        let b = filter(pitchshift(z, rate: 1 / 2.0), apf: (lag: 0.5, 0.9))
        
        let store = Buffer(stream: x.stream, period: x.period * 40)
        try store.import(stream: Σ(b, t, a, s, axis: .term), interval: .init(value: 1, timescale: .init(fs)), capacity: 4096 as Samples)
        store.fade(in: .init(fs * 6), dB: -60)
        store.fade(out: .init(fs * 6), dB: -60)
        try Buffer.Export(into: .init(filePath: "/tmp/amb13.wav"), rate: fs, data: store)
    }
}
