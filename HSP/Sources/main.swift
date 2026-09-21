//
//  main.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//

#if !os(macOS)
#error("HSP requires native macOS Core Audio HAL.")
#endif

import CoreAudio
import Darwin
import Dispatch
import Foundation

let paths: [StreamPath] = [(
    input: [0],
    output: [0],
    ioproc: { _, input, _, output, _ in
        for (input, output) in zip(
            UnsafeMutableAudioBufferListPointer(
                UnsafeMutablePointer(mutating: input)
            ),
            UnsafeMutableAudioBufferListPointer(output)
        ) {
            guard let source = input.mData,
                  let destination = output.mData
            else { continue }
            let count = min(
                Int(input.mDataByteSize),
                Int(output.mDataByteSize)
            )
            destination.copyMemory(from: source, byteCount: count)
            let remainder = Int(output.mDataByteSize) - count
            if remainder > 0 {
                destination.advanced(by: count).initializeMemory(
                    as: UInt8.self,
                    repeating: 0,
                    count: remainder
                )
            }
        }
    }
)]
try paths.validate()

let outputDevice = try SystemObject.outputDevice
let outputUID = try outputDevice.uuid
let physicalOutputStreams = try outputDevice.streams(
    scope: kAudioObjectPropertyScopeOutput
)
let tapDescriptions = physicalOutputStreams.indices.map { bus in
    let description = CATapDescription(
        excludingProcesses: [SystemObject.currentProcess],
        deviceUID: outputUID,
        stream: UInt(bus)
    )
    description.name = "MUTE HSP Tap \(bus)"
    description.isPrivate = true
    description.muteBehavior = .mutedWhenTapped
    return description
}
let processTaps = try tapDescriptions.map(Tap.init(description:))

let aggregateDescription: [String: Any] = [
    kAudioAggregateDeviceNameKey: "MUTE.HSP",
    kAudioAggregateDeviceUIDKey: "tools.ars.mute.host.\(UUID().uuidString)",
    kAudioAggregateDeviceIsPrivateKey: true,
    kAudioAggregateDeviceMainSubDeviceKey: outputUID,
    kAudioAggregateDeviceSubDeviceListKey: [[
        kAudioSubDeviceUIDKey: outputUID,
        // The physical device is output-only in this aggregate;
        // the tap is its sole input source.
        kAudioSubDeviceInputChannelsKey: 0,
    ]],
    kAudioAggregateDeviceTapListKey: tapDescriptions.map { tap in
        [kAudioSubTapUIDKey: tap.uuid.uuidString]
    },
]

let aggregate = try AggregateStream(
    description: aggregateDescription,
    taps: processTaps
)
let maximumIOFrameCount = try aggregate.device.maximumIOFrameCount
print("maximum frames/callback:", maximumIOFrameCount)

guard aggregate.inputStreams.count == physicalOutputStreams.count else {
    throw Error(
        operation: "aggregate input stream mapping",
        status: kAudio_ParamError
    )
}

let ioProcs = try paths.map { path in
    return try IOProc(
        stream: aggregate,
        inputStreams: path.input,
        outputStreams: path.output,
        proc: path.ioproc
    )
}

print("HSP is running \(ioProcs.count) stream paths.")
print("Output device UID: \(outputUID)")
print("Press Control-C to stop.")

signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)

let termination = DispatchSemaphore(value: 0)
let signalSources = Array(arrayLiteral: SIGINT, SIGTERM).map {
    let source = DispatchSource.makeSignalSource(signal: $0, queue: .global())
    source.setEventHandler { [termination] in
        termination.signal()
    }
    source.resume()
    return source
}
withExtendedLifetime((signalSources, ioProcs), termination.wait)
