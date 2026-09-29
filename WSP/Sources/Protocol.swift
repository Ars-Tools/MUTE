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
@usableFromInline
func sendMIDI1Chunk(_ payload: some Collection<UInt8>, at timestamp: MIDITimeStamp, to target: Proxy) {
    var fetch = payload[...]
    while !fetch.isEmpty {
        switch fetch.first {
        case.some(0x80 ... 0xBF), .some(0xE0 ... 0xEF), .some(0xF2):
            let count = 3
            defer {
                fetch.removeFirst(count)
            }
            if case.some(let msg) = MSG_1_0(buffer: fetch.prefix(count)).map(\.rawValue) {
                target.send((timestamp, msg))
            }
        case.some(0xC0 ... 0xDF), .some(0xF1), .some(0xF3):
            let count = 2
            defer {
                fetch.removeFirst(count)
            }
            if case.some(let msg) = MSG_1_0(buffer: fetch.prefix(count)).map(\.rawValue) {
                target.send((timestamp, msg))
            }
        case.some(0xF6), .some(0xF8 ... 0xFF):
            let count = 1
            defer {
                fetch.removeFirst(count)
            }
            if case.some(let msg) = MSG_1_0(buffer: fetch.prefix(count)).map(\.rawValue) {
                target.send((timestamp, msg))
            }
        case.some(0xF0):
            while fetch.popFirst() != .some(0xF7) {}
        default:
            break
        }
    }
}
extension Proxy {
	@inlinable
	public func send(payload: UnsafeBufferPointer<UInt8>, at timestamp: MIDITimeStamp = 0) {
		sendMIDI1Chunk(payload, at: timestamp, to: self)
	}
	@_disfavoredOverload
	@inlinable
	public func send(payload: some Collection<UInt8>, at timestamp: MIDITimeStamp = 0) {
		sendMIDI1Chunk(payload, at: timestamp, to: self)
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
