//
//  MSG.swift
//  MUTE
//
//  Created by Kota on 7/4/R7.
//
@preconcurrency import CoreMIDI
public protocol MSG: RawRepresentable, Codable, BitwiseCopyable where RawValue == MIDIUniversalMessage {
	func withUnsafeBufferPointer<E, R>(_ body: (UnsafeBufferPointer<UInt32>) throws (E) -> R) rethrows -> R
}
extension MIDIUniversalMessage {
	public func withUnsafeBufferPointer<E, R>(_ body: (UnsafeBufferPointer<UInt32>) throws (E) -> R) rethrows -> R {
		switch type {
		case.channelVoice1:
			try channelVoice1.withUnsafeBufferPointer(group: group, body)
		case.channelVoice2:
			try channelVoice2.withUnsafeBufferPointer(group: group, body)
		default:
			try withUnsafeTemporaryAllocation(of: UInt32.self, capacity: 0) { try body(.init($0)) }
		}
	}
}
extension MIDIUniversalMessage.__Unnamed_union___Anonymous_field3.__Unnamed_struct_channelVoice1 {
	@inlinable
	func withUnsafeBufferPointer<E, R>(group: UInt8, _ body: (UnsafeBufferPointer<UInt32>) throws (E) -> R) rethrows -> R {
		switch status {
		case.noteOff:
			try withUnsafeBytes(of: MIDI1UPNoteOff(group, channel, note.number, note.velocity)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.noteOn:
			try withUnsafeBytes(of: MIDI1UPNoteOn(group, channel, note.number, note.velocity)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.polyPressure:
			try withUnsafeBytes(of: MIDI1UPPolyPressure(group, channel, polyPressure.noteNumber, polyPressure.pressure)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.controlChange:
			try withUnsafeBytes(of: MIDI1UPControlChange(group, channel, controlChange.index, controlChange.data)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.programChange:
			try withUnsafeBytes(of: MIDI1UPProgramChange(group, channel, program)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.channelPressure:
			try withUnsafeBytes(of: MIDI1UPChannelPressure(group, channel, channelPressure)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.pitchBend:
			switch unsafeBitCast(pitchBend.bigEndian, to: (UInt8, UInt8).self) {
			case let (msb, lsb):
				try withUnsafeBytes(of: MIDI1UPPitchBend(group, channel, msb, lsb)) {
					try $0.withMemoryRebound(to: UInt32.self, body)
				}
			}
		default:
			try withUnsafeTemporaryAllocation(of: UInt32.self, capacity: 0) { try body(.init($0)) }
		}
	}
}
extension MIDIUniversalMessage.__Unnamed_union___Anonymous_field3.__Unnamed_struct_channelVoice2 {
	@inlinable
	func withUnsafeBufferPointer<E, R>(group: UInt8, _ body: (UnsafeBufferPointer<UInt32>) throws (E) -> R) rethrows -> R {
		switch status {
		case.noteOff:
			try withUnsafeBytes(of: MIDI2NoteOff(group, channel, note.number, note.attributeType.rawValue, note.attribute, note.velocity)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.noteOn:
			try withUnsafeBytes(of: MIDI2NoteOn(group, channel, note.number, note.attributeType.rawValue, note.attribute, note.velocity)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.polyPressure:
			try withUnsafeBytes(of: MIDI2PolyPressure(group, channel, polyPressure.noteNumber, polyPressure.pressure)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.controlChange:
			try withUnsafeBytes(of: MIDI2ControlChange(group, channel, controlChange.index, controlChange.data)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.programChange:
			switch unsafeBitCast(programChange.bank.bigEndian, to: (UInt8, UInt8).self) {
			case let (msb, lsb):
				try withUnsafeBytes(of: MIDI2ProgramChange(group, channel, programChange.options.contains(.bankValid), programChange.program, msb, lsb)) {
					try $0.withMemoryRebound(to: UInt32.self, body)
				}
			}
		case.channelPressure:
			try withUnsafeBytes(of: MIDI2ChannelPressure(group, channel, channelPressure.data)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		case.pitchBend:
			try withUnsafeBytes(of: MIDI2PitchBend(group, channel, pitchBend.data)) {
				try $0.withMemoryRebound(to: UInt32.self, body)
			}
		default:
			try withUnsafeTemporaryAllocation(of: UInt32.self, capacity: 0) { try body(.init($0)) }
		}
	}
}
