//
//  MIDI+Publisher.swift
//  MUTE
//
//  Created by Kota on 7/21/R7.
//
@preconcurrency import CoreAudioKit
import MIDI
// An AudioUnit which creates MIDI virtual source to publish midi messages from the AUGraph
public final class MIDIPublisher: AUAudioUnit {
	let input: AUAudioUnitBus
	let output: AUAudioUnitBus
	private(set) var id: MIDIEndpointRef
	public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
		id = .init()
		input = .init()
		output = .init()
		try super.init(componentDescription: componentDescription, options: options)
		let name = componentDescription.identifier(suffix: audioUnitShortName ?? audioUnitName ?? ProcessInfo.processInfo.processName)
		switch MIDISourceCreateWithProtocol(Client.default.id, name as CFString, audioUnitMIDIProtocol, &id) {
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
extension MIDIPublisher {
	public override var inputBusses: AUAudioUnitBusArray {
		.init(audioUnit: self, busType: .input, busses: [input])
	}
	public override var outputBusses: AUAudioUnitBusArray {
		.init(audioUnit: self, busType: .output, busses: [output])
	}
	public override var canPerformInput: Bool { false }
	public override var canPerformOutput: Bool { false }
}
extension MIDIPublisher {
	public override var audioUnitMIDIProtocol: MIDIProtocolID { ._2_0 }
	public override var virtualMIDICableCount: Int { 1 }
}
extension MIDIPublisher {
	public override var scheduleMIDIEventBlock: AUScheduleMIDIEventBlock {
		{ [audioUnitMIDIProtocol, scheduleMIDIEventListBlock] t, b, s, d in
			let status = switch MSG_1_0(buffer: UnsafeBufferPointer(start: d, count: s)) {
			case.some(let msg):
				MIDI.Buffer(msg: CollectionOfOne(msg), as: audioUnitMIDIProtocol, at: .init(AUEventSampleTimeImmediate)).withUnsafeEventListPointer {
					scheduleMIDIEventListBlock(AUEventSampleTimeImmediate, b, $0)
				}
			case.none:
				kAudio_NoError
			}
			switch status {
			default:
				break
			}
		}
	}
	public override var scheduleMIDIEventListBlock: AUMIDIEventListBlock {
		{ [id] in
			switch $1 {
			case.zero:
				MIDIReceivedEventList(id, $2)
			default:
				kAudio_NoError
			}
		}
	}
	public override var renderBlock: AURenderBlock {
		{ _, _, _, _, _, _ in kAudio_NoError }
	}
}
