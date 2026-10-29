//
//  main.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//

#if !os(macOS)
#error("HSP requires native macOS Core Audio HAL.")
#endif
import AppKit
import AVFoundation
import CoreAudio
import Foundation
import Combine
import CLK
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

let text = try CMTimebase(sourceClock: CMClockGetHostTimeClock())
try text.set(rate: 1)
let proxy = PassthroughSubject<String, Never>()
Task {
    for try await tick in text.tick(every: .init(duration: .seconds(3))) {
        proxy.send("hello")
    }
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
        let x = i//tts(text: "Hello World")
        //buffer(i)
        assert(x.count == 2)
//        let y = filter(x, apf: fma(tri(freqs: 0.6, ratio: 0.1), 4000, 4200), butterworth: 300)
        let z = buffer(fma(
            sin(freqs: 0.20, 0.21, 0.22, 0.23, 0.24, 0.25, 0.26, 0.27, 0.28),
            const(150, 200, 350, 550,  900, 1450, 2350, 3800, 6150),
            const(200, 300, 500, 800, 1300, 2100, 3400, 5500, 8900)
        ))
        let (w, r) = buffer(2, capacity: 6)
        let k = pitchshift(filter(r[t - 0.28], lpf: 4000, bessel: 6), rate: 0.9) //p.depends(on: w)
        let p = 0.5 * x + 0.2 * filter(k, apf: 700, butterworth: 2000)
//        let p = x + 0.92  * filter(r[t - fma(sin(freqs: 1 / 6.0), 0.001, 0.28)], hdf: 300, chebyshev1: 4200, ε: Parameter.ripple(dB: 3))
        
        w.source = p
        let y = p.depends(on: w)
//        let p = x + 0.9 * filter(r[t - 0.3], hdf: 140, chebyshev1: 5000, ε: Utils.ripple(dB: 6))
        
        
        
//        let y = filter(x, sos: [
//            Filter.Cascade.Ar.Section.peq(ω₀: z[2..<3], Q: 1.5.squareRoot(), dB: const(6)),
//            Filter.Cascade.Ar.Section.peq(ω₀: z[3..<4], Q: 1.5.squareRoot(), dB: const(6)),
//            Filter.Cascade.Ar.Section.peq(ω₀: z[4..<5], Q: 1.5.squareRoot(), dB: const(6)),
//            Filter.Cascade.Ar.Section.peq(ω₀: z[5..<6], Q: 1.5.squareRoot(), dB: const(6)),
//            Filter.Cascade.Ar.Section.peq(ω₀: z[6..<7], Q: 1.5.squareRoot(), dB: const(6)),
//            Filter.Cascade.Ar.Section.peq(ω₀: z[7..<8], Q: 1.5.squareRoot(), dB: const(6))
//        ])
//        let y = filter(x, sos: .lsf(ω₀: 400, Q: 0.5.squareRoot(), dB: -6))
//        let xof = filter(x[0..<1], xof: 200, 400, 800, 1600, 3200, 6400, 12800)//p.depends(on: w)
//        let y = mix(xof, weight: [
//            [1, 0, 0, 1, 0, 0, 0, 0]
//        ])
//        let osc = pulse(freqs: 1)
//        let y = filter(x, apf: (0.1, 0.98))
        
//            filter(l, apf: 400, butterworth: 3000),
//            filter(r, apf: 400, butterworth: 3000)
//        )
//        let z = buffer(x, capacity: 600)
//        let y = filter(x, lpf: fma(phasor(freqs: 0.01), 5800, 200), cauer: 24, ε: Utils.ripple(dB: 6), η: Utils.ripple(dB: 60))
//        let y = filter(x, lpf: fma(tri(freqs: 1, ratio: 0.1), 5000, 5200), cauer: 50, ε: Utils.ripple(dB: 1), η: Utils.ripple(dB: 60))
//        let y = filter(x, lpf: 324, chebyshev1: 3, ε: Utils.ripple(dB: 1))
//        let y = filter(x, lpf: 324, butterworth: 3)
//        let y = pitchshift(x, rate: 1.2)
////        let z = buffer(filter(residual(target: x, rls: 21, λ: 0.9998), ldf: 220, chebyshev1: 4000, ε: Utils.ripple(dB: 3)), capacity: 3)[t-0.1]
//        let t = filter(x[0..<1], lpf: 12000, bessel: 12)
//        let w = kernel(target: t, rls: 12, λ: 0.9997)
//        let u = uniform(in: -0.01 ... 0.01, -0.01 ... 0.01)
//        let s = residual(target: x, var: 28, λ: 0.9996)
        let o = try Output.Direct(sampleRate: sampleRate, source: y)// clip(y, range: -1...1))
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
