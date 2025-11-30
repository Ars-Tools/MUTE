//
//  DSP.swift
//  MUTE
//
//  Created by Kota on 11/30/25.
//
import Testing
import ASP
import DSP
import Numerics
extension GenTest {
    @Test
    func delay_ff() async throws {
        try await scenario(time: .seconds(12)) {
//            let (fs, x) = try Buffer.Import(from: .init(filePath: "/tmp/audio.wav"))
//            x.maximize(dB: -6)
            let fs = 44100.0
            let x = pulse(freqs: 1)
//            let x = 0.5 * sin(freqs: 220)
            let y = buffer(x, capacity: 0.5)
            let z = buffer(y(t) + y(t-0.1), capacity: 0.5)
            let w = z(t) + z(t-0.2)
            let bus = try Output.Direct(sampleRate: fs, source: w)
//            let bus = try Output.Direct(sampleRate: fs, source: 0.3 * w)
            $0.append(bus)
        }
    }
    @Test
    func delay_fb() async throws {
        try await scenario(time: .seconds(12)) {
//            let (fs, x) = try Buffer.Import(from: .init(filePath: "/tmp/audio.wav"))
//            x.maximize(dB: -6)
            let fs = 44100.0
            let x = pulse(freqs: 1)
            let (w, r) = buffer(x.count, capacity: 5)
            w.source = x + 0.9 * r[t-0.1]
//            let bus = try Output.Direct(sampleRate: fs, source: r.depends(on: w))
            let bus = try Output.Direct(sampleRate: fs, source: r[t-0.5])
            $0.append(bus)
        }
    }
}
