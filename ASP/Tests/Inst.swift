//
//  Inst.swift
//  MUTE
//
//  Created by Kota on 7/7/R7.
//
import Testing
import AVFoundation
//import MSP
import Combine
import ASP

//struct InstTest {
//	let source: AudioComponentDescription
//	let target: AudioComponentDescription
//	
//	init() {
//		source = .init(componentType: kAudioUnitType_MIDIProcessor,
//					   componentSubType: 0, // This might be problematic for a MIDIProcessor
//					   componentManufacturer: .init(code: "@ars"),
//					   componentFlags: 0,
//					   componentFlagsMask: 0)
//		target = .init(componentType: kAudioUnitType_MusicDevice,
//					   componentSubType: 0,
//					   componentManufacturer: .init(code: "@ars"),
//					   componentFlags: 0,
//					   componentFlagsMask: 0)
//		AUAudioUnit.registerSubclass(MIDIUnit.self, as: source, name: "gen", version: 0)
//		AUAudioUnit.registerSubclass(UnitUniversal.self, as: target, name: "ins", version: 0)
//	}
//	@Test
//	func eval() async throws {
//		let engine = AVAudioEngine()
//		let player = try await AVAudioUnit.instantiate(with: source)
//		if let unit = player.auAudioUnit as?MIDIUnit {
//			unit.addMIDIPort(name: "TARGET")
//		}
//		let stream = try await AVAudioUnit.instantiate(with: target)
//		if let unit = stream.auAudioUnit as?UnitUniversal {
//			try unit.addBusOutput(sampleRate: 16000, source: φ(count: 1))
//		}
//		engine.attach(player)
//		engine.attach(stream)
//		engine.connect(stream, to: engine.mainMixerNode, format: stream.outputFormat(forBus: 0))
//		engine.connectMIDI(player, to: stream, format: .none)
//		engine.connect(engine.mainMixerNode, to: engine.outputNode, format: engine.mainMixerNode.outputFormat(forBus: 0))
//		engine.prepare()
//		try engine.start()
//		try await Task.sleep(for: .seconds(20))
//	}
//}
