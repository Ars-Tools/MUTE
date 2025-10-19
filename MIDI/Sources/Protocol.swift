//
//  Protocol.swift
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Combine.Subject
@preconcurrency import typealias Combine.PassthroughSubject
@preconcurrency import typealias CoreMIDI.MIDIUniversalMessage
@preconcurrency import typealias CoreMIDI.MIDITimeStamp
@preconcurrency import typealias CoreMIDI.MIDIEventList
@preconcurrency import typealias CoreMIDI.MIDIProtocolID
@preconcurrency import func CoreMIDI.MIDIEventListForEachEvent
protocol Instance: Sendable, Identifiable, Hashable {
	var id: UInt32 { get }
}
extension Instance {
	public func hash(into hasher: inout Hasher) {
		id.hash(into: &hasher)
	}
	public static func==(lhs: Self, rhs: Self) -> Bool {
		lhs.id == rhs.id
	}
}
public protocol Processor: Sendable {
	var `protocol`: MIDIProtocolID { get }
	func process(msg: some Payload) throws
}
extension Processor {
	public func process<T: MSG>(msg: some Collection<(MIDITimeStamp, T)>) throws {
		try process(msg: Buffer(msg: msg, as: `protocol`))
	}
	public func process<T: MSG>(msg: some Collection<T>, at timestamp: MIDITimeStamp) throws {
		try process(msg: Buffer(msg: msg, as: `protocol`, at: timestamp))
	}
}
public typealias Source = Combine.Publisher<(MIDITimeStamp, MIDIUniversalMessage), Never>
public typealias Proxy = PassthroughSubject<(MIDITimeStamp, MIDIUniversalMessage), Never>
extension Proxy {
	@inlinable
	public func send(payload: UnsafeBufferPointer<UInt8>) {
		if case.some(let ump) = MSG_1_0(buffer: payload).map(\.rawValue) {
			send((0, ump))
		} else {} // ignore sysex, et al
	}
	@_disfavoredOverload
	@inlinable
	public func send(payload: some Collection<UInt8>) {
		if case.some(let ump) = MSG_1_0(buffer: payload).map(\.rawValue) {
			send((0, ump))
		} else {} // ignore sysex, et al
	}
	@inlinable
	public func send(payload: UnsafePointer<MIDIEventList>) {
		MIDIEventListForEachEvent(payload, {
			guard let self = $0 else { return }
			Unmanaged<Proxy>
				.fromOpaque(self)
				.takeUnretainedValue()
				.send(($1, $2))
		}, Unmanaged.passUnretained(self).toOpaque())
	}
	@_disfavoredOverload
	@inlinable
	public func send(payload: some Payload) {
		payload.withUnsafeEventListPointer(send)
	}
}
