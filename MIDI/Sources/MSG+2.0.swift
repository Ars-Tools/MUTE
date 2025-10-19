//
//  MSG+2.0.swift
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
import CoreMIDI
@preconcurrency import protocol Combine.Publisher
public struct MSG_2_0: Codable, Sendable, BitwiseCopyable {
	public let group: UInt8
	public let channel: UInt8
	public let message: Message
	public enum Message: Codable, Sendable, BitwiseCopyable {
		case noteOff(number: UInt8, velocity: UInt16, attributeType: UInt8, attributeData: UInt16)
		case noteOn(number: UInt8, velocity: UInt16, attributeType: UInt8, attributeData: UInt16)
		case polyPressure(number: UInt8, value: UInt32)
		case controlChange(index: UInt8, value: UInt32)
		case programChange(value: UInt8, bank: UInt16)	// 0xC_
		case channelPressure(value: UInt32)				// 0xD_
		case pitchBend(value: UInt32)					// 0xE_
	}
}
extension MSG_2_0 {
	public init(note number: UInt8, velocity pf: UInt16, channel idx: UInt8, group g: UInt8 = 0, attr: (MIDINoteAttribute, UInt16) = (.none, 0)) {
		group = g
		channel = idx
		message = switch pf {
		case.zero:
			.noteOff(number: number, velocity: 0, attributeType: attr.0.rawValue, attributeData: attr.1)
		default:
			.noteOn(number: number, velocity: pf, attributeType: attr.0.rawValue, attributeData: attr.1)
		}
	}
}
extension MSG_2_0 {
	public func withUnsafeBufferPointer<E, R>(_ body: (UnsafeBufferPointer<UInt32>) throws(E) -> R) rethrows -> R {
		switch message {
		case.noteOff(let number, let velocity, let attributeType, let attributeData):
			try withUnsafeBytes(of: MIDI2NoteOff(group, channel, number, attributeType, attributeData, velocity)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.noteOn(let number, let velocity, let attributeType, let attributeData):
			try withUnsafeBytes(of: MIDI2NoteOn(group, channel, number, attributeType, attributeData, velocity)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.polyPressure(let number, let value):
			try withUnsafeBytes(of: MIDI2PolyPressure(group, channel, number, value)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.controlChange(let index, let value):
			try withUnsafeBytes(of: MIDI2ControlChange(group, channel, index, value)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.programChange(let value, let bank):
			try withUnsafeBytes(of: MIDI2ProgramChange(group, channel, bank != .zero, value, .init((bank >> 8) & 0xFF), .init((bank >> 0) & 0x00))) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.channelPressure(let value):
			try withUnsafeBytes(of: MIDI2ChannelPressure(group, channel, value)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.pitchBend(let value):
			try withUnsafeBytes(of: MIDI2PitchBend(group, channel, value)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		}
	}
}
extension MSG_2_0.Message {
	@usableFromInline
	typealias RawValue = MIDIUniversalMessage.__Unnamed_union___Anonymous_field3.__Unnamed_struct_channelVoice2
	@inlinable
	init?(rawValue: RawValue) {
		switch rawValue.status {
		case.noteOff:
			self = .noteOff(number: rawValue.note.number,
							velocity: rawValue.note.velocity,
							attributeType: rawValue.note.attributeType.rawValue,
							attributeData: rawValue.note.attribute)
		case.noteOn:
			self = .noteOn(number: rawValue.note.number,
						   velocity: rawValue.note.velocity,
						   attributeType: rawValue.note.attributeType.rawValue,
						   attributeData: rawValue.note.attribute)
		case.polyPressure:
			self = .polyPressure(number: rawValue.polyPressure.noteNumber,
								 value: rawValue.polyPressure.pressure)
		case.controlChange:
			self = .controlChange(index: rawValue.controlChange.index,
								  value: rawValue.controlChange.data)
		case.programChange:
			self = .programChange(value: rawValue.programChange.program,
								  bank: rawValue.programChange.bank)
		case.channelPressure:
			self = .channelPressure(value: rawValue.channelPressure.data)
		case.pitchBend:
			self = .pitchBend(value: rawValue.pitchBend.data)
		default:
			return nil
		}
	}
	@inlinable
	func rawValue(with channel: UInt8) -> RawValue {
		switch self {
		case.noteOff(let number, let velocity, let attributeType, let attributeData):
				.init(status: .noteOff, channel: channel, reserved: (0, 0, 0),
					  .init(note: .init(number: number, attributeType: .init(rawValue: attributeType) ?? .none, velocity: velocity, attribute: attributeData)))
		case.noteOn(let number, let velocity, let attributeType, let attributeData):
				.init(status: .noteOn, channel: channel, reserved: (0, 0, 0),
					  .init(note: .init(number: number, attributeType: .init(rawValue: attributeType) ?? .none, velocity: velocity, attribute: attributeData)))
		case.polyPressure(let number, let value):
				.init(status: .polyPressure, channel: channel, reserved: (0, 0, 0),
					  .init(polyPressure: .init(noteNumber: number, reserved: 0, pressure: value)))
		case.controlChange(let index, let value):
				.init(status: .controlChange, channel: channel, reserved: (0, 0, 0),
					  .init(controlChange: .init(index: index, reserved: 0, data: value)))
		case.programChange(let value, let bank):
				.init(status: .programChange, channel: channel, reserved: (0, 0, 0),
					  .init(programChange: .init(options: bank != .zero ? .bankValid : .init(), program: value, reserved: (0, 0), bank: bank)))
		case.channelPressure(let value):
				.init(status: .channelPressure, channel: channel, reserved: (0, 0, 0),
					  .init(channelPressure: .init(data: value, reserved: (0, 0))))
		case.pitchBend(let value):
				.init(status: .pitchBend, channel: channel, reserved: (0, 0, 0),
					  .init(pitchBend: .init(data: value, reserved: (0, 0))))
		}
	}
}
extension MSG_2_0: MSG {
	@inlinable
	public init?(rawValue: RawValue) {
		switch rawValue.type {
		case.channelVoice2:
			guard case.some(let value) = Message(rawValue: rawValue.channelVoice2) else { return nil }
			group = rawValue.group
			channel = rawValue.channelVoice2.channel
			message = value
		default:
			return nil
		}
	}
	@inlinable
	public var rawValue: RawValue {
		.init(type: .channelVoice2, group: group, reserved: (0, 0, 0), .init(channelVoice2: message.rawValue(with: channel)))
	}
}
extension Source {
	@inlinable
	public var _2_0: some Combine.Publisher<(MIDITimeStamp, MSG_2_0), Failure> {
		compactMap {
			switch MSG_2_0(rawValue: $1) {
			case.some(let msg):
					.some(($0, msg))
			case.none:
					.none
			}
		}
	}
	@inlinable
	public var noteIn_2_0: some Combine.Publisher<(MIDITimeStamp, UInt8, UInt8, UInt16), Never> {
		_2_0.compactMap {
			switch $1.message {
			case.noteOff(let number, let velocity, _, _):
					.some(($0, $1.channel, number, velocity))
			case.noteOn(let number, let velocity, _, _):
					.some(($0, $1.channel, number, velocity))
			default:
					.none
			}
		}
	}
}
extension Sequence where Element == (MIDITimeStamp, MIDIUniversalMessage) {
	@inlinable
	public var _2_0: some Sequence<(MIDITimeStamp, MSG_2_0)> {
		lazy.compactMap {
			switch MSG_2_0(rawValue: $1) {
			case.some(let msg):
				.some(($0, msg))
			default:
				.none
			}
		}
	}
	@inlinable
	public var noteIn_2_0: some Sequence<(MIDITimeStamp, UInt8, UInt8, UInt16)> {
		_2_0.compactMap {
			switch $1.message {
			case.noteOff(let number, let velocity, _, _):
				.some(($0, $1.channel, number, velocity))
			case.noteOn(let number, let velocity, _, _):
				.some(($0, $1.channel, number, velocity))
			default:
				.none
			}
		}
	}
}
