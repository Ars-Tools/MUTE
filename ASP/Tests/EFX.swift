//
//  EFX.swift
//  MUTE
//
//  Created by Kota on 7/7/R7.
//
import Testing
import AVFoundation
import ASP
import DSP
import Accelerate
@Suite
struct EFXTestCase {
	let gen: AudioComponentDescription
	let efx: AudioComponentDescription
	init() {
		gen = .init(componentType: kAudioUnitType_Generator,
					componentSubType: .init(four: "test"),
					componentManufacturer: .init(four: "@ars"),
					componentFlags: 0,
					componentFlagsMask: 0)
		efx = .init(componentType: kAudioUnitType_Effect,
					componentSubType: .init(four: "test"),
					componentManufacturer: .init(four: "@ars"),
					componentFlags: 0,
					componentFlagsMask: 0)
		AUAudioUnit.registerSubclass(Universal.self, as: gen, name: "Generator", version: 0)
		AUAudioUnit.registerSubclass(Universal.self, as: efx, name: "Effector", version: 0)
	}
	func scenario(time: Swift.Duration = .seconds(30), _ body: (Universal) throws -> Void) async throws {
		let engine = AVAudioEngine()
		let phasor = try await AVAudioUnit.instantiate(with: gen, options: .loadOutOfProcess)
		if let unit = phasor.auAudioUnit as?Universal {
			let p = DSP.sin(freqs: 220, ratio: 0.25)
			let q = inject(p) {
				for target in stride(from: 0, to: $3, by: $3).lazy.map($2.advanced(by:)) {
					
				}
			}
			let x = try Output.Direct(sampleRate: 44100, source: q)
			unit.append(x)
		}
		let stream = try await AVAudioUnit.instantiate(with: efx, options: .loadOutOfProcess)
		if let unit = stream.auAudioUnit as?Universal {
			do {
				let x = try Input.WithConverter(sampleRate: 48000, target: 1)
				let y = try Output.Direct(sampleRate: 48000, source: x)
				unit.append(x)
				unit.append(y)
			} catch {
				print(error)
				throw error
			}
		}
		engine.attach(phasor)
		engine.attach(stream)
		engine.connect(phasor, to: stream, fromBus: 0, toBus: 0, format: phasor.outputFormat(forBus: 0))
		engine.connect(stream, to: engine.mainMixerNode, fromBus: 0, toBus: 0, format: stream.outputFormat(forBus: 0))
		engine.connect(engine.mainMixerNode, to: engine.outputNode, format: .none)
		print(phasor.outputFormat(forBus: 0))
		print(stream.inputFormat(forBus: 0), stream.outputFormat(forBus: 0))
		try engine.start()
		try await Task.sleep(for: time)
		engine.stop()
	}
	@Test
	func thru() async throws {
		try await scenario(time: .seconds(6)) { u in
			
		}
	}
}
