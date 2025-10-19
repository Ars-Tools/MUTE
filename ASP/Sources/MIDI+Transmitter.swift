//
//  MIDI+Transmitter.swift
//  MUTE
//
//  Created by Kota on 7/21/R7.
//
@preconcurrency import CoreAudioKit
@preconcurrency import Combine
import MIDI
// An AudioUnit to transmit MIDI messages to some MIDI destination out of the AUGraph
public final class MIDITransmitter: AUAudioUnit {
	let input: AUAudioUnitBus
	let output: AUAudioUnitBus
	private(set) var id: MIDIPortRef
	private(set) var target: MIDIEndpointRef
	private(set) var cancellable: AnyCancellable?
	public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
		let client = .default as Client
		id = .init()
		target = .init()
		input = .init()
		output = .init()
		try super.init(componentDescription: componentDescription, options: options)
		let name = componentDescription.identifier(suffix: audioUnitShortName ?? audioUnitName ?? ProcessInfo.processInfo.processName)
		switch MIDIOutputPortCreate(client.id, name as CFString, &id) {
		case.zero:
			break
		case let status:
			throw Error.midi(status)
		}
		let target = AUParameter(identifier: "target", name: "target", address: 0, range: AUValue.zero ... AUValue.infinity, unit: .indexed)
		let stdout = AUParameter(identifier: "stdout", name: "stdout", address: 1, range: AUValue.zero ... AUValue.infinity, unit: .boolean)
		let stderr = AUParameter(identifier: "stderr", name: "stderr", address: 2, range: AUValue.zero ... AUValue.infinity, unit: .generic)
		parameterTree = .init {
			target
			stdout
			stderr
		}
		parameterTree?.implementorStringFromValueCallback = {
			switch $0.address {
			case target.address:
				switch $1.map(\.pointee).flatMap(Int.init(exactly:)).map(MIDIGetDestination) {
				case.some(.zero):
					""
				case.some(let e):
					EntityView(rawValue: e).displayName ?? ""
				default:
					""
				}
			default:
				""
			}
		}
		parameterTree?.implementorValueFromStringCallback = {
			switch $0.address {
			case target.address:
				Client.Target
					.map(\.displayName)
					.firstIndex(of: $1)
					.flatMap(AUValue.init(exactly:)) ?? .nan
			default:
				.nan
			}
		}
		let endpoint = target.publisher(for: \.value, options: [.new]).compactMap(Int.init(exactly:)).map(MIDIGetDestination)
		cancellable = Publishers.CombineLatest(client.Target, endpoint)
		.map {
			$0.map(\.id).contains($1) ? $1 : 0
		}.removeDuplicates()
		.assign(to: \.target, on: self)
	}
	deinit {
		cancellable.take()?.cancel()
		MIDIEndpointDispose(id)
	}
}
extension MIDITransmitter {
	public override var inputBusses: AUAudioUnitBusArray {
		.init(audioUnit: self, busType: .input, busses: [input])
	}
	public override var outputBusses: AUAudioUnitBusArray {
		.init(audioUnit: self, busType: .output, busses: [output])
	}
	public override var canPerformInput: Bool { false }
	public override var canPerformOutput: Bool { false }
}
extension MIDITransmitter {
	public override var audioUnitMIDIProtocol: MIDIProtocolID {
		._2_0
	}
	public override var virtualMIDICableCount: Int { 1 }
}
extension MIDITransmitter {
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
		{ [unowned self] in
			switch $1 {
			case.zero:
				switch target {
				case.zero:
					kAudio_NoError
				case let target:
					MIDISendEventList(id, target, $2)
				}
			default:
				kAudio_NoError
			}
		}
	}
	public override var renderBlock: AURenderBlock {
		{ _, _, _, _, _, _ in kAudio_NoError }
	}
}
