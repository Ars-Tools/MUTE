//
//  MIDI+Subscriber.swift
//  MUTE
//
//  Created by Kota on 7/20/R7.
//
import Testing
import DSP
import MIDI
@testable import ASP
@preconcurrency import AVFoundation
@Suite
struct MIDITestCase {
	let dspDesc: AudioComponentDescription
	init() {
		MIDIRestart()
		dspDesc = .init(componentType: kAudioUnitType_MusicDevice,
						componentSubType: en(code: "test"),
						componentManufacturer: en(code: "@ars"),
						componentFlags: 0, componentFlagsMask: 0)
		AUAudioUnit.registerSubclass(Universal.self, as: dspDesc, name: "DSP", version: 0)
	}
	@Test
	func relay() async throws {
		let subDesc = AudioComponentDescription(componentType: kAudioUnitType_MIDIProcessor,
												componentSubType: en(code: "sub1"),
												componentManufacturer: en(code: "@ars"),
												componentFlags: 0, componentFlagsMask: 0)
		AUAudioUnit.registerSubclass(MIDISubscriber.self, as: subDesc, name: "MIDI Subscriber", version: 0)
		let sub = try await AVAudioUnit.instantiate(with: subDesc)
		if let u = sub.auAudioUnit as?MIDISubscriber, let pt = u.parameterTree, let p = pt.parameter(withAddress: 0) {
			let available = (0...).lazy.map {
				p.description(of: .init($0))
			}.prefix {
				!$0.isEmpty
			}
			let list = Array(available)
			if let found = list.firstIndex(of: "from Max 1") {
				p.value = .init(found)
			} else {
				Issue.record()
			}
//			if let found = list.firstIndex(of: "Keystage KBD/CTRL") {
//				p.value = .init(found)
//			}
		}
		
		let pubDesc = AudioComponentDescription(componentType: kAudioUnitType_MIDIProcessor,
												componentSubType: en(code: "pub1"),
												componentManufacturer: en(code: "@ars"),
												componentFlags: 0, componentFlagsMask: 0)
		AUAudioUnit.registerSubclass(MIDITransmitter.self, as: pubDesc, name: "MIDI Publisher", version: 0)
		let pub = try await AVAudioUnit.instantiate(with: pubDesc)
		if let u = pub.auAudioUnit as?MIDITransmitter, let pt = u.parameterTree, let p = pt.parameter(withAddress: 0) {
			let available = (0...).lazy.map {
				p.description(of: .init($0))
			}.prefix {
				!$0.isEmpty
			}
			let list = Array(available)
			if let found = list.firstIndex(of: "to Max 1") {
				p.value = .init(found)
			} else {
				Issue.record()
			}
		}
		
		let dsp = try await AVAudioUnit.instantiate(with: dspDesc)
		if let u = dsp.auAudioUnit as?Universal {
			let o = try Output.Direct(sampleRate: 44100, source: sin(freqs: 150) * 0.0)
			u.append(o)
		}
		
		let engine = AVAudioEngine()
		engine.attach(sub)
		engine.attach(pub)
		engine.attach(dsp)
		
		engine.connectMIDI(sub, to: pub, format: .init(sampleRate: 44100, monoChannels: 1))
		engine.connectMIDI(pub, to: dsp, format: .init(sampleRate: 44100, monoChannels: 1))
		engine.connect(dsp, to: engine.mainMixerNode, format: dsp.outputFormat(forBus: 0))
		engine.connect(engine.mainMixerNode, to: engine.outputNode, format: engine.outputNode.inputFormat(forBus: 0))
		
		engine.prepare()
		try engine.start()
		try await Task.sleep(for: .seconds(12))
		
		engine.stop()
		engine.detach(dsp)
		engine.detach(pub)
		engine.detach(sub)
		
	}
}
