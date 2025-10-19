//
//  AUv3+AURenderEvent+.swift
//  MUTE
//
//  Created by Kota on 7/7/R7.
//
import typealias AudioUnit.AURenderEvent
import typealias AudioUnit.AURenderEventType
import typealias AudioUnit.AURenderEventHeader
import typealias AudioUnit.AUParameterEvent
import typealias AudioUnit.AUEventSampleTime
import typealias AudioUnit.AUMIDIEvent
import typealias AudioUnit.AUMIDIEventList
import typealias CoreMIDI.MIDIEventList
extension UnsafePointer where Pointee == AURenderEvent {
	@inlinable
	var type: AURenderEventType {
		withMemoryRebound(to: AURenderEventHeader.self, capacity: 1, \.pointee.eventType)
	}
	@inlinable
	var next: Optional<UnsafePointer<Pointee>> {
		.init(withMemoryRebound(to: AURenderEventHeader.self, capacity: 1, \.pointee.next))
	}
	@inlinable
	var parameter: UnsafePointer<AUParameterEvent> {
		withMemoryRebound(to: AUParameterEvent.self, capacity: 1, \.self)
	}
	@inlinable
	var midiEvent: UnsafePointer<AUMIDIEvent> {
		withMemoryRebound(to: AUMIDIEvent.self, capacity: 1, \.self)
	}
	@inlinable
	var midiEventList: UnsafePointer<AUMIDIEventList> {
		withMemoryRebound(to: AUMIDIEventList.self, capacity: 1, \.self)
	}
}
extension UnsafePointer where Pointee == AUMIDIEvent {
	@inlinable
	var cable: UInt8 {
		.init(pointer(to: \.cable).unsafelyUnwrapped.pointee)
	}
	@inlinable
	var payload: UnsafeBufferPointer<UInt8> {
		.init(start: .init(.init(.init(pointer(to: \.data)))),
			  count: .init(pointer(to: \.length).unsafelyUnwrapped.pointee))
	}
}
extension UnsafePointer where Pointee == AUMIDIEventList {
	@inlinable
	var cable: UInt8 {
		pointer(to: \.cable).unsafelyUnwrapped.pointee
	}
	@inlinable
	var payload: UnsafePointer<MIDIEventList> {
		.init(pointer(to: \.eventList).unsafelyUnwrapped)
	}
}
