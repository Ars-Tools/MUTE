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

import ASP
import BSP
import DSP
import FSP
let efxDescription = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                    componentSubType: .init(four: "$hsp"),
                                    componentManufacturer: .init(four: "@ars"),
                                    componentFlags: 0,
                                    componentFlagsMask: 0)
AUAudioUnit.registerSubclass(Universal.self, as: efxDescription, name: "Effector", version: 0)

let outputDevice = try SystemObject.outputDevice
let outputUID = try outputDevice.uuid
let physicalOutputStreams = try outputDevice.streams(
    scope: kAudioObjectPropertyScopeOutput
)

let tapDescription = physicalOutputStreams.indices.map { stream in
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
let taps = try tapDescription.map(Tap.init(description:))

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
        kAudioAggregateDeviceTapListKey: tapDescription.map { description in
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
    let sampleRate = inputFormat.sampleRate
    let efx = try await AVAudioUnit.instantiate(with: efxDescription, options: .loadInProcess)
    engine.attach(efx)
    switch efx.auAudioUnit {
    case let unit as Universal:
        let i = try Input.Direct(sampleRate: sampleRate, target: 2)
        let x = i
        let y = pitchshift(x, rate: 1.2)
//        let z = buffer(filter(residual(target: x, rls: 21, λ: 0.9998), ldf: 220, chebyshev1: 4000, ε: Utils.ripple(dB: 3)), capacity: 3)[t-0.1]
        let t = filter(x[0..<1], lpf: 12000, bessel: 12)
        let w = kernel(target: t, rls: 12, λ: 0.9997)
        let u = uniform(in: -0.01 ... 0.01, -0.01 ... 0.01)
        let s = residual(target: x, var: 28, λ: 0.9996)
        let o = try Output.Direct(sampleRate: sampleRate, source: 0.5 * clip(x + 0.5 * buffer(y)[t-0.2], range: -1...1))
        unit.append(i)
        unit.append(o)
    default:
        throw Error(operation: "efx binding", status: kAudioUnitErr_FormatNotSupported)
    }
    engine.connect(nodes.input, to: efx, fromBus: .init(bus), toBus: .init(bus), format: .some(inputFormat))
    engine.connect(efx, to: nodes.output, fromBus: .init(bus), toBus: .init(bus), format: .some(outputFormat))
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
