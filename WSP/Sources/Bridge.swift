//
//  Bridge.swift
//  MUTE
//
//  Created by Kota on 7/21/R7.
//
import typealias CoreFoundation.CFString
import typealias CoreFoundation.CFData
import typealias CoreMIDI.MIDIEndpointRef
import typealias CoreMIDI.MIDIThruConnectionRef
import typealias CoreMIDI.MIDIThruConnectionParams
import typealias Foundation.Data
import func CoreMIDI.MIDIThruConnectionParamsInitialize
import func CoreMIDI.MIDIThruConnectionCreate
import func CoreMIDI.MIDIThruConnectionDispose
import protocol Combine.Publisher
import protocol Combine.Subscriber
import typealias Combine.Publishers
// MARK: Bridge class to connect between some CoreMIDI-Sources and CoreMIDI-Destinations
public final class Bridge: Entity {
	public let id: MIDIThruConnectionRef
	public init(owner: String, configuration: (UnsafeMutablePointer<MIDIThruConnectionParams>) -> Void) throws {
		id = try withUnsafePointer(to: 0 as MIDIThruConnectionRef) {
			var data = Data(count: MemoryLayout<MIDIThruConnectionParams>.size)
			data.withUnsafeMutableBytes {
				$0.withMemoryRebound(to: MIDIThruConnectionParams.self) {
					guard let memory = $0.baseAddress else { return }
					MIDIThruConnectionParamsInitialize(memory)
					configuration(memory)
				}
			}
			return switch MIDIThruConnectionCreate(owner as CFString, data as CFData, .init(mutating: $0)) {
			case.zero:
				$0.pointee
			case let status:
				throw Error.native(status)
			}
		}
	}
	@inlinable
	deinit {
		MIDIThruConnectionDispose(id)
	}
}
extension Bridge {
	public convenience init(from source: MIDIEndpointRef, to target: MIDIEndpointRef, as name: String) throws {
		try self.init(owner: name) {
			$0.pointee.numSources = 1
			$0.pointee.sources.0.endpointRef = source
			$0.pointee.numDestinations = 1
			$0.pointee.destinations.0.endpointRef = target
		}
	}
}
extension Bridge {
	public static func Connection(from source: String, to target: String, as name: String, client: Client = .default) -> some Combine.Publisher<Bool, Never> {
		Publishers.CombineLatest(client.Source, client.Target)
			.map {
				let source = $0.first { $0.displayName == .some(source) }
				let target = $1.first { $0.displayName == .some(target) }
				return (source.map(\.id), target.map(\.id))
			}
			.removeDuplicates(by: ==)
			.scan(.none as Optional<Bridge>) {
				switch $1 {
				case (.some(let lhs), .some(let rhs)):
					try?Bridge(from: lhs, to: rhs, as: name)
				default:
					.none
				}
			}.map {
				$0 != .none
			}
	}
}
