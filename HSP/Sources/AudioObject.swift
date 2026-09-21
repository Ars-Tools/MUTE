//
//  AudioObject.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//
import CoreAudio
import Darwin
@usableFromInline
protocol AudioObjectProtocol {
    var rawValue: AudioObjectID { get }
}
extension AudioObjectProtocol {
    @inlinable
    static func has(object: AudioObjectID, address: AudioObjectPropertyAddress) -> Bool {
        withUnsafePointer(to: address) {
            AudioObjectHasProperty(object, $0)
        }
    }
    @inlinable
    func has(address: AudioObjectPropertyAddress) -> Bool {
        Self.has(object: rawValue, address: address)
    }
}
extension AudioObjectProtocol {
    @inlinable
    static func bytes(object: AudioObjectID,
                      address: AudioObjectPropertyAddress,
                      qualifier: UnsafeRawBufferPointer = .init(start: .none, count: 0)) throws -> Int {
        try withUnsafePointer(to: address) {
            var size = .zero as UInt32
            switch AudioObjectGetPropertyDataSize(
                object,
                $0,
                .init(qualifier.count),
                qualifier.baseAddress,
                &size
            ) {
            case noErr:
                break
            case let status:
                throw Error(status: status)
            }
            return.init(size)
        }
    }
    @inlinable
    static func bytes<Qualifier: BitwiseCopyable>(object: AudioObjectID, address: AudioObjectPropertyAddress, qualifier: Qualifier) throws -> Int {
        try withUnsafeBytes(of: qualifier) {
            try bytes(object: object, address: address, qualifier: $0)
        }
    }
    @inlinable
    func bytes(address: AudioObjectPropertyAddress) throws -> Int {
        try Self.bytes(object: rawValue, address: address)
    }
    @inlinable
    func bytes<Qualifier: BitwiseCopyable>(address: AudioObjectPropertyAddress, qualifier: Qualifier) throws -> Int {
        try Self.bytes(object: rawValue, address: address, qualifier: qualifier)
    }
}
extension AudioObjectProtocol {
    @inlinable
    static func get(object: AudioObjectID,
                    address: AudioObjectPropertyAddress,
                    into buffer: UnsafeMutableRawBufferPointer,
                    qualifier: UnsafeRawBufferPointer = .init(start: .none, count: 0)) throws -> UnsafeMutableRawBufferPointer.Index {
        try withUnsafePointer(to: address) {
            var size = .init(buffer.count) as UInt32
            return switch AudioObjectGetPropertyData(object,
                                                     $0,
                                                     .init(qualifier.count),
                                                     qualifier.baseAddress,
                                                     &size,
                                                     buffer.baseAddress.unsafelyUnwrapped) {
            case noErr:
                    .init(size)
            case let status:
                throw Error(status: status)
            }
        }
    }
    @inlinable
    static func get<Q: BitwiseCopyable>(object: AudioObjectID,
                                        address: AudioObjectPropertyAddress,
                                        into buffer: UnsafeMutableRawBufferPointer,
                                        qualifier: Q) throws -> UnsafeMutableRawBufferPointer.Index {
        try withUnsafeBytes(of: qualifier) {
            try Self.get(object: object, address: address, into: buffer, qualifier: $0)
        }
    }
}
extension AudioObjectProtocol {
    @inlinable
    func get<T: BitwiseCopyable>(address: AudioObjectPropertyAddress) throws -> T {
        try withUnsafeTemporaryAllocation(byteCount: Self.bytes(object: rawValue, address: address),
                                          alignment: MemoryLayout<T>.alignment) {
            switch try Self.get(object: rawValue, address: address, into: $0) {
            case let bytes where bytes.isMultiple(of: MemoryLayout<T>.stride):
                $0.prefix(bytes).load(as: T.self)
            default:
                throw Error(status: kAudio_UnimplementedError)
            }
            
        }
    }
    @inlinable
    func get<T: BitwiseCopyable, Q: BitwiseCopyable>(address: AudioObjectPropertyAddress, qualifier: Q) throws -> T {
        try withUnsafeTemporaryAllocation(byteCount: Self.bytes(object: rawValue, address: address),
                                          alignment: MemoryLayout<T>.alignment) {
            switch try Self.get(object: rawValue, address: address, into: $0, qualifier: qualifier) {
            case let bytes where bytes.isMultiple(of: MemoryLayout<T>.stride):
                $0.prefix(bytes).load(as: T.self)
            default:
                throw Error(status: kAudio_UnimplementedError)
            }
        }
    }
}
extension AudioObjectProtocol {
    @inlinable
    func get<T: BitwiseCopyable>(address: AudioObjectPropertyAddress) throws -> Array<T> {
        switch try Self.bytes(object: rawValue, address: address).quotientAndRemainder(dividingBy: MemoryLayout<T>.stride) {
        case (let count, 0):
            try.init(unsafeUninitializedCapacity: count) {
                $1 = try Self.get(object: rawValue, address: address, into: .init($0)) / MemoryLayout<T>.stride
            }
        default:
            throw Error(status: kAudio_UnimplementedError)
        }
    }
    @inlinable
    func get<T: BitwiseCopyable, Q: BitwiseCopyable>(address: AudioObjectPropertyAddress, qualifier: Q) throws -> Array<T> {
        switch try Self.bytes(object: rawValue, address: address).quotientAndRemainder(dividingBy: MemoryLayout<T>.stride) {
        case (let count, 0):
            try.init(unsafeUninitializedCapacity: count) {
                $1 = try Self.get(object: rawValue, address: address, into: .init($0), qualifier: qualifier) / MemoryLayout<T>.stride
            }
        default:
            throw Error(status: kAudio_UnimplementedError)
        }
    }
}
extension AudioObjectProtocol {
    @inlinable
    static func set(object: AudioObjectID,
                    address: AudioObjectPropertyAddress,
                    from buffer: UnsafeRawBufferPointer,
                    qualifier: UnsafeRawBufferPointer = .init(start: .none, count: 0)) throws {
        try withUnsafePointer(to: address) {
            switch AudioObjectSetPropertyData(object,
                                                     $0,
                                                     .init(qualifier.count),
                                                     qualifier.baseAddress,
                                                     .init(buffer.count),
                                                     buffer.baseAddress.unsafelyUnwrapped) {
            case noErr:
                break
            case let status:
                throw Error(status: status)
            }
        }
    }
    @inlinable
    static func set<Q: BitwiseCopyable>(object: AudioObjectID,
                                        address: AudioObjectPropertyAddress,
                                        from buffer: UnsafeRawBufferPointer,
                                        qualifier: Q) throws {
        try withUnsafeBytes(of: qualifier) {
            try Self.set(object: object, address: address, from: buffer, qualifier: $0)
        }
    }
}
extension AudioObjectProtocol {
    @inlinable
    func set<T: BitwiseCopyable>(address: AudioObjectPropertyAddress, value: T) throws {
        try withUnsafeBytes(of: value) {
            try Self.set(object: rawValue, address: address, from: $0)
        }
    }
    @inlinable
    func set<T: BitwiseCopyable, Q: BitwiseCopyable>(address: AudioObjectPropertyAddress, value: T, qualifier: Q) throws {
        try withUnsafeBytes(of: value) {
            try Self.set(object: rawValue, address: address, from: $0, qualifier: qualifier)
        }
    }
}
extension AudioObjectProtocol {
    @inlinable
    func set<T: BitwiseCopyable>(address: AudioObjectPropertyAddress, value: Array<T>) throws {
        try value.withUnsafeBytes {
            try Self.set(object: rawValue, address: address, from: $0)
        }
    }
    @inlinable
    func set<T: BitwiseCopyable, Q: BitwiseCopyable>(address: AudioObjectPropertyAddress, value: Array<T>, qualifier: Q) throws {
        try value.withUnsafeBytes {
            try Self.set(object: rawValue, address: address, from: $0, qualifier: qualifier)
        }
    }
}
extension AudioObjectProtocol {
    @inlinable
    var uuid: String {
        get throws {
            try(get(address: .init(mSelector: kAudioDevicePropertyDeviceUID,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
            ) as Unmanaged<CFString>).takeRetainedValue() as String
        }
    }
}
@usableFromInline
protocol AudioDeviceProtocol: AudioObjectProtocol {}
extension AudioDeviceProtocol {
    @inlinable
    var running: Bool {
        get throws {
            try get(address: .init(
                mSelector: kAudioDevicePropertyDeviceIsRunning,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )) != UInt32.zero
        }
    }
    @inlinable
    var usesVariableBufferFrameSizes: UInt32 {
        get throws {
            try get(address: .init(mSelector: kAudioDevicePropertyUsesVariableBufferFrameSizes,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain))
        }
    }
    @inlinable
    var bufferFrameSize: UInt32 {
        get throws {
            try get(address: .init(mSelector: kAudioDevicePropertyBufferFrameSize,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain))
        }
    }
    @inlinable
    var maximumIOFrameCount: UInt32 {
        get throws {
            try has(address: .init(mSelector: kAudioDevicePropertyUsesVariableBufferFrameSizes,
                                   mScope: kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)) ?
            usesVariableBufferFrameSizes : bufferFrameSize
        }
    }
    @inlinable
    func streams(scope: AudioObjectPropertyScope) throws -> [AudioStream] {
        try(get(address: .init(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )) as [AudioObjectID]).map(AudioStream.init(rawValue:))
    }
}

@usableFromInline
struct AudioDevice: AudioDeviceProtocol, Sendable, BitwiseCopyable {
    @usableFromInline
    let rawValue: AudioObjectID
    @inlinable
    init(rawValue: AudioObjectID) {
        self.rawValue = rawValue
    }
}

@usableFromInline
struct AudioStream: AudioObjectProtocol, Sendable, BitwiseCopyable {
    @usableFromInline
    let rawValue: AudioObjectID
    @inlinable
    init(rawValue: AudioObjectID) {
        self.rawValue = rawValue
    }
}
extension AudioStream {
    @inlinable
    var virtualFormat: AudioStreamBasicDescription {
        get throws {
            try get(address: .init(
                mSelector: kAudioStreamPropertyVirtualFormat,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            ))
        }
    }
}
@usableFromInline
struct SystemObject {
    @usableFromInline
    let rawValue: AudioObjectID
    fileprivate init(rawValue: AudioObjectID) {
        self.rawValue = rawValue
    }
    @usableFromInline
    static let shared = Self(rawValue: .init(kAudioObjectSystemObject))
}
extension SystemObject: AudioObjectProtocol, Sendable, BitwiseCopyable {}
extension SystemObject {
    @inlinable
    static var inputDevice: AudioDevice {
        get throws {
            try.init(rawValue: shared.get(address: .init(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )))
        }
    }
    @usableFromInline
    static var outputDevice: AudioDevice {
        get throws {
            try.init(rawValue: shared.get(address: .init(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )))
        }
    }
    @inlinable
    static func process(id: pid_t) throws -> AudioObjectID {
        try shared.get(address: .init(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        ), qualifier: id)
    }
    @usableFromInline
    static let currentProcess: AudioObjectID = try!process(id: getpid())
}
