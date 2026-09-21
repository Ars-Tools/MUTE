//
//  StreamFormats.swift
//  MUTE
//

import CoreAudio
@usableFromInline
struct StreamFormats {
    @usableFromInline
    let input: [Int: AudioStreamBasicDescription]
    @usableFromInline
    let output: [Int: AudioStreamBasicDescription]
    @inlinable
    init(stream: AggregateStream, inputStreams: Set<Int>, outputStreams: Set<Int>) throws {
        let inputs = stream.inputStreams
        let outputs = stream.outputStreams
        guard inputStreams.allSatisfy(inputs.indices.contains),
              outputStreams.allSatisfy(outputs.indices.contains)
        else {
            throw Error(status: kAudio_ParamError)
        }
        input = try Dictionary(uniqueKeysWithValues: inputStreams.map {
            try ($0, inputs[$0].virtualFormat)
        })
        output = try Dictionary(uniqueKeysWithValues: outputStreams.map {
            try ($0, outputs[$0].virtualFormat)
        })
    }
}
