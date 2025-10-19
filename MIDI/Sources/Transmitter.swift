//
//  Transmitter.swift
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
@preconcurrency import typealias CoreFoundation.CFString
@preconcurrency import typealias CoreMIDI.MIDIProtocolID
@preconcurrency import typealias CoreMIDI.MIDIPortRef
@preconcurrency import typealias CoreMIDI.MIDIEventList
@preconcurrency import typealias CoreMIDI.MIDIEndpointRef
@preconcurrency import func CoreMIDI.MIDIOutputPortCreate
@preconcurrency import func CoreMIDI.MIDIPortDispose
@preconcurrency import func CoreMIDI.MIDISendEventList
@preconcurrency import Combine
import typealias Synchronization.Atomic
public final class Transmitter: Instance {
	public let id: MIDIPortRef
	public let client: Client
	@inlinable
	public init(name: String, client parent: Client = .default) throws {
		id = try withUnsafePointer(to: 0 as MIDIPortRef) {
			switch MIDIOutputPortCreate(parent.id, name as CFString, .init(mutating: $0)) {
			case.zero:
				$0.pointee
			case let status:
				throw Error.native(status)
			}
		}
		client = parent
	}
	deinit {
		MIDIPortDispose(id)
	}
}
extension Transmitter {
	@inlinable
	public func send(msg: some Payload, to endpoint: MIDIEndpointRef) throws {
		try msg.withUnsafeEventListPointer {
			switch MIDISendEventList(id, endpoint, $0) {
			case.zero:
				break
			case let status:
				throw Error.native(status)
			}
		}
	}
}
extension Transmitter {
	public func connectio(to displayName: String, as version: MIDIProtocolID) -> some Processor {
		let endpoint = Atomic<MIDIEndpointRef>(0)
		let subscription = client.Target.sink {
			let found = $0.first { $0.displayName == displayName }
			switch found.map(\.id) {
			case.some(let id):
				endpoint.store(id, ordering: .releasing)
			case.none:
				endpoint.store(.zero, ordering: .releasing)
			}
		}
		return Connector(protocol: version, tx: self) {
			withExtendedLifetime(subscription) { endpoint.load(ordering: .acquiring) }
		}
	}
}
extension Transmitter {
	public struct Connector: Sendable {
		public let `protocol`: MIDIProtocolID
		@usableFromInline let tx: Transmitter
		@usableFromInline let rx: @Sendable () -> MIDIEndpointRef
	}
}
extension Transmitter.Connector {
	public func send(msg: some Payload) throws {
		switch rx() {
		case.zero:
			throw Error.noEndpoint
		case let endpoint:
			try tx.send(msg: msg, to: endpoint)
		}
	}
}
extension Transmitter.Connector: Processor {
	public func process(msg: some Payload) throws {
		try send(msg: msg)
	}
}
