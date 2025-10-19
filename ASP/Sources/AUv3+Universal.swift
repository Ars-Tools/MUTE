//
//  AUv3+Universal.swift
//  MUTE
//
//  Created by Kota on 7/7/R7.
//
import typealias AudioUnit.AUAudioUnit
import typealias AudioUnit.AUAudioUnitBusArray
import typealias AudioUnit.AUInternalRenderBlock
import typealias AudioUnit.MIDIProtocolID
import let AudioUnit.kAudio_NoError
import let AudioUnit.kAudioUnitErr_NoConnection
import let AudioUnit.kAudioUnitErr_CannotDoInCurrentContext
import let AudioUnit.AUEventSampleTimeImmediate
import typealias Synchronization.Atomic
import typealias AVFoundation.AVAudioFormat
import typealias MIDI.Proxy
import typealias CoreMIDI.MIDIEventList
import func CoreMIDI.MIDIEventListInit
import func CoreMIDI.MIDIEventListAdd
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.PassthroughSubject
@preconcurrency import typealias Combine.AnyCancellable
import os.log
//
// (P      ) -> A : Generator
// (P, M   ) -> A : Instrument
// (P,    A) -> A : Effect / Mixer
// (P, M, A) -> A : Music Effect
// (P,     ) -> M :
// (P, M   ) -> M : MIDI Processor
// (P,    A) -> M :
// (P, M, A) -> M :
//
@dynamicMemberLookup
open class Universal: AUAudioUnit {
	var bus: (i: Array<Input.`Protocol`>, o: Array<Output.`Protocol`>) = (.init(), .init())
	var midi: Array<(i: MIDI.Proxy, o: MIDI.Proxy)> = .init()
	let timeSignaturePublisher: PassthroughSubject<SIMD2<Float64>, Never> = .init()
	let beatPublisher: PassthroughSubject<SIMD2<Float64>, Never> = .init()
	private(set) var cancellables: Set<AnyCancellable> = .init()
}
extension Universal {
	public var timeSignature: some Publisher<(Float64, Float64), Never> {
		timeSignaturePublisher.removeDuplicates().map { unsafeBitCast($0, to: (Float64, Float64).self) }
	}
	public var beat: some Publisher<(Float64, Float64), Never> {
		beatPublisher.removeDuplicates().map { unsafeBitCast($0, to: (Float64, Float64).self) }
	}
}
extension Universal {
	public override var inputBusses: AUAudioUnitBusArray {
		.init(audioUnit: self, busType: .input, busses: bus.i)
	}
	public override var outputBusses: AUAudioUnitBusArray {
		.init(audioUnit: self, busType: .output, busses: bus.o)
	}
}
extension Universal {
	subscript<R>(dynamicMember dynamicMember: KeyPath<Array<Input.`Protocol`>, R>) -> R {
		_read {
			yield bus.i[keyPath: dynamicMember]
		}
	}
	subscript<R>(dynamicMember dynamicMember: WritableKeyPath<Array<Input.`Protocol`>, R>) -> R {
		_read {
			yield bus.i[keyPath: dynamicMember]
		}
		_modify {
			yield &bus.i[keyPath: dynamicMember]
		}
	}
	subscript<R>(dynamicMember dynamicMember: ReferenceWritableKeyPath<Array<Input.`Protocol`>, R>) -> R {
		_read {
			yield bus.i[keyPath: dynamicMember]
		}
		_modify {
			yield &bus.i[keyPath: dynamicMember]
		}
	}
	subscript<R>(dynamicMember dynamicMember: KeyPath<Array<Output.`Protocol`>, R>) -> R {
		_read {
			yield bus.o[keyPath: dynamicMember]
		}
	}
	subscript<R>(dynamicMember dynamicMember: WritableKeyPath<Array<Output.`Protocol`>, R>) -> R {
		_read {
			yield bus.o[keyPath: dynamicMember]
		}
		_modify {
			yield &bus.o[keyPath: dynamicMember]
		}
	}
	subscript<R>(dynamicMember dynamicMember: ReferenceWritableKeyPath<Array<Output.`Protocol`>, R>) -> R {
		_read {
			yield bus.o[keyPath: dynamicMember]
		}
		_modify {
			yield &bus.o[keyPath: dynamicMember]
		}
	}
}
extension Universal {
	public override func allocateRenderResources() throws {
		try super.allocateRenderResources()
		for i in bus.i where i.isEnabled {
			try i.allocate()
		}
		for o in bus.o where o.isEnabled {
			try o.allocate()
		}
		for (index, cable) in midi.enumerated() {
			cable.o.sink { [audioUnitMIDIProtocol, midiOutputEventListBlock] timestamp, msg in
				withUnsafeTemporaryAllocation(byteCount: MemoryLayout<MIDIEventList>.size, alignment: MemoryLayout<UInt32>.alignment) {
					let length = $0.count
					let target = $0.baseAddress.unsafelyUnwrapped.assumingMemoryBound(to: MIDIEventList.self)
					let cursor = msg.withUnsafeBufferPointer {
						MIDIEventListAdd(target, length, MIDIEventListInit(target, audioUnitMIDIProtocol), timestamp, $0.count, $0.baseAddress.unsafelyUnwrapped)
					}
					assert(Int(bitPattern: cursor) != .zero)
					switch midiOutputEventListBlock?(AUEventSampleTimeImmediate, .init(index), target) {
					case.some(.zero):
						break
					case.some:
						break
					case.none:
						break
					}
					
				}
			}.store(in: &cancellables)
		}
	}
	public override func deallocateRenderResources() {
		cancellables.removeAll()
		for o in bus.o where o.isEnabled {
			o.deallocate()
		}
		for i in bus.i where i.isEnabled {
			i.deallocate()
		}
		super.deallocateRenderResources()
	}
}
extension Universal {
	public func append(_ newElement: Input.Direct) {
		bus.i.append(newElement)
	}
	public func append(_ newElement: Input.WithConverter) {
		bus.i.append(newElement)
	}
	public func append(_ newElement: Output.Direct) {
		bus.o.append(newElement)
	}
	public func append(_ newElement: Output.WithConverter) {
		bus.o.append(newElement)
	}
}
extension Universal {
	public override var audioUnitMIDIProtocol: MIDIProtocolID { ._2_0 }
	public override var virtualMIDICableCount: Int { midi.count }
}
extension Universal {
	public override var internalRenderBlock: AUInternalRenderBlock {
		let ts = Atomic<UInt64>(.min)
		return { [unowned self] in
			if $0.pointee.isEmpty {
				if case (let old, let new) = ts.max($1.pointee.mHostTime, ordering: .acquiringAndReleasing), old < new {
					if let musicalContextBlock {
						var timeSignature = (0.0, 0)
						var beat = (0.0, 0.0)
						switch musicalContextBlock(&beat.0, &timeSignature.0, &timeSignature.1, &beat.1, nil, nil) {
						case true:
							timeSignaturePublisher.send(.init(timeSignature.0, .init(timeSignature.1)))
							beatPublisher.send(unsafeBitCast(beat, to: SIMD2<Float64>.self))
						case false:
							break
						}
					}
					if let event = $5 {
						for event in sequence(first: event, next: \.next) {
							switch event.type {
							case.midiSysEx where audioUnitMIDIProtocol == ._1_0:
								fallthrough
							case.MIDI:
								let event = event.midiEvent
								let index = Int(event.cable)
								if midi.indices ~= index {
									midi[index].i.send(payload: event.payload)
								}
							case.midiSysEx where audioUnitMIDIProtocol == ._2_0:
								fallthrough
							case.midiEventList:
								let event = event.midiEventList
								let index = Int(event.cable)
								if midi.indices ~= index {
									midi[index].i.send(payload: event.payload)
								}
							case.parameter,.parameterRamp:
								if let parameterTree, let parameter = parameterTree.parameter(withAddress: event.parameter.pointee.parameterAddress) {
									parameter.setValue(event.pointee.parameter.value,
													   originator: .none,
													   atHostTime: $1.pointee.mHostTime)
								}
							default:
								os_log(.info, "%@ has not been handled", String(reflecting: event.type), String(describing: event.pointee))
							}
						}
					}
					if let block = $6 {
						for i in bus.i where i.isEnabled {
							switch i.fetch(flags: $0, stamp: $1, count: $2, block: block) {
							case kAudio_NoError:
								continue
							case let e:
								return e
							}
						}
					}
				}
				return if bus.o.isEmpty {
					0
				} else if bus.o.indices ~= $3, bus.o[$3].isEnabled {
					bus.o[$3](at: $1.pointee.mSampleTime, to: $2, of: $4)
				} else {
					kAudioUnitErr_NoConnection
				}
			} else if $0.pointee ~= .offlineUnitRenderAction_Preflight {
				return kAudio_NoError
			} else if $0.pointee ~= .offlineUnitRenderAction_Render {
				return kAudio_NoError
			} else if $0.pointee ~= .offlineUnitRenderAction_Complete {
				return kAudio_NoError
			} else if $0.pointee ~= .unitRenderAction_OutputIsSilence {
				return kAudio_NoError
			} else if $0.pointee ~= .unitRenderAction_PreRender {
				return kAudio_NoError
			} else if $0.pointee ~= .unitRenderAction_PostRenderError {
				return kAudio_NoError
			} else if $0.pointee ~= .unitRenderAction_DoNotCheckRenderArgs {
				return kAudio_NoError
			} else if $0.pointee ~= .unitRenderAction_OutputIsSilence {
				return kAudio_NoError
			} else {
				return kAudioUnitErr_CannotDoInCurrentContext
			}
		}
	}
}
