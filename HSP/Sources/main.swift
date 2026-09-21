//
//  main.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//

#if !os(macOS)
#error("HSP requires native macOS Core Audio HAL.")
#endif

import AVFoundation
import CoreAudio
import Foundation

let outputDevice = try SystemObject.outputDevice
let outputUID = try outputDevice.uuid
let physicalOutputStreams = try outputDevice.streams(
    scope: kAudioObjectPropertyScopeOutput
)

let tapDescriptions = physicalOutputStreams.indices.map { stream in
    let description = CATapDescription(
        excludingProcesses: [SystemObject.currentProcess],
        deviceUID: outputUID,
        stream: UInt(stream)
    )
    description.name = "MUTE HSP Tap \(stream)"
    description.isPrivate = true
    description.muteBehavior = .mutedWhenTapped
    return description
}
let taps = try tapDescriptions.map(Tap.init(description:))

let aggregate = try AggregateStream(
    description: [
        kAudioAggregateDeviceNameKey: "MUTE.HSP",
        kAudioAggregateDeviceUIDKey: "tools.ars.mute.host.\(UUID().uuidString)",
        kAudioAggregateDeviceIsPrivateKey: true,
        kAudioAggregateDeviceMainSubDeviceKey: outputUID,
        kAudioAggregateDeviceSubDeviceListKey: [[
            kAudioSubDeviceUIDKey: outputUID,
            kAudioSubDeviceInputChannelsKey: 0,
        ]],
        kAudioAggregateDeviceTapListKey: tapDescriptions.map { description in
            [kAudioSubTapUIDKey: description.uuid.uuidString]
        },
    ],
    taps: taps
)

let nodes = try await aggregate.nodes()
guard aggregate.inputStreams.count == aggregate.outputStreams.count else {
    throw Error(
        operation: "one-to-one stream pass-through",
        status: kAudioUnitErr_FormatNotSupported
    )
}

let engine = AVAudioEngine()
engine.attach(input: nodes.input, output: nodes.output)
for bus in aggregate.inputStreams.indices {
    let inputFormat = nodes.input.outputFormat(forBus: AVAudioNodeBus(bus))
    let outputFormat = nodes.output.inputFormat(forBus: AVAudioNodeBus(bus))
    guard inputFormat == outputFormat else {
        print("Input stream format:", inputFormat)
        print("Output stream format:", outputFormat)
        throw Error(
            operation: "direct stream format match",
            status: kAudioUnitErr_FormatNotSupported
        )
    }
    engine.connect(
        nodes.input,
        to: nodes.output,
        fromBus: AVAudioNodeBus(bus),
        toBus: AVAudioNodeBus(bus),
        format: inputFormat
    )
}

signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)

let termination = DispatchSemaphore(value: 0)
let signalSources = [SIGINT, SIGTERM].map { signal in
    let source = DispatchSource.makeSignalSource(
        signal: signal,
        queue: .global()
    )
    source.setEventHandler { @Sendable [termination] in
        termination.signal()
    }
    source.resume()
    return source
}

try engine.withIO(
    on: aggregate,
    input: nodes.input,
    output: nodes.output
) {
    print("HSP AVAudioEngine bridge is running.")
    for bus in aggregate.inputStreams.indices {
        print(
            "HAL input stream \(bus) -> engine -> HAL output stream \(bus):",
            nodes.input.outputFormat(forBus: AVAudioNodeBus(bus))
        )
    }
    print("Press Control-C to stop.")
    withExtendedLifetime(
        (aggregate, nodes, engine, signalSources),
        termination.wait
    )
}
