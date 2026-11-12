import CoreAudio
import Darwin
import Foundation

extension VirtualAudioInputDeviceProtocol {
    public func GetPropertyData(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifier: UnsafeRawBufferPointer, data: UnsafeMutableRawBufferPointer
    ) throws -> Int {
        throw Error(status: kAudioHardwareUnknownPropertyError)
    }

    public func SetPropertyData(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifier: UnsafeRawBufferPointer, data: UnsafeRawBufferPointer
    ) throws -> Int {
        throw Error(status: HasProperty(object: object, pid: pid, address: address) == nil
            ? kAudioHardwareUnknownPropertyError : kAudioHardwareUnsupportedOperationError)
    }

    /// An empty destination queries required capacity without consuming the value.
    public func GetPropertyDataSize(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifier: UnsafeRawBufferPointer = UnsafeRawBufferPointer(start: .none, count: 0)
    ) throws -> Int {
        let count: Int = try GetPropertyData(object: object, pid: pid, address: address,
                                             qualifier: qualifier, data: UnsafeMutableRawBufferPointer(start: .none, count: 0))
        guard count >= 0 else { throw Error(status: kAudioHardwareBadPropertySizeError) }
        return count
    }

    /// Retry when the property has grown since the preceding capacity query.
    public func GetPropertyData(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifier: UnsafeRawBufferPointer = UnsafeRawBufferPointer(start: .none, count: 0)
    ) throws -> Data {
        let count = try GetPropertyData(object: object, pid: pid, address: address, qualifier: qualifier, data: .none)
        guard 0 <= count else { throw Error(status: kAudioHardwareBadPropertySizeError) }
        var data = Data(count: count)
        data.count = try data.withUnsafeMutableBytes {
            try GetPropertyData(object: object, pid: pid, address: address, qualifier: qualifier, data: $0)
        }
        guard data.count <= count else { throw Error(status: kAudioHardwareBadPropertySizeError) }
        return data
    }

    /// Data and Array<UInt8> expose contiguous bytes through this overload.
    @discardableResult
    public func SetPropertyData<Bytes: ContiguousBytes>(
        object: AudioObjectID, pid: pid_t, address: UnsafePointer<AudioObjectPropertyAddress>,
        qualifier: UnsafeRawBufferPointer = UnsafeRawBufferPointer(start: .none, count: 0), data: Bytes
    ) throws -> Int {
        try data.withUnsafeBytes {
            try SetPropertyData(object: object, pid: pid, address: address, qualifier: qualifier, data: $0)
        }
    }
}
extension OSStatus {
    @inlinable
    init(error: any Swift.Error) {
        self = switch error {
        case let error as Error where error.status == noErr:
            kAudioHardwareUnspecifiedError
        case let error as Error:
            error.status
        case let error as NSError where error.domain == NSOSStatusErrorDomain:
                .init(exactly: error.code) ?? kAudioHardwareUnspecifiedError
        default:
            kAudioHardwareUnspecifiedError
        }
    }
}
