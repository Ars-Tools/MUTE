//
//  Tap.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//
import CoreAudio
@usableFromInline
final class Tap: RawRepresentable, AudioObjectProtocol, Sendable {
    @usableFromInline
    let rawValue: AudioObjectID
    @inlinable
    init(rawValue: AudioObjectID) {
        self.rawValue = rawValue
    }
    @inlinable
    deinit {
        switch AudioHardwareDestroyProcessTap(rawValue) {
        case noErr:
            break
        case let status:
            Error.log(status: status)
        }
    }
}

extension Tap {
    @inlinable
    convenience init(description: CATapDescription) throws {
        var handle = kAudioObjectUnknown as AudioObjectID
        switch AudioHardwareCreateProcessTap(description, &handle) {
        case noErr where handle != kAudioObjectUnknown:
            self.init(rawValue: handle)
        case let status:
            throw Error(status: status)
        }
    }
    @inlinable
    var format: AudioStreamBasicDescription {
        get throws {
            try AudioHardwareTap(id: rawValue).format
        }
    }
}
