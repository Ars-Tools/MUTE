//
//  IOProc.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//

import CoreAudio

@usableFromInline
final class IOProcResource: Sendable {
    @usableFromInline
    let device: AggregateDevice
    @usableFromInline
    let rawValue: AudioDeviceIOProcID
    @inlinable
    init(
        device: AggregateDevice,
        proc block: @escaping AudioDeviceIOBlock
    ) throws {
        self.device = device
        var handle = .none as Optional<AudioDeviceIOProcID>
        switch AudioDeviceCreateIOProcIDWithBlock(
            &handle,
            device.rawValue,
            nil,
            block
        ) {
        case noErr where handle != nil:
            rawValue = handle.unsafelyUnwrapped
        case let status:
            throw Error(status: status)
        }
    }

    @inlinable
    deinit {
        switch AudioDeviceDestroyIOProcID(device.rawValue, rawValue) {
        case noErr:
            break
        case let status:
            Error.log(status: status)
        }
    }
}
@usableFromInline
struct IOProc {
    @usableFromInline
    let stream: AggregateStream
    @usableFromInline
    let resource: IOProcResource
    @inlinable
    init(stream: AggregateStream, proc block: @escaping AudioDeviceIOBlock) throws {
        try self.init(stream: stream, resource: IOProcResource(
            device: stream.device,
            proc: block
        ))
        try start()
    }
    @inlinable
    init(stream: AggregateStream, resource: IOProcResource) {
        self.stream = stream
        self.resource = resource
    }
    @inlinable
    func start() throws {
        switch AudioDeviceStart(stream.deviceID, resource.rawValue) {
        case noErr:
            break
        case let status:
            throw Error(status: status)
        }
    }
    @inlinable
    func stop() throws {
        switch AudioDeviceStop(stream.deviceID, resource.rawValue) {
        case noErr:
            break
        case let status:
            throw Error(status: status)
        }
    }
}
