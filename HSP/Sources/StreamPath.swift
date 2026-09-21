//
//  StreamPath.swift
//  MUTE
//

import CoreAudio

typealias StreamPath = (
    input: Set<Int>,
    output: Set<Int>,
    ioproc: AudioDeviceIOBlock
)

enum StreamPathError: Swift.Error, CustomStringConvertible {
    case negativeInput(Int)
    case negativeOutput(Int)
    case overlappingOutput(Int)

    var description: String {
        switch self {
        case let .negativeInput(stream):
            "input stream \(stream) is negative"
        case let .negativeOutput(stream):
            "output stream \(stream) is negative"
        case let .overlappingOutput(stream):
            "output stream \(stream) is assigned to more than one IOProc"
        }
    }
}

extension Array where Element == StreamPath {
    func validate() throws {
        var outputs: Set<Int> = []
        for path in self {
            if let stream = path.input.first(where: { $0 < 0 }) {
                throw StreamPathError.negativeInput(stream)
            }
            if let stream = path.output.first(where: { $0 < 0 }) {
                throw StreamPathError.negativeOutput(stream)
            }
            if let stream = path.output.first(where: { outputs.contains($0) }) {
                throw StreamPathError.overlappingOutput(stream)
            }
            outputs.formUnion(path.output)
        }
    }
}
