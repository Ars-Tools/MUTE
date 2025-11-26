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
    func cross() async throws {
        try await scenario(time: .seconds(420)) {
            let (fs, y0) = try Buffer.Import(from: .init(filePath: "/tmp/10100_bgm_crows2mix.wav"))
            let (_, y1) = try Buffer.Import(from: .init(filePath: "/tmp/Double Snare Beat 01.caf"))
            let k0 = kernel(target: y0[0][t], var: 12, λ: 0.9998)
            let k1 = kernel(target: y1[0][t], var: 12, λ: 0.9998)
            let r0 = residual(target: y0[0][t], var: 12, λ: 0.9998)
            let r1 = residual(target: y1[0][t], var: 12, λ: 0.9998)
            let z = filter(r0, stg: k1)
            let bus = try Output.Direct(sampleRate: fs, source: clip(z, range: -1 ... 1))
            $0.append(bus)
        }
    }
    @Test
    func var1_r() async throws {
        try await scenario(time: .seconds(120)) {
            let (fs, y) = try Buffer.Import(from: .init(filePath: "/tmp/10100_bgm_crows2mix.wav"))
            y.maximize(dB: -6)
            let r = residual(target: y[0], var: 28, λ: 0.99)
            let bus = try Output.Direct(sampleRate: fs, source: r)
            $0.append(bus)
        }
    }
    @Test
    func var2_r() async throws {
        try await scenario(time: .seconds(360)) {
            let (fs, y) = try Buffer.Import(from: .init(filePath: "/tmp/jyugyuzu_bgm_wvoice.wav"))
//            let (fs, y) = try Buffer.Import(from: .init(filePath: "/tmp/10100_bgm_crows2mix.wav"))
            y.maximize(dB: -6)
            let r = residual(target: y, var: 42, λ: 0.99)
//            let r = orthogonalize(y, λ: 0.9999)
            let bus = try Output.Direct(sampleRate: fs, source: clip(r, range: -1 ... 1))
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
            let r = kernel(target: y[0], rls: 42, λ: 0.997)
            let x = uniform(in: -0.01 ... 0.01)
            let z = filter(x, stg: r)
            let bus = try Output.Direct(sampleRate: fs, source: clip(z, range: -1 ... 1))
            $0.append(bus)
        }
    }
    @Test
    func var2_conv() async throws {
        try await scenario(time: .seconds(120)) {
//            let (fs, y) = try Buffer.Import(from: .init(filePath: "/tmp/jyugyuzu_bgm_wvoice.wav"), backing: "/tmp/backing.tmp")
            let (fs, y) = try Buffer.Import(from: .init(filePath: "/tmp/10100_bgm_crows2mix.wav"), backing: "/tmp/backing.tmp")
            let r = kernel(target: y, var: 42, λ: 0.997)
            let x = uniform(in: -0.01 ... 0.01, -0.01 ... 0.01)
            let z = filter(x, var: r)
            let bus = try Output.Direct(sampleRate: fs, source: clip(z, range: -1 ... 1))
            $0.append(bus)
        }
    }
}
