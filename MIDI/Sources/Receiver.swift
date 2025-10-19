//
//  Receiver.swift
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
@preconcurrency import typealias CoreFoundation.CFString
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Combine.Subscriber
@preconcurrency import typealias Combine.PassthroughSubject
@preconcurrency import typealias CoreMIDI.MIDIPortRef
@preconcurrency import typealias CoreMIDI.MIDIEndpointRef
@preconcurrency import typealias CoreMIDI.MIDITimeStamp
@preconcurrency import typealias CoreMIDI.MIDIUniversalMessage
@preconcurrency import typealias CoreMIDI.MIDIProtocolID
@preconcurrency import func CoreMIDI.MIDIDestinationCreateWithProtocol
@preconcurrency import func CoreMIDI.MIDIEventListForEachEvent
@preconcurrency import func CoreMIDI.MIDIEndpointDispose
public final class Receiver: Instance {
	public let id: MIDIEndpointRef
	@usableFromInline let rx: PassthroughSubject<(MIDITimeStamp, MIDIUniversalMessage), Never>
	@inlinable
	public init(name: String, as version: MIDIProtocolID, client: Client = .default) throws {
		let tx = PassthroughSubject<(MIDITimeStamp, MIDIUniversalMessage), Never>()
		id = try withUnsafePointer(to: 0 as MIDIEndpointRef) {
			let status = MIDIDestinationCreateWithProtocol(client.id, name as CFString, version, .init(mutating: $0)) { msg, ref in
				MIDIEventListForEachEvent(msg, {
					guard case.some(let rx) = $0 else { return }
					Unmanaged<PassthroughSubject<(MIDITimeStamp, MIDIUniversalMessage), Never>>
						.fromOpaque(rx)
						.takeUnretainedValue()
						.send(($1, $2))
				}, Unmanaged.passUnretained(tx).toOpaque())
			}
			return switch status {
			case.zero:
				$0.pointee
			case let status:
				throw Error.native(status)
			}
		}
		rx = tx
	}
	deinit {
		MIDIEndpointDispose(id)
	}
}
extension Receiver: Combine.Publisher {
	public typealias Output = (MIDITimeStamp, MIDIUniversalMessage)
	public typealias Failure = Never
	public func receive(subscriber: some Combine.Subscriber<(MIDITimeStamp, MIDIUniversalMessage), Never>) {
		rx.subscribe(subscriber)
	}
}
