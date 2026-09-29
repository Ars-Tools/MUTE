//
//  Publisher.swift
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
@preconcurrency import typealias CoreFoundation.CFString
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias CoreMIDI.MIDIProtocolID
@preconcurrency import typealias CoreMIDI.MIDITimeStamp
@preconcurrency import typealias CoreMIDI.MIDIEventList
@preconcurrency import typealias CoreMIDI.MIDIEndpointRef
@preconcurrency import typealias CoreMIDI.MIDIUniversalMessage
@preconcurrency import func CoreMIDI.MIDISourceCreateWithProtocol
@preconcurrency import func CoreMIDI.MIDIEndpointDispose
@preconcurrency import func CoreMIDI.MIDIReceivedEventList
public final class Publisher: Instance {
	public let id: MIDIEndpointRef
	@inlinable
	public init(name: String, as version: MIDIProtocolID, client: Client = .default) throws {
		id = try withUnsafePointer(to: 0 as MIDIEndpointRef) {
			switch MIDISourceCreateWithProtocol(client.id, name as CFString, version, .init(mutating: $0)) {
			case.zero:
				$0.pointee
			case let status:
				throw Error.native(status)
			}
		}
	}
	deinit {
		MIDIEndpointDispose(id)
	}
}
extension Publisher {
	@inlinable
	public func publish(msg: some Payload) throws {
		try msg.withUnsafeEventListPointer {
			switch MIDIReceivedEventList(id, $0) {
			case.zero:
				break
			case let status:
				throw Error.native(status)
			}
		}
	}
}
extension Publisher {
	@inlinable
	public func publish<T: MSG>(msg: some Collection<(MIDITimeStamp, T)>, as version: MIDIProtocolID) throws {
		try msg.withUnsafeMIDIEventList(as: version, publish)
	}
}
extension Publisher: Processor {
	public var `protocol`: MIDIProtocolID {
		EntityView(rawValue: id).protocol ?? .init(rawValue: 0).unsafelyUnwrapped
	}
	public func process(msg: some Payload) throws {
		try publish(msg: msg)
	}
}
