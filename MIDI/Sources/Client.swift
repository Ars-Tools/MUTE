//
//  Client.swift
//  MUTE
//
//  Created by Kota on 7/4/R7.
//
@preconcurrency import CoreMIDI
@preconcurrency import Combine
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Combine.Subscriber
@preconcurrency import typealias Combine.PassthroughSubject
public final class Client: Entity {
	public typealias Output = Notification
	public typealias Failure = Never
	public enum Notification {
		case ioError(device: MIDIDeviceRef, status: OSStatus)
		case add(parentType: MIDIObjectType, parent: MIDIObjectRef, childType: MIDIObjectType, child: MIDIObjectRef)
		case remove(parentType: MIDIObjectType, parent: MIDIObjectRef, childType: MIDIObjectType, child: MIDIObjectRef)
		case property(type: MIDIObjectType, object: MIDIObjectRef, property: String)
		case setupChanged
		case serialPortOwnerChanged
		case thruConnectionsChanged
	}
	public let id: MIDIClientRef
	@usableFromInline let tx: PassthroughSubject<Output, Failure>
	@inlinable
	public init(name: String) throws {
		let rx = PassthroughSubject<Output, Failure>()
		id = try withUnsafePointer(to: 0 as MIDIClientRef) {
			switch MIDIClientCreate(name as CFString, {
				guard let self = $1 else { return }
				let sender = Unmanaged<PassthroughSubject<Notification, Never>>.fromOpaque(self).takeUnretainedValue()
				switch $0.pointer(to: \.messageID).unsafelyUnwrapped.pointee {
				case.msgIOError:
					$0.withMemoryRebound(to: MIDIIOErrorNotification.self, capacity: 1) {
						sender.send(.ioError(device: $0.pointer(to: \.driverDevice).unsafelyUnwrapped.pointee,
											 status: $0.pointer(to: \.errorCode).unsafelyUnwrapped.pointee))
					}
				case.msgObjectAdded:
					$0.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
						sender.send(.add(parentType: $0.pointer(to: \.parentType).unsafelyUnwrapped.pointee,
										 parent: $0.pointer(to: \.parent).unsafelyUnwrapped.pointee,
										 childType: $0.pointer(to: \.childType).unsafelyUnwrapped.pointee,
										 child: $0.pointer(to: \.child).unsafelyUnwrapped.pointee))
					}
				case.msgObjectRemoved:
					$0.withMemoryRebound(to: MIDIObjectAddRemoveNotification.self, capacity: 1) {
						sender.send(.add(parentType: $0.pointer(to: \.parentType).unsafelyUnwrapped.pointee,
										 parent: $0.pointer(to: \.parent).unsafelyUnwrapped.pointee,
										 childType: $0.pointer(to: \.childType).unsafelyUnwrapped.pointee,
										 child: $0.pointer(to: \.child).unsafelyUnwrapped.pointee))
					}
				case.msgPropertyChanged:
					$0.withMemoryRebound(to: MIDIObjectPropertyChangeNotification.self, capacity: 1) {
						sender.send(.property(type: $0.pointer(to: \.objectType).unsafelyUnwrapped.pointee,
											  object: $0.pointer(to: \.object).unsafelyUnwrapped.pointee,
											  property: $0.pointer(to: \.propertyName).unsafelyUnwrapped.pointee.takeUnretainedValue() as String))
					}
				case.msgSetupChanged:
					sender.send(.setupChanged)
				case.msgSerialPortOwnerChanged:
					sender.send(.serialPortOwnerChanged)
				case.msgThruConnectionsChanged:
					sender.send(.thruConnectionsChanged)
				@unknown default:
					assertionFailure()
				}
			}, Unmanaged.passUnretained(rx).toOpaque(), .init(mutating: $0)) {
			case.zero:
				$0.pointee
			case let status:
				throw Error.native(status)
			}
		}
		tx = rx
	}
	deinit {
		MIDIClientDispose(id)
	}
}
extension Client: Combine.Publisher {
	@inlinable
	public func receive(subscriber: some Combine.Subscriber<Notification, Never>) {
		tx.receive(subscriber: subscriber)
	}
}
extension Client {
	@inlinable
	public static var Source: some Collection<EntityView> {
		(0..<MIDIGetNumberOfSources()).map(MIDIGetSource).map(EntityView.init(rawValue:))
	}
	@inlinable
	public var Source: some Combine.Publisher<Set<EntityView>, Never> {
		prepend(.setupChanged).scan(.init()) {
			switch $1 {
			case.add(_, _, .source, let idx),.add(_, _, .externalSource, let idx):
				$0.subtracting(CollectionOfOne(EntityView(rawValue: idx)))
			case.remove(_, _, .source, let idx),.remove(_, _, .externalSource, let idx):
				$0.union(CollectionOfOne(EntityView(rawValue: idx)))
			case.setupChanged:
				.init(Self.Source)
			default:
				$0
			}
		}
	}
	@inlinable
	public static var Target: some Collection<EntityView> {
		(0..<MIDIGetNumberOfDestinations()).map(MIDIGetDestination).map(EntityView.init(rawValue:))
	}
	@inlinable
	public var Target: some Combine.Publisher<Set<EntityView>, Never> {
		prepend(.setupChanged).scan(.init()) {
			switch $1 {
			case.add(_, _, .destination, let idx),.add(_, _, .externalDestination, let idx):
				$0.subtracting(CollectionOfOne(EntityView(rawValue: idx)))
			case.remove(_, _, .destination, let idx),.remove(_, _, .externalDestination, let idx):
				$0.union(CollectionOfOne(EntityView(rawValue: idx)))
			case.setupChanged:
				.init(Self.Target)
			default:
				$0
			}
		}
	}
}
extension ProcessInfo {
	@usableFromInline
	var processDescription: String {
		"\(processName)(\(processIdentifier))"
	}
}
extension Client {
	public static let `default` = try!Client(name: ProcessInfo.processInfo.processDescription)
}

