//
//  FSP.swift
//  MUTE
//
//  Created by Kota on 11/14/25.
//
import Testing
import ASP
import DSP
import BSP
import FSP
extension GenTest {
    @Test
    func var1_r() async throws {
        try await scenario(time: .seconds(120)) {
            let (fs, x) = try Buffer.Import(from: .init(filePath: "/tmp/10100_bgm_crows2mix.wav"))
            x.maximize(dB: -6)
            let y = pitchshift(x[t], rate: 0.6)
            let bus = try Output.Direct(sampleRate: fs, source: y)
            $0.append(bus)
        }
    }
    @Test
    func var2_r() async throws {
        try await scenario(time: .seconds(120)) {
            let (fs, y) = try Buffer.Import(from: .init(filePath: "/tmp/jyugyuzu_bgm_wvoice.wav"))
//            let (fs, y) = try Buffer.Import(from: .init(filePath: "/tmp/10100_bgm_crows2mix.wav"))
            y.maximize(dB: -6)
            let r = residual(target: y, var: 28, λ: 0.9999)
//            let r = orthogonalize(y, λ: 0.9999)
            let bus = try Output.Direct(sampleRate: fs, source: clip(10 * r, range: -1 ... 1))
            $0.append(bus)
        }
    }
    @Test
    func lsl_conv() async throws {
        try await scenario(time: .seconds(120)) {
            let (fs, y) = try Buffer.Import(from: .init(filePath: "/tmp/jyugyuzu_bgm_wvoice.wav"))
//            let (_, y) = try Buffer.Import(from: .init(filePath: "/tmp/jyugyuzu_bgm_wvoice.wav"))
//            let (fs, y) = try Buffer.Import(from: .init(filePath: "/tmp/10100_bgm_crows2mix.wav"))
            y.maximize(dB: -6)
            let r = parcor(target: y[0], rls: 24, λ: 0.997)
            let x = uniform(in: -0.01 ... 0.01)
            let z = filter(x, stg: r)
            let bus = try Output.Direct(sampleRate: fs, source: clip(z, range: -1 ... 1))
            $0.append(bus)
        }
    }
    @Test
    func var2_conv() async throws {
        try await scenario(time: .seconds(120)) {
            let (fs, y) = try Buffer.Import(from: .init(filePath: "/tmp/jyugyuzu_bgm_wvoice.wav"))
//            let (_, z) = try Buffer.Import(from: .init(filePath: "/tmp/jyugyuzu_bgm_wvoice.wav"))
//            let (_, z) = try Buffer.Import(from: .init(filePath: "/tmp/10100_bgm_crows2mix.wav"))
            let r = residual(target: y, var: 24, λ: 0.9997)
            let k = kernel(target: y, var: 24, λ: 0.99)
            let w = filter(r, var: k)
            let bus = try Output.Direct(sampleRate: fs, source: clip(w, range: -1 ... 1))
            $0.append(bus)
        }
    }
}
