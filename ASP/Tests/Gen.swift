//
//  Gen.swift
//  MUTE
//
//  Created by Kota on 7/7/R7.
//
import Testing
import MetalPerformanceShadersGraph
import AVFoundation
import ASP
import DSP
import FSP
import Combine
import Accelerate
final class Gen: Universal {
	
}
extension Gen {
	
}
@Suite
struct GenTest {
	let description: AudioComponentDescription
	init() {
		description = .init(componentType: kAudioUnitType_Generator,
							componentSubType: .init(four: "test"),
							componentManufacturer: .init(four: "@ars"),
							componentFlags: 0,
							componentFlagsMask: 0)
		AUAudioUnit.registerSubclass(Gen.self, as: description, name: "Generator", version: 0)
	}
	func scenario(time: Swift.Duration = .seconds(30), _ body: (Universal) throws -> Void) async throws {
		let engine = AVAudioEngine()
		let stream = try await AVAudioUnit.instantiate(with: description, options: .loadOutOfProcess)
		try (stream.auAudioUnit as?Universal).map(body)
		engine.attach(stream)
		engine.connect(stream, to: engine.mainMixerNode, format: .none)
		engine.connect(engine.mainMixerNode, to: engine.outputNode, format: .none)
		try engine.start()
		try await Task.sleep(for: time)
		engine.stop()
		engine.detach(stream)
	}
	@Test
	func ff() async throws {
		try await scenario(time: .seconds(6)) {
			let x = sin(freqs: 330, 440)
			let b = buffer(x, capacity: 12)
			let y = b[fma(sin(freqs: 0.5, 0.6), 0.01, t - 1)]
			let bus = try Output.Direct(sampleRate: 44100, source: x * 0.5)
			$0.append(bus)
		}
	}
//	@Test
//	func fb() async throws {
//		try await scenario(time: .seconds(6)) {
//			let u = uniform(in: 110...440)
//			let p = phasor(freqs: 2)
////			let m = edge(rise: Δₜ(p) < 0)
////			let y = click(trigger: m.map { t in .zero })
//			let f = edge(gate: Δₜ(p) < 0, hold: u)
//			let y = sin(freqs: f) + 3e-6 * u
//			let b = Buffer.RefWeak(count: y.count, capacity: 3)(y.count, capacity: 3)
//			let z = buffer(y + 0.9 * b[t - 0.28])
//			b.source = z
//			let bus = try Output.Direct(sampleRate: 44100, source: z.with(b))
//			$0.append(bus)
//			
//		}
//	}
	@Test
	func playback() async throws {
		try await scenario(time: .seconds(70)) {
			let p = try Playback(path: .init(filePath: "/tmp/1.wav"), loop: false)
			let bus = try Output.Direct(sampleRate: 44100, source: p)
			$0.append(bus)
		}
	}
//	@Test
//	func sith() async throws {
//		try await scenario(time: .seconds(24)) {
//			let r = line(order:
//				.init(position: 200, duration: 0.3),
//				.init(position: 8400, duration: 5.3),
//				.init(duration: 1.8),
//				.init(position: 400, duration: 0.7))
//			let n = buffer(r)
//			let m = buffer(fma(tri(freqs: 0.3, ratio: 0.95), 0.45, 0.5))
//			let x = mix(poly: 6, each: [241.1, 333.2, 390.9, 439.5, 552.7, 580.3].enumerated().publisher.map(\.self)) {
//				filter(tri(freqs: $0, ratio: m), lpf: (n, const(1.8)))
//			}
//			let y = buffer(x.count, capacity: 3)
//			let z = buffer(x.count, capacity: 3)
//			let w = harmonics(x, coefficients: 0, 1, 0e-3, 0e-3) + 0.5 * y[t - 0.7] + 0.3 * z[t - 1.5] + 1e-2 * z[t - 2.8]
//			y.input = w
//			z.input = w
//			let bus = try Output.Direct(sampleRate: 44100, source: 0.3 * w.with(y, z))
//			$0.append(bus)
//		}
//	}
	@Test
	func irmod() async throws {
//		let x = DSP.uniform(in: -1...1, -1...1)
//        let x = try Playback(path: .init(filePath: "/tmp/jongly.aif"), loop: true)
        let x = try buffer(Playback(path: .init(filePath: "/tmp/brushes.aif"), loop: true))
//        let ω = fma(sin(freqs: 0.05, ratio: 0.25, 0.75), 130, 220)
//        let ω = fma(tri(freqs: 0.1, ratio: 0.99), 550, 660)
//		let y = filter(x, lpf: ω, cauer: 12, ε: Utils.ripple(dB: 6), η: Utils.ripple(dB: 60))
//        let y = filter(x, lpf: ω, chebyshev1: 42, ε: 0.05)
//        let y = filter(x, lpf: ω, bessel: 12)
        let ω = fma(sin(freqs: 0.05, ratio: 0.25, 0.75), 2800, 3000)
        let y = filter(x, hpf: ω, cauer: 12, ε: Utils.ripple(dB: 6), η: Utils.ripple(dB: 60))
//        let y = filter(x, lpf: ω, chebyshev1: 60, ε: 0.05)
		try await scenario(time: .seconds(70)) {
            let bus = try Output.Direct(sampleRate: 48000, source: fma(x, 0.01, y))
			$0.append(bus)
		}
	}
	@Test
	func testFilter() async throws {
		let x = uniform(in: -0.5 ... 0.5)
		let y = filter(x, with: ([1], [1, -2 * 0.1 * 0.9, 0.9 * 0.9]))
		try await scenario(time: .seconds(30)) {
			let bus = try Output.Direct(sampleRate: 44100, source: y)
			$0.append(bus)
		}
	}
	@Test
	func filterPrototypes() async throws {
		let x = try Playback(path: .init(filePath: "/tmp/brushes.aif"), loop: true)
//		let y = filter(x, lpf: (const(234), const(0.5.squareRoot())))
//		let y = filter(x, alt: (const(234), const(0, 0, 3), const(1, 3, 3)))
//		let y = filter(x, sos: .lpf(ω₀: 234, quality: 0.5.squareRoot()))
        let z = fma(tri(freqs: 0.03, ratio: 1.0), 895, 900)
//		let y = filter(x, lpf: 420, chebyshev1: 16000, ε: 0.05)
//        let y = filter(x, apf: 420, butterworth: 12000)
        
		let y = filter(x, apf: z, butterworth: 500)
//		let y = filter(x, lpf: z, chebyshev1: 600, ε: 0.03)
//		let y = filter(x, lpf: 600, chebyshev1: 8000, ε: 0.03)
//		let y = filter(x, lpf: 500, chebyshev1: 8000, ε: 0.03) // LPF!!!
//		let y = filter(x, alt: 440, Hₛ: (.init(1, 0, 0), .init(1, 2.0.squareRoot(), 1)))
//		let y = filter(x, lpf: z, bessel: 7)
//		let y = filter(x, lpf: 144, butterworth: 6)
//		let y = filter(x, lpf: z, chebyshev1: 30, ε: 0.01)
//		let y = filter(x, lpf: z, chebyshev2: 6, ε: 0.01)
//		let y = filter(x, lpf: z, cauer: 12, ε: ripple(dB: 3), η: ripple(dB: 50))
//		let y = filter(x, sos: .lpf(ω₀: 144, quality: 0.5.squareRoot()), .lpf(ω₀: 144, quality: 0.5.squareRoot()))
		try await scenario(time: .seconds(420)) {
			let bus = try Output.Direct(sampleRate: 44100, source: y)
			$0.append(bus)
		}
	}
	@Test
	func testLattice() async throws {
		let x = pulse(freqs: 1) + uniform(in: -0.01 ... 0.01)
//		let y = filter(x, bpf: (fma(sin(freqs: 0.1), 500, 1000), const(10)))
//		let x = uniform(in: -1 ... 1)
		let e = try Playback(path: .init(filePath: "/tmp/jyugyuzu_bgm_wvoice.wav"))
//		let f = try Playback(path: .init(filePath: "/tmp/jyugyuzu_bgm_wvoice.wav"))
//		let z = buffer(y)
//		let x2 = residual(target: e[0..<1], sgd: 8, μ: 1e-3)
		let x2 = residual(target: e[0..<1], rls: 12, λ: 0.99)
		let y = inject(kernel(target: e[0..<1], rls: 24, λ: Utils.forget(factor: 0.98, per: 1200))) {
			let packet = zip(stride(from: 0, to: $3, by: $3).lazy.map($2.advanced(by:)), sequence(first: $1, next: \.self)).map(UnsafeMutableBufferPointer.init(start:count:))
			let max = vDSP.maximum(packet.map(vDSP.maximum))
			let min = vDSP.minimum(packet.map(vDSP.minimum))
			guard -1.0 <= min, max <= 1.0 else {
				print("anomaly detected", min, max)
				return
			}
		}
//		let x = residual(target: e[0..<1], sgd: 24, μ: 1e-2)
//		let y = parcor(target: f[0..<1], sgd: 24, μ: 1e-2)
		let z = filter(x, stg: clip(y, range: -0.98 ... 0.98))
        let a = filter(clip(x2, range: -1 ... 1), apf: 500, butterworth: 8000)
//        let a = filter(clip(x2, range: -1 ... 1), lpf: 500, chebyshev1: 8000, ε: 0.05)
		
		try await scenario(time: .seconds(300)) {
			let bus = try Output.Direct(sampleRate: 44100, source: 10 * clip(a, range: -1 ... 1))
			$0.append(bus)
		}
	}
	@Test
	func qslerp() async throws {
		let p = phasor(freqs: 110)
        let x = slerp(phasor: p, s: simd_quaternion(0.5, 0, 0, 0.2), t: simd_quatd(ix: 0, iy: 0.5, iz: 0.5, r: 0.3))
		try await scenario(time: .seconds(10)) {
			let bus = try Output.Direct(sampleRate: 44100, source: 0.5 * x[2..<3])
			$0.append(bus)
		}
	}
	@Test
	func adaptive() async throws {
		let source = try buffer(Playback(path: .init(filePath: "/tmp/01.m4a"))[0..<1])// + uniform(in: -0.1 ... 0.1)
//		let source = uniform(in: -0.1 ... 0.1)
		let target = filter(source, sos: .raw(b₀: 0.5, b₁: 1, b₂: 0.5, a₁: 0, a₂: 0))
//		let target = try Playback(path: .init(filePath: "/tmp/jyugyuzu_bgm_wvoice.wav"))[1..<2]
		let r = inject(residual(target: target, source: source, lsl: 6, λ: 0.98)) {
//		let r = inject(residual(target: target, source: source, sgd: 80, μ: 0.003)) {
//		let r = inject(residual(target: target, source: source, rls: 80, λ: 0.98)) {
//		let r = inject(0.01 * residual(target: source, source: target, ftf: 100, λ: 0.999)) {
			let packet = zip(stride(from: 0, to: $3, by: $3).lazy.map($2.advanced(by:)), sequence(first: $1, next: \.self)).map(UnsafeMutableBufferPointer.init(start:count:))
			let max = vDSP.maximum(packet.map(vDSP.maximum))
			let min = vDSP.minimum(packet.map(vDSP.minimum))
			guard -1.0 <= min, max <= 1.0 else {
				print("anomaly detected", min, max)
				return
			}
			print($2[$3*0])
		}
//		let r = residual(target: source, source: target, sgd: 200, μ: 0.01)
		try await scenario(time: .seconds(60)) {
			let bus = try Output.Direct(sampleRate: 44100, source: clip(r, range: -1 ... 1))
			$0.append(bus)
		}
	}
	@Test
	func GSO() async throws {
		let a = sin(freqs: 330)
		let b = sin(freqs: 220)
		let c = sin(freqs: 110)
		
		let x = 0.3 * stack(a + b + c, 0.5 * b, b + 0.1 * c)
		let y = orthogonalize(x, λ: 0.999)
		try await scenario(time: .seconds(12)) {
			let bus = try Output.Direct(sampleRate: 44100, source: clip(y[0..<1], range: -1 ... 1))
			$0.append(bus)
		}
	}
	@Test
	func duffing() async throws {
		let y = filter(sin(freqs: 0.1), duffing: .lpf(ω₀: 600, quality: 2.0.squareRoot()), αβ: .init(127/128, 1/128.0))
		let x = 0.3 * tri(freqs: inject(fma(y, 110, 220)) {
			print($2[0*$3])
		}, ratio: 0.5)
		try await scenario(time: .seconds(120)) {
			let bus = try Output.Direct(sampleRate: 44100, source: x)
			$0.append(bus)
		}
	}
}
