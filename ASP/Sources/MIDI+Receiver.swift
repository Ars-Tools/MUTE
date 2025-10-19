//
//  MIDI+Receiver.swift
//  MUTE
//
//  Created by Kota on 7/20/R7.
//
@preconcurrency import CoreAudioKit
import MIDI
// An AudioUnit which creates MIDI virtual destination to receive midi messages and send into the AUGraph
public final class MIDIReceiver: AUAudioUnit {
	let input: AUAudioUnitBus
	let output: AUAudioUnitBus
	private(set) var id: MIDIEndpointRef
	public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
		id = .init()
		input = .init()
		output = .init()
		try super.init(componentDescription: componentDescription, options: options)
		let name = componentDescription.identifier(suffix: audioUnitShortName ?? audioUnitName ?? ProcessInfo.processInfo.processName)
		let status = MIDIDestinationCreateWithProtocol(Client.default.id, name as CFString, audioUnitMIDIProtocol, &id) { [unowned self] msg, ref in
			switch midiOutputEventListBlock?(AUEventSampleTimeImmediate, 0, msg) {
			case.some(.zero):
				break
			case.some:
				break
			case.none:
				break
			}
		}
		switch status {
		case.zero:
			break
		case let status:
			throw Error.midi(status)
		}
	}
	deinit {
		MIDIEndpointDispose(id)
	}
}
extension MIDIReceiver {
	public override var inputBusses: AUAudioUnitBusArray {
		.init(audioUnit: self, busType: .input, busses: [input])
	}
	public override var outputBusses: AUAudioUnitBusArray {
		.init(audioUnit: self, busType: .output, busses: [output])
	}
	public override var canPerformInput: Bool { false }
	public override var canPerformOutput: Bool { false }
}
extension MIDIReceiver {
	public override var audioUnitMIDIProtocol: MIDIProtocolID { ._2_0 }
	public override var virtualMIDICableCount: Int { 1 }
}
extension MIDIReceiver {
	public override var renderBlock: AURenderBlock {
		{ _, _, _, _, _, _ in kAudio_NoError }
	}
}
