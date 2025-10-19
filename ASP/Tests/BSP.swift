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
extension GenTest {
    @Test
    func ps() async throws {
        try await scenario(time: .seconds(120)) {
            let x = try Playback(path: .init(filePath: "/tmp/crow.wav"), loop: false)
            let y = filter(x, sos: .lpf(ω₀: 8000, quality: 0.5.squareRoot()))
            let z = pitchshift(y, rate: 0.5)
            let bus = try Output.Direct(sampleRate: 48000, source: z)
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
}
