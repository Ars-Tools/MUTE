//
//  MIDI+Subscriber.swift
//  MUTE
//
//  Created by Kota on 7/20/R7.
//
@preconcurrency import CoreAudioKit
@preconcurrency import Combine
import MIDI
// An AudioUnit to subscribe some MIDI source out of the AUGraph to receive MIDI messages
public final class MIDISubscriber: AUAudioUnit, @unchecked Sendable {
	let input: AUAudioUnitBus
	let output: AUAudioUnitBus
	private(set) var id: MIDIPortRef
	private(set) var cancellable: AnyCancellable?
	public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
		let client = .default as Client
		id = .init()
		input = .init()
		output = .init()
		try super.init(componentDescription: componentDescription, options: options)
		let name = componentDescription.identifier(suffix: audioUnitShortName ?? audioUnitName ?? ProcessInfo.processInfo.processName)
		let status = MIDIInputPortCreateWithProtocol(client.id, name as CFString, audioUnitMIDIProtocol, &id) {
			guard let ref = $1 else { return }
			switch Unmanaged<AUAudioUnit>.fromOpaque(ref).takeUnretainedValue().midiOutputEventListBlock?(AUEventSampleTimeImmediate, 0, $0) {
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
		let source = AUParameter(identifier: "source", name: "source", address: 0, range: AUValue.zero ... AUValue.infinity, unit: .indexed)
		let stdout = AUParameter(identifier: "stdout", name: "stdout", address: 1, range: AUValue.zero ... AUValue.infinity, unit: .boolean)
		let stderr = AUParameter(identifier: "stderr", name: "stderr", address: 2, range: AUValue.zero ... AUValue.infinity, unit: .generic)
		parameterTree = .init {
			source
			stdout
			stderr
		}
		parameterTree?.implementorStringFromValueCallback = {
			switch $0.address {
			case source.address:
				switch $1.map(\.pointee).flatMap(Int.init(exactly:)).map(MIDIGetSource) {
				case.some(.zero),.none:
					""
				case.some(let s):
					EntityView(rawValue: s).displayName ?? ""
				}
			default:
				""
			}
		}
		parameterTree?.implementorValueFromStringCallback = {
			switch $0.address {
			case source.address:
				Client.Source
					.map(\.displayName)
					.firstIndex(of: $1)
					.flatMap(AUValue.init(exactly:)) ?? .nan
			default:
				.nan
			}
		}
		let endpoint = source.publisher(for: \.value, options: [.new]).compactMap(Int.init(exactly:)).map(MIDIGetSource)
		cancellable = Publishers.CombineLatest(client.Source.map { $0.map(\.id) }, endpoint)
			.map {
				$0.contains($1) ? $1 : .zero
			}
			.removeDuplicates()
			.map { [weak self] endpoint in
				do {
					enum Error: Swift.Error {
						case no
					}
					guard let self,
						  .zero != endpoint,
						  .zero == MIDIPortConnectSource(id, endpoint, Unmanaged.passUnretained(self).toOpaque()) else { throw Error.no }
					return CurrentValueSubject<AUValue, Never>(1)
						.handleEvents(receiveCompletion: .some({ [id] completion in
							   MIDIPortDisconnectSource(id, endpoint)
						   }), receiveCancel: .some({ [id] in
							   MIDIPortDisconnectSource(id, endpoint)
						   }))
				} catch {
					return CurrentValueSubject<AUValue, Never>(0)
						.handleEvents()
				}
			}.switchToLatest()
			.sink {
				stdout.value = $0
			}
	}
	deinit {
		if let parameterTree, let parameter = parameterTree.parameter(withAddress: 0) {
			parameter.value = 0
		}
		MIDIPortDispose(id)
	}
}
extension MIDISubscriber {
	public override var inputBusses: AUAudioUnitBusArray {
		.init(audioUnit: self, busType: .input, busses: [input])
	}
	public override var outputBusses: AUAudioUnitBusArray {
		.init(audioUnit: self, busType: .output, busses: [output])
	}
	public override var canPerformInput: Bool { false }
	public override var canPerformOutput: Bool { false }
}
extension MIDISubscriber {
	public override var audioUnitMIDIProtocol: MIDIProtocolID {
		._2_0
	}
	public override var virtualMIDICableCount: Int { 1 }
}
extension MIDISubscriber {
	public override var renderBlock: AURenderBlock {
		{ _, _, _, _, _, _ in kAudio_NoError }
	}
}
