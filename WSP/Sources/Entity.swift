//
//  Entity.swift
//  MUTE
//
//  Created by Kota on 7/22/R7.
//
@preconcurrency import typealias CoreFoundation.CFString
@preconcurrency import typealias CoreMIDI.MIDIProtocolID
@preconcurrency import func CoreMIDI.MIDIEventListForEachEvent
@preconcurrency import func CoreMIDI.MIDIObjectGetStringProperty
@preconcurrency import func CoreMIDI.MIDIObjectGetIntegerProperty
@preconcurrency import let CoreMIDI.kMIDIPropertyName
@preconcurrency import let CoreMIDI.kMIDIPropertyDisplayName
@preconcurrency import let CoreMIDI.kMIDIPropertyOffline
@preconcurrency import let CoreMIDI.kMIDIPropertyPrivate
@preconcurrency import let CoreMIDI.kMIDIPropertyProtocolID
// MARK: Entity, as a foundamental protocol for CoreMIDI entities
public protocol Entity: Identifiable, Hashable, Sendable {
	@inlinable
	var id: UInt32 { get }
}
extension Entity {
	@inlinable @inline(__always)
	func int(for key: CFString) -> Optional<Int32> {
		withUnsafePointer(to: 0 as Int32) {
			MIDIObjectGetIntegerProperty(id, key, .init(mutating: $0)) == .zero ? .some($0.pointee) : .none
		}
	}
	@inlinable @inline(__always)
	func string(for key: CFString) -> Optional<String> {
		withUnsafePointer(to: .none as Optional<Unmanaged<CFString>>) {
			switch MIDIObjectGetStringProperty(id, key, .init(mutating: $0)) {
			case.zero:
				$0.pointee.map { r in
					defer {
						r.release()
					}
					return r.takeUnretainedValue() as String
				}
			default:
				.none
			}
		}
	}
}
extension Entity {
	@inlinable
	public var propertyName: Optional<String> {
		string(for: kMIDIPropertyName)
	}
	@inlinable
	public var displayName: Optional<String> {
		string(for: kMIDIPropertyDisplayName)
	}
	@inlinable
	public var `protocol`: Optional<MIDIProtocolID> {
		int(for: kMIDIPropertyProtocolID).flatMap(MIDIProtocolID.init(rawValue:))
	}
	@inlinable
	public var isOnline: Bool {
		int(for: kMIDIPropertyOffline).map { $0 == .zero } ?? false
	}
	@inlinable
	public var isPrivate: Bool {
		int(for: kMIDIPropertyPrivate).map { $0 != .zero } ?? false
	}
}
extension Entity {
	@inlinable
	public static func==(lhs: Self, rhs: Self) -> Bool {
		lhs.id == rhs.id
	}
	@inlinable
	public func hash(into hasher: inout Hasher) {
		id.hash(into: &hasher)
	}
}
// MARK: EntityView to view entity properties
public struct EntityView: Entity {
	public let id: UInt32
}
extension EntityView {
	@inlinable
	public static func==(lhs: Self, rhs: Self) -> Bool {
		lhs.id == rhs.id
	}
	@inlinable
	public func hash(into hasher: inout Hasher) {
		id.hash(into: &hasher)
	}
}
extension EntityView: RawRepresentable, Codable {
	@inlinable
	public init(rawValue: UInt32) {
		id = rawValue
	}
	@inlinable
	public var rawValue: UInt32 {
		id
	}
}
extension EntityView: CustomStringConvertible {
	public var description: String {
		displayName ?? "unk(\(id))"
	}
}
