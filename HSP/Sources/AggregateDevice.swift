//
//  AggregateDevice.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//
import CoreAudio
@usableFromInline
final class AggregateDevice: AudioDeviceProtocol, RawRepresentable, Sendable {
    @usableFromInline
    let rawValue: AudioObjectID
    @inlinable
    init(rawValue: AudioObjectID) {
        self.rawValue = rawValue
    }
    @inlinable
    deinit {
        switch AudioHardwareDestroyAggregateDevice(rawValue) {
        case noErr:
            break
        case let status:
            Error.log(status: status)
        }
    }
}
extension AggregateDevice {
    @inlinable
    convenience init(description: Dictionary<String, Any>) throws (Error) {
        var handle = kAudioObjectUnknown as AudioObjectID
        switch AudioHardwareCreateAggregateDevice(
            description as CFDictionary,
            &handle
        ) {
        case noErr where handle != kAudioObjectUnknown:
            self.init(rawValue: handle)
        case let status:
            throw Error(status: status)
        }
    }
}

@usableFromInline
struct AggregateStream: Copyable, Sendable {
    @usableFromInline
    let device: AggregateDevice
    @usableFromInline
    let taps: [Tap]
    @usableFromInline
    let inputStreams: [AudioStream]
    @usableFromInline
    let outputStreams: [AudioStream]
}
extension AggregateStream {
    @usableFromInline
    init(description: Dictionary<String, Any>, taps: Array<Tap> = .init()) throws {
        switch try AggregateDevice(description: description) {
        case let device:
            try self.init(
                device: device,
                taps: taps,
                inputStreams: device.streams(scope: kAudioObjectPropertyScopeInput),
                outputStreams: device.streams(scope: kAudioObjectPropertyScopeOutput)
            )
        }
    }
    @inlinable
    var deviceID: AudioDeviceID {
        _read { yield device.rawValue }
    }
}
