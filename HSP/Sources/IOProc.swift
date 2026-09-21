//
//  IOProc.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//

import CoreAudio

@usableFromInline
final class IOProc {
    @usableFromInline
    let stream: AggregateStream
    @usableFromInline
    let rawValue: AudioDeviceIOProcID

    @usableFromInline
    init(
        stream: AggregateStream,
        proc block: @escaping AudioDeviceIOBlock
    ) throws {
        self.stream = stream
        var handle: AudioDeviceIOProcID?
        switch AudioDeviceCreateIOProcIDWithBlock(
            &handle,
            stream.device.deviceID,
            nil,
            block
        ) {
        case noErr where handle != nil:
            rawValue = handle.unsafelyUnwrapped
        case let status:
            throw Error(status: status)
        }

        switch AudioDeviceStart(stream.device.deviceID, rawValue) {
        case noErr:
            break
        case let status:
            AudioDeviceDestroyIOProcID(stream.device.deviceID, rawValue)
            throw Error(status: status)
        }
    }

    @usableFromInline
    deinit {
        try? stop()
        switch AudioDeviceDestroyIOProcID(stream.device.deviceID, rawValue) {
        case noErr:
            break
        case let status:
            Error.log(status: status)
        }
    }

    @usableFromInline
    func stop() throws {
        switch AudioDeviceStop(stream.device.deviceID, rawValue) {
        case noErr:
            break
        case let status:
            throw Error(status: status)
        }
    }
}
