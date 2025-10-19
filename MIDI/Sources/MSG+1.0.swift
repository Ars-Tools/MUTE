//
//  MSG+1.0.swift
//  MUTE
//
//  Created by Kota on 7/4/R7.
//
import CoreMIDI
@preconcurrency import protocol Combine.Publisher
public struct MSG_1_0: Codable, Sendable, BitwiseCopyable {
	public let group: UInt8
	public let channel: UInt8
	public let message: Message
	public enum Message: Codable, Sendable, BitwiseCopyable {
		case noteOff(number: UInt8, velocity: UInt8)	// 0x8_
		case noteOn(number: UInt8, velocity: UInt8)		// 0x9_
		case polyPressure(number: UInt8, value: UInt8)	// 0xA_
		case controlChange(index: UInt8, value: UInt8)	// 0xB_
		case programChange(value: UInt8)				// 0xC_
		case channelPressure(value: UInt8)				// 0xD_
		case pitchBend(value: UInt16)					// 0xE_
	}
}
extension MSG_1_0 {
	public init(note number: UInt8, velocity pf: UInt8, channel idx: UInt8, group g: UInt8 = 0) {
		group = g
		channel = idx
		message = switch pf {
		case.zero:
			.noteOff(number: number, velocity: 0)
		default:
			.noteOn(number: number, velocity: pf)
		}
	}
}
extension MSG_1_0: MSG {
	public func withUnsafeBufferPointer<E, R>(_ body: borrowing (UnsafeBufferPointer<UInt32>) throws(E) -> R) rethrows -> R {
		switch message {
		case.noteOff(let number, let velocity):
			try withUnsafeBytes(of: MIDI1UPNoteOff(0, channel, number, velocity)) {
				try body($0.assumingMemoryBound(to: UInt32.self))
			}
		case.noteOn(let number, let velocity):
			try withUnsafeBytes(of: MIDI1UPNoteOn(0, channel, number, velocity)) {
				try body($0.assumingMemoryBound(to: UInt32.self))
			}
		case.polyPressure(let number, let pressure):
			try withUnsafeBytes(of: MIDI1UPPolyPressure(0, channel, number, pressure)) {
				try body($0.assumingMemoryBound(to: UInt32.self))
			}
		case.controlChange(let index, let value):
			try withUnsafeBytes(of: MIDI1UPControlChange(0, channel, index, value)) {
				try body($0.assumingMemoryBound(to: UInt32.self))
			}
		case.programChange(let value):
			try withUnsafeBytes(of: MIDI1UPProgramChange(0, channel, value)) {
				try body($0.assumingMemoryBound(to: UInt32.self))
			}
		case.channelPressure(let value):
			try withUnsafeBytes(of: MIDI1UPChannelPressure(0, channel, value)) {
				try body($0.assumingMemoryBound(to: UInt32.self))
			}
		case.pitchBend(let value):
			switch unsafeBitCast(value.bigEndian, to: (UInt8, UInt8).self) {
			case let (msb, lsb):
				try withUnsafeBytes(of: MIDI1UPPitchBend(0, channel, msb, lsb)) {
					try body($0.assumingMemoryBound(to: UInt32.self))
				}
			}
		}
	}
}
extension MSG_1_0.Message {
	@usableFromInline
	typealias RawValue = MIDIUniversalMessage.__Unnamed_union___Anonymous_field3.__Unnamed_struct_channelVoice1
	@inlinable
	init?(rawValue: RawValue) {
		switch rawValue.status {
		case.noteOff:
			self = .noteOff(number: rawValue.note.number, velocity: rawValue.note.velocity)
		case.noteOn:
			self = .noteOn(number: rawValue.note.number, velocity: rawValue.note.velocity)
		case.polyPressure:
			self = .polyPressure(number: rawValue.polyPressure.noteNumber, value: rawValue.polyPressure.pressure)
		case.controlChange:
			self = .controlChange(index: rawValue.controlChange.index, value: rawValue.controlChange.data)
		case.programChange:
			self = .programChange(value: rawValue.program)
		case.channelPressure:
			self = .channelPressure(value: rawValue.channelPressure)
		case.pitchBend:
			self = .pitchBend(value: rawValue.pitchBend)
		default:
			return nil
		}
	}
	@inlinable
	func rawValue(with channel: UInt8) -> RawValue {
		switch self {
		case.noteOff(let number, let velocity):
			.init(status: .noteOff, channel: channel, reserved: (0, 0, 0),
				  .init(note: .init(number: number, velocity: velocity)))
		case.noteOn(let number, let velocity):
			.init(status: .noteOn, channel: channel, reserved: (0, 0, 0),
				  .init(note: .init(number: number, velocity: velocity)))
		case.polyPressure(let number, let value):
			.init(status: .polyPressure, channel: channel, reserved: (0, 0, 0),
				  .init(polyPressure: .init(noteNumber: number, pressure: value)))
		case.controlChange(let index, let value):
			.init(status: .controlChange, channel: channel, reserved: (0, 0, 0),
				  .init(controlChange: .init(index: index, data: value)))
		case.programChange(let value):
			.init(status: .programChange, channel: channel, reserved: (0, 0, 0),
				  .init(program: value))
		case.channelPressure(let value):
			.init(status: .channelPressure, channel: channel, reserved: (0, 0, 0),
				  .init(channelPressure: value))
		case.pitchBend(let value):
			.init(status: .pitchBend, channel: channel, reserved: (0, 0, 0),
				  .init(pitchBend: value))
		}
	}
}
extension MSG_1_0 {
	@inlinable
	public init?(rawValue: MIDIUniversalMessage) {
		switch rawValue.type {
		case.channelVoice1:
			guard case.some(let msgValue) = Message(rawValue: rawValue.channelVoice1) else { return nil }
			group = rawValue.group
			channel = rawValue.channelVoice1.channel
			message = msgValue
		default:
			return nil
		}
	}
	@inlinable
	public var rawValue: MIDIUniversalMessage {
		.init(type: .channelVoice1, group: group, reserved: (0, 0, 0), .init(channelVoice1: message.rawValue(with: channel)))
	}
}
extension Source {
	@inlinable
	public var _1_0: some Combine.Publisher<(MIDITimeStamp, MSG_1_0), Failure> {
		compactMap {
			switch MSG_1_0(rawValue: $1) {
			case.some(let msg):
				.some(($0, msg))
			default:
				.none
			}
		}
	}
	@inlinable
	public var noteIn_1_0: some Combine.Publisher<(MIDITimeStamp, UInt8, UInt8, UInt8), Failure> {
		_1_0.compactMap {
			switch $1.message {
			case.noteOff(let number, let velocity):
				.some(($0, $1.channel, number, velocity))
			case.noteOn(let number, let velocity):
				.some(($0, $1.channel, number, velocity))
			default:
				.none
			}
		}
	}
}
extension Sequence where Element == (MIDITimeStamp, MIDIUniversalMessage) {
	@inlinable
	public var _1_0: some Sequence<(MIDITimeStamp, MSG_1_0)> {
		lazy.compactMap {
			switch MSG_1_0(rawValue: $1) {
			case.some(let msg):
				.some(($0, msg))
			default:
				.none
			}
		}
	}
	@inlinable
	public var noteIn_1_0: some Sequence<(MIDITimeStamp, UInt8, UInt8, UInt8)> {
		_1_0.compactMap {
			switch $1.message {
			case.noteOff(let number, let velocity):
				.some(($0, $1.channel, number, velocity))
			case.noteOn(let number, let velocity):
				.some(($0, $1.channel, number, velocity))
			default:
				.none
			}
		}
	}
}
extension MSG_1_0 {
	public init?(buffer: some Collection<UInt8>) {
		var parser = buffer[...]
		guard case.some(let status) = parser.popFirst() else { return nil }
		let channel = status & 0b0000_1111
		switch status & 0b1111_0000 {
		case 0b1000_0000:
			guard let msb = parser.popFirst(), let lsb = parser.popFirst() else { fallthrough }
			self = .init(group: 0, channel: channel, message: .noteOn(number: msb, velocity: lsb))
		case 0b1001_0000:
			guard let msb = parser.popFirst(), let lsb = parser.popFirst() else { fallthrough }
			self = .init(group: 0, channel: channel, message: .noteOff(number: msb, velocity: lsb))
		case 0b1010_0000:
			guard let msb = parser.popFirst(), let lsb = parser.popFirst() else { fallthrough }
			self = .init(group: 0, channel: channel, message: .polyPressure(number: msb, value: lsb))
		case 0b1011_0000:
			guard let msb = parser.popFirst(), let lsb = parser.popFirst() else { fallthrough }
			self = .init(group: 0, channel: channel, message: .controlChange(index: msb, value: lsb))
		case 0b1100_0000:
			guard let msb = parser.popFirst() else { fallthrough }
			self = .init(group: 0, channel: channel, message: .programChange(value: msb))
		case 0b1101_0000:
			guard let msb = parser.popFirst() else { fallthrough }
			self = .init(group: 0, channel: channel, message: .channelPressure(value: msb))
		case 0b1110_0000:
			guard let msb = parser.popFirst(), let lsb = parser.popFirst() else { fallthrough }
			self = .init(group: 0, channel: channel, message: .pitchBend(value: .init(bigEndian: unsafeBitCast((msb, lsb), to: UInt16.self))))
		default:
			return nil
		}
	}
}
