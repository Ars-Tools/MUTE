//
//  Subscriber.swift
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
@preconcurrency import typealias CoreFoundation.CFString
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Combine.Subscriber
@preconcurrency import typealias Combine.Publishers
@preconcurrency import typealias Combine.PassthroughSubject
@preconcurrency import typealias Combine.Empty
@preconcurrency import typealias CoreMIDI.MIDIPortRef
@preconcurrency import typealias CoreMIDI.MIDIProtocolID
@preconcurrency import typealias CoreMIDI.MIDITimeStamp
@preconcurrency import typealias CoreMIDI.MIDIUniversalMessage
@preconcurrency import typealias CoreMIDI.MIDIEndpointRef
@preconcurrency import func CoreMIDI.MIDIInputPortCreateWithProtocol
@preconcurrency import func CoreMIDI.MIDIEventListForEachEvent
@preconcurrency import func CoreMIDI.MIDIPortConnectSource
@preconcurrency import func CoreMIDI.MIDIPortDisconnectSource
@preconcurrency import func CoreMIDI.MIDIPortDispose
public final class Subscriber: Instance {
	public let id: MIDIPortRef
	public let client: Client
	@inlinable
	public init(name: String, as version: MIDIProtocolID, client parent: Client = .default) throws {
		id = try withUnsafePointer(to: 0 as MIDIPortRef) {
			let status = MIDIInputPortCreateWithProtocol(parent.id, name as CFString, version, .init(mutating: $0)) {
				MIDIEventListForEachEvent($0, {
					guard let target = $0 else { return }
					Unmanaged<PassthroughSubject<(MIDITimeStamp, MIDIUniversalMessage), Never>>
						.fromOpaque(target)
						.takeUnretainedValue()
						.send(($1, $2))
				}, $1)
			}
			return switch status {
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
extension Subscriber {
	public typealias Output = (MIDITimeStamp, MIDIUniversalMessage)
	public typealias Failure = Never
	public func subscribe(from endpoint: MIDIEndpointRef) throws -> some Source {
		let rx = PassthroughSubject<(MIDITimeStamp, MIDIUniversalMessage), Never>()
		return switch MIDIPortConnectSource(id, endpoint, Unmanaged.passUnretained(rx).toOpaque()) {
		case.zero:
			rx.handleEvents(receiveCompletion: .some({ [self] completion in
				MIDIPortDisconnectSource(id, endpoint)
			}), receiveCancel: .some({ [self] in
				MIDIPortDisconnectSource(id, endpoint)
			}))
		case let status:
			throw Error.native(status)
		}
	}
}
extension Subscriber {
	public func subscribe(from displayName: String) throws -> some Source {
		client.Source
			.map {
				$0.first { $0.displayName == displayName }
			}
			.removeDuplicates()
			.compactMap { [self] in
				try?$0.map(\.id).map(subscribe(from:))
			}
			.switchToLatest()
	}
}
