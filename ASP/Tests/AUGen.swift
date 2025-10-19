//
//  AUGen.swift
//  MUTE
//
//  Created by Kota on 5/15/R7.
//
//import Testing
//import Combine
//import Dispatch
//import CLK
//import Accelerate
//@preconcurrency import AVFoundation
//@preconcurrency import MetalPerformanceShaders
//@preconcurrency import MetalPerformanceShadersGraph
//@preconcurrency import AVFoundation
//@preconcurrency import CoreAudioKit
//import MSP
//@testable import AUv3
//@Suite
//struct AUGen {
//	let component: AudioComponentDescription
//	init() throws {
//		component = AudioComponentDescription(componentType: kAudioUnitType_Generator,
//											  componentSubType: kAudioUnitSubType_MIDISynth,
//											  componentManufacturer: kAudioUnitManufacturer_Apple,
//											  componentFlags: 0, componentFlagsMask: 0)
//		AUAudioUnit.registerSubclass(Generator.self, as: component, name: "Generator", version: 0)
//	}
//	func scenario(time: Swift.Duration = .seconds(30), _ body: (Generator) throws -> Void) async throws {
//		let engine = AVAudioEngine()
//		let stream = try await AVAudioUnit.instantiate(with: component, options: .loadOutOfProcess)
//		try (stream.auAudioUnit as?Generator).map(body)
//		engine.attach(stream)
//		engine.connect(stream, to: engine.mainMixerNode, format: .none)
//		engine.connect(engine.mainMixerNode, to: engine.outputNode, format: .none)
//		try engine.start()
//		try await Task.sleep(for: time)
//		engine.stop()
//	}
//	@Test
//	func osc() async throws {
//		try await scenario(time: .seconds(10)) {
//			let x = tri(freqs: 220.0, ratio: fma(sin(freqs: 6), 0.3, 0.5))
//			let y = tri(freqs: 274.0, ratio: fma(sin(freqs: 6.2), 0.2, 0.5))
//			let z = rec(freqs: 330.0, ratio: fma(sin(freqs: 6.4), 0.1, 0.5))
//			let w = filter(x + y + z, lpf: (ω₀: fma(sin(freqs: 7.3), 800, 900), quality: const(0.75)))
//			try $0.outputs.append(.init(sampleRate: 44100, source: 0.5 * w))
//		}
//	}
//	@Test
//	func div() async throws {
//		try await scenario(time: .seconds(10)) {
//			let c = 0.1 * sin(freqs: 330)
//			let m = fma(sin(freqs: 220), 0.8, 1.0)
////			let y = filter(u, bpf: (fma(sin(freqs: 3), 30, 300), const(9)))
//			try $0.outputs.append(.init(sampleRate: 44100, source: c / m))
//		}
//	}
//	@Test
//	func noise_lpf() async throws {
//		try await scenario(time: .seconds(10)) {
//			let u = uniform(in: -0.5...0.5)
//			let y = filter(u, cascade: .lpf(ω₀: 400, quality: 9))
////			let y = filter(u, bpf: (fma(sin(freqs: 3), 30, 300), const(9)))
//			try $0.outputs.append(.init(sampleRate: 44100, source: y))
//		}
//	}
//	@Test
//	func noise_svf() async throws {
//		try await scenario(time: .seconds(10)) {
//			let u = uniform(in: -0.5...0.5)
//			let y = filter(u, svf: (ω₀: 300, quality: 4.5))
//			let b = buffer(y)
//			try $0.outputs.append(.init(sampleRate: 44100, source: b[0]))
//		}
//	}
//	@Test
//	func pulsef() async throws {
//		try await scenario(time: .seconds(60)) {
//			let x = pulse(freqs: fma(sin(freqs: 0.1), 20, 400))
//			let y = filter(x, cascade: .lpf(ω₀: 600, quality: 6))
//			try $0.outputs.append(.init(sampleRate: 48000, source: y))
//		}
//	}
//	@Test
//	func playback() async throws {
//		try await scenario(time: .seconds(60)) {
//			let b = try AVAudioFile(forReading: .init(filePath: "/tmp/01.m4a"))
////			let s = b[t]
////			let m = buffer(s)[0]
////			let s = b[1][fma(sin(freqs: 3), 0.001, -t)]
////			let s = oversample(b[t], factor: 3, smooth: .rect(3))
//			let s = undersample(b[t], factor: .init(1, 6))
//			try $0.outputs.append(.init(sampleRate: 48000, source: s))
//		}
//	}
//	@Test
//	func wavetable() async throws {
//		try await scenario(time: .seconds(30)) {
//			let b = [vForce.sinPi(vDSP.ramp(from: 0.0, through: 4.0, count: 256))]
////			let s = try AVAudioFile(forReading: .init(filePath: "/tmp/01.m4a"))
////			let b = buffer(s[t + 60], capacity: 1)
//			let k = b(phase: 0.5 * phasor(freqs: 220) + 0.5 * sin(freqs: 0.5))
//			try $0.outputs.append(.init(sampleRate: 44100, source: k))
//		}
//	}
//	@Test
//	func echo_iir() async throws {
//		try await scenario(time: .seconds(60)) {
//			let s = try AVAudioFile(forReading: .init(filePath: "/tmp/01.m4a"))
//			let r = buffer(count: 2)
//			let b = buffer(s[t] + 0.6 * r[fma(sin(freqs: 0.3), 0.05, t - 1)], capacity: 30)
//			r.target = b.target
//			try $0.outputs.append(.init(sampleRate: 44100, source: b))
//		}
//	}
//	@Test
//	func svf() async throws {
//		try await scenario(time: .seconds(60)) {
//			let s = try AVAudioFile(forReading: .init(filePath: "/tmp/01.m4a"))
//			let r = filter(s[-t], svf: (444, 6.0))
//			let x = buffer(r)
//			#expect(x.count == 6)
//			let l = x[0..<2] * fma(sin(freqs: 2), 0.5, 0.5)
//			let b = x[2..<4] * fma(sin(freqs: 3), 0.5, 0.5)
//			let h = x[4..<6] * fma(sin(freqs: 5), 0.5, 0.5)
//			let y = l + b + h
//			try $0.outputs.append(.init(sampleRate: 44100, source: y))
//		}
//	}
//	@Test
//	func cheby() async throws {
//		try await scenario(time: .seconds(60)) {
//			let f = fma(phasor(freqs: 0.05), 1200, 100)
//			print(f.count)
//			let x = sin(freqs: f)
//			assert(x.count == 1)
//			print(x.count)
//			let y = harmonics(x, coefficients: [0, 0.5, 0.1, 0.7, 0.03, 0.1, 0.07])
//			print(y.count)
//			try $0.outputs.append(.init(sampleRate: 44100, source: 0.1 * y))
//		}
//	}
//	@Test
//	func timer() async throws {
//		try await scenario(time: .seconds(60)) {
//			let timer = try CMTimebase(sourceClock: .hostTimeClock)
//			try timer.set(rate: 1)
//			let s = PassthroughSubject<CurrentValueSubject<(CMTime, MSP.Stream), Never>, Never>()
//			let p = mix(source: s, output: 2)
//			Task {
//				for try await _ in timer.tick(every: .init(duration: .seconds(2))) {
//					let v = CurrentValueSubject<(CMTime, MSP.Stream), Never>((CMTime.indefinite, 0.5 * sin(freqs: Float64.random(in: 220...400))))
//					s.send(v)
//					Task {
//						try await Task.sleep(for: .seconds(5))
//						v.send(completion: .finished)
//					}
//				}
//			}
//			try $0.outputs.append(.init(sampleRate: 44100, source: p))
//		}
//	}
//	@Test
//	func mps() async throws {
//		try await scenario(time: .seconds(60)) {
//			let thread = MTLCreateSystemDefaultDevice().flatMap { $0.makeCommandQueue() }.unsafelyUnwrapped
//			let x = phasor(freqs: 440, 550)
////			let y = 0.1 * sinπ(2 * x)
//			let y = framewise(x, window: .rectangular(0.5), stride: .relative(1), output: 1, thread: thread) {
//				let w = Array<Float32>(repeating: 1, count: 2)
// 				let p = $1.multiplication($1.constant(2.0 * .pi, dataType: .float32), $3, name: .none)
//				let s = $1.sin(with: p, name: .none)
//				let k = $1.constant(w.withUnsafeBytes { Data($0) }, shape: [1, 2], dataType: .float32)
//				let y = $1.matrixMultiplication(primary: k, secondary: s, name: .none)
//				return $1.multiplication($1.constant(0.1, dataType: .float32), y, name: .none)
//			}
//			try $0.outputs.append(.init(sampleRate: 44100, source: y))
//		}
//	}
////	@Test
////	func fmsin() async throws {
////		try await scenario(time: .seconds(10)) {
////			let f = fma(sin(freqs: 1), 10, 200)
////			let y = 0.3 * sin(freqs: f)
////			try $0.outputs.append(.init(sampleRate: 44100, source: y))
////		}
////	}
//}
