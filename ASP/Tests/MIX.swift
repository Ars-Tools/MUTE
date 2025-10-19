//
//  MIX.swift
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
import Testing
import AVFoundation
import ASP
import DSP
import Accelerate
@Suite
struct MIXTestCase {
	let gen: AudioComponentDescription
	let mix: AudioComponentDescription
	init() {
		gen = .init(componentType: kAudioUnitType_Generator,
					componentSubType: .init(four: "test"),
					componentManufacturer: .init(four: "@ars"),
					componentFlags: 0,
					componentFlagsMask: 0)
		mix = .init(componentType: kAudioUnitType_Mixer,
					componentSubType: .init(four: "test"),
					componentManufacturer: .init(four: "@ars"),
					componentFlags: 0,
					componentFlagsMask: 0)
		AUAudioUnit.registerSubclass(Universal.self, as: gen, name: "Generator", version: 0)
		AUAudioUnit.registerSubclass(Universal.self, as: mix, name: "Mixer", version: 0)
	}
	@Test
	func scenario() async throws {
		let engine = AVAudioEngine()
		let s220 = try await AVAudioUnit.instantiate(with: gen, options: .loadOutOfProcess)
		if let unit = s220.auAudioUnit as?Universal {
			try unit.append(Output.Direct(sampleRate: 44100, source: sin(freqs: 220, ratio: 0.25)))
			try unit.append(Output.Direct(sampleRate: 44100, source: sin(freqs: 330, ratio: 0.25)))
		}
		let s330 = try await AVAudioUnit.instantiate(with: gen, options: .loadOutOfProcess)
		if let unit = s330.auAudioUnit as?Universal {
			try unit.append(Output.Direct(sampleRate: 44100, source: tri(freqs: 220, ratio: 0.5)))
			try unit.append(Output.Direct(sampleRate: 44100, source: tri(freqs: 330, ratio: 0.5)))
		}
		let mixer = try await AVAudioUnit.instantiate(with: mix, options: .loadOutOfProcess)
		if let unit = mixer.auAudioUnit as?Universal {
			let x = try Input.Direct(sampleRate: 44100, target: 1)
			let y = try Input.Direct(sampleRate: 44100, target: 1)
			let z = stack(x, y)
			unit.append(x)
			unit.append(y)
			try unit.append(Output.Direct(sampleRate: 44100, source: z))
		}
		engine.attach(s220)
		engine.attach(s330)
		engine.attach(mixer)
		engine.connect(s220, to: mixer, fromBus: 0, toBus: 0, format: mixer.inputFormat(forBus: 0))
		engine.connect(s220, to: mixer, fromBus: 1, toBus: 1, format: mixer.inputFormat(forBus: 1))
		engine.connect(mixer, to: engine.mainMixerNode, format: mixer.outputFormat(forBus: 0))
		engine.connect(engine.mainMixerNode, to: engine.outputNode, format: .none)
		try engine.start()
		try await Task.sleep(for: .seconds(3))
		engine.stop()
	}
}
