//
//  AggregateDevice.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//
import CoreAudio
@usableFromInline
final class AggregateDevice: AudioDeviceProtocol {
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
struct AggregateStream {
    @usableFromInline
    let device: AggregateDevice
    @usableFromInline
    let taps: Array<Tap>
    @usableFromInline
    let inputStreams: Array<AudioStream>
    @usableFromInline
    let outputStreams: Array<AudioStream>
}
extension AggregateStream {
    @usableFromInline
    init(description: Dictionary<String, Any>, taps: Array<Tap> = .init()) throws {
        let device = try AggregateDevice(description: description)
        let input = try device.streams(scope: kAudioObjectPropertyScopeInput)
        let output = try device.streams(scope: kAudioObjectPropertyScopeOutput)
        self.init(device: device,
                  taps: taps,
                  inputStreams: input,
                  outputStreams: output)
    }
    @inlinable
    var deviceID: AudioDeviceID {
        _read {
            yield device.rawValue
        }
    }
}
