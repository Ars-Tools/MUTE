//
//  IOProc.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//
import CoreAudio
import protocol DSP.Stream
@usableFromInline
final class IOProc {
    @usableFromInline
    let stream: AggregateStream
    @usableFromInline
    let rawValue: AudioDeviceIOProcID
    @inlinable
    init(stream: AggregateStream, rawValue: AudioDeviceIOProcID) {
        self.stream = stream
        self.rawValue = rawValue
    }
    @usableFromInline
    deinit {
        try?stop()
        switch AudioDeviceDestroyIOProcID(stream.deviceID, rawValue) {
        case noErr:
            break
        case let status:
            Error.log(status: status)
        }
    }
}

extension IOProc {
    @usableFromInline
    convenience init(
        stream: AggregateStream,
        proc block: @escaping AudioDeviceIOBlock
    ) throws {
        try self.init(
            stream: stream,
            inputStreams: Set(stream.inputStreams.indices),
            outputStreams: Set(stream.outputStreams.indices),
            proc: block
        )
    }

    @usableFromInline
    convenience init(
        stream: AggregateStream,
        inputStreams: Set<Int>,
        outputStreams: Set<Int>,
        proc block: @escaping AudioDeviceIOBlock
    ) throws {
        switch stream.inputStreams.count {
        case let streamCount:
            guard inputStreams.allSatisfy((0..<streamCount).contains) else {
                throw Error(status: kAudio_ParamError)
            }
        }
        switch stream.outputStreams.count {
        case let streamCount:
            guard outputStreams.allSatisfy((0..<streamCount).contains) else {
                throw Error(status: kAudio_ParamError)
            }
        }
        var handle = .none as Optional<AudioDeviceIOProcID>
        switch AudioDeviceCreateIOProcIDWithBlock(
            &handle,
            stream.deviceID,
            nil,
            block
        ) {
        case noErr where handle != nil:
            self.init(stream: stream, rawValue: handle.unsafelyUnwrapped)
            try setStreamUsage(
                inputStreams,
                scope: kAudioObjectPropertyScopeInput
            )
            try setStreamUsage(
                outputStreams,
                scope: kAudioObjectPropertyScopeOutput
            )
            try self.start()
        case let status:
            throw Error(status: status)
        }
    }

    @usableFromInline
    convenience init(
        stream: AggregateStream,
        inputStreams: Set<Int>,
        outputStreams: Set<Int>,
        prepare: (
            _ formats: StreamFormats,
            _ maximumIOFrameCount: UInt32
        ) throws -> AudioDeviceIOBlock
    ) throws {
        let formats = try StreamFormats(
            stream: stream,
            inputStreams: inputStreams,
            outputStreams: outputStreams
        )
        let maximumIOFrameCount = try stream.device.maximumIOFrameCount
        try self.init(
            stream: stream,
            inputStreams: inputStreams,
            outputStreams: outputStreams,
            proc: try prepare(formats, maximumIOFrameCount)
        )
    }
    @inlinable
    convenience init(
        stream: AggregateStream,
        with dsp: (DSP.Stream) -> DSP.Stream
    ) throws {
        fatalError()
    }
}
extension IOProc {
    private func setStreamUsage(
        _ streams: Set<Int>,
        scope: AudioObjectPropertyScope
    ) throws {
        let count = switch scope {
        case kAudioObjectPropertyScopeInput:
            stream.inputStreams.count
        case kAudioObjectPropertyScopeOutput:
            stream.outputStreams.count
        default:
            throw Error(status: kAudio_ParamError)
        }
        guard count > 0 else { return }
        guard streams.allSatisfy((0..<count).contains) else {
            throw Error(status: kAudio_ParamError)
        }
        try withUnsafeTemporaryAllocation(
            byteCount: MemoryLayout<AudioHardwareIOProcStreamUsage>.stride + (count - 1) * MemoryLayout<UInt32>.stride,
            alignment: MemoryLayout<AudioHardwareIOProcStreamUsage>.alignment
        ) {
            let usage = $0.assumingMemoryBound(to: AudioHardwareIOProcStreamUsage.self)
            usage.prefix(1).initialize(repeating: .init(
                mIOProc: unsafeBitCast(rawValue, to: UnsafeMutableRawPointer.self),
                mNumberStreams: .init(count),
                mStreamIsOn: 0
            ))
            let extra = UnsafeMutableBufferPointer(start: usage.baseAddress.flatMap { $0.pointer(to: \.mStreamIsOn) },
                                                   count: count)
            extra.initialize(repeating: 0)
            for index in streams {
                extra[index] = 1
            }
            try AggregateDevice.set(object: stream.deviceID,
                                    address: .init(mSelector: kAudioDevicePropertyIOProcStreamUsage,
                                                   mScope: scope,
                                                   mElement: kAudioObjectPropertyElementMain),
                                    from: .init($0))
        }
    }

    private func start() throws {
        switch AudioDeviceStart(stream.deviceID, rawValue) {
        case noErr:
            break
        case let status:
            throw Error(status: status)
        }
    }
    private func stop() throws {
        switch AudioDeviceStop(stream.deviceID, rawValue) {
        case noErr:
            break
        case let status:
            throw Error(status: status)
        }
    }
}
