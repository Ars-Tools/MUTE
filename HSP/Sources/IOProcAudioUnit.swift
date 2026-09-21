//
//  IOProcAudioUnit.swift
//  MUTE
//

import AudioToolbox
import AVFoundation

@usableFromInline
final class IOCycle: @unchecked Sendable {
    @usableFromInline
    nonisolated(unsafe) var input: UnsafePointer<AudioBufferList>?
    @usableFromInline
    nonisolated(unsafe) var output: UnsafeMutablePointer<AudioBufferList>?

    @inlinable
    func withBuffers<Result>(
        input: UnsafePointer<AudioBufferList>,
        output: UnsafeMutablePointer<AudioBufferList>,
        _ body: () throws -> Result
    ) rethrows -> Result {
        self.input = input
        self.output = output
        defer {
            self.input = nil
            self.output = nil
        }
        return try body()
    }
}

@usableFromInline
final class InputAudioUnit: AUAudioUnit, @unchecked Sendable {
    @usableFromInline
    var buses: [AUAudioUnitBus] = []
    @usableFromInline
    var hardwareFormats: [AudioStreamBasicDescription] = []
    @usableFromInline
    var context: IOCycle?

    @usableFromInline
    override var outputBusses: AUAudioUnitBusArray {
        .init(audioUnit: self, busType: .output, busses: buses)
    }

    @usableFromInline
    override var internalRenderBlock: AUInternalRenderBlock {
        let buses = buses
        let hardwareFormats = hardwareFormats
        let context = context
        return { _, _, frameCount, outputBus, outputData, _, _ in
            guard buses.indices.contains(outputBus),
                  let input = context?.input,
                  input.pointee.mNumberBuffers > outputBus,
                  outputData.pointee.mNumberBuffers == buses[outputBus].format.channelCount
            else {
                return kAudioUnitErr_NoConnection
            }

            let source = UnsafeMutableAudioBufferListPointer(
                UnsafeMutablePointer(mutating: input)
            )[outputBus]
            let hardwareFormat = hardwareFormats[outputBus]
            let channels = Int(hardwareFormat.mChannelsPerFrame)
            let byteCount = Int(frameCount) * Int(hardwareFormat.mBytesPerFrame)
            guard source.mNumberChannels == channels,
                  source.mDataByteSize >= byteCount,
                  let sourceData = source.mData?.assumingMemoryBound(to: Float.self)
            else {
                return kAudioUnitErr_FormatNotSupported
            }
            for (channel, target) in UnsafeMutableAudioBufferListPointer(outputData).enumerated() {
                guard target.mNumberChannels == 1,
                      target.mDataByteSize >= Int(frameCount) * MemoryLayout<Float>.stride,
                      let targetData = target.mData?.assumingMemoryBound(to: Float.self)
                else {
                    return kAudioUnitErr_FormatNotSupported
                }
                for frame in 0..<Int(frameCount) {
                    targetData[frame] = sourceData[frame * channels + channel]
                }
            }
            return noErr
        }
    }

    @usableFromInline
    func configure(
        formats: [AVAudioFormat],
        hardwareFormats: [AudioStreamBasicDescription],
        context: IOCycle
    ) throws {
        guard !renderResourcesAllocated,
              buses.isEmpty,
              formats.count == hardwareFormats.count
        else {
            throw Error(status: kAudioUnitErr_CannotDoInCurrentContext)
        }
        self.context = context
        self.hardwareFormats = hardwareFormats
        buses = try formats.map(AUAudioUnitBus.init(format:))
    }
}

@usableFromInline
final class OutputAudioUnit: AUAudioUnit, @unchecked Sendable {
    @usableFromInline
    var inputs: [AUAudioUnitBus] = []
    @usableFromInline
    var outputs: [AUAudioUnitBus] = []
    @usableFromInline
    var hardwareFormats: [AudioStreamBasicDescription] = []
    @usableFromInline
    var buffers: [AVAudioPCMBuffer] = []
    @usableFromInline
    var context: IOCycle?

    @usableFromInline
    override var inputBusses: AUAudioUnitBusArray {
        .init(audioUnit: self, busType: .input, busses: inputs)
    }

    @usableFromInline
    override var outputBusses: AUAudioUnitBusArray {
        .init(audioUnit: self, busType: .output, busses: outputs)
    }

    @usableFromInline
    override var internalRenderBlock: AUInternalRenderBlock {
        let inputs = inputs
        let outputs = outputs
        let hardwareFormats = hardwareFormats
        let context = context
        return { [unowned self] actionFlags, timestamp, frameCount, outputBus, outputData, _, pullInput in
            guard outputBus == 0,
                  let output = context?.output,
                  output.pointee.mNumberBuffers >= inputs.count,
                  self.buffers.count == inputs.count,
                  let pullInput
            else {
                return kAudioUnitErr_NoConnection
            }

            for inputBus in inputs.indices {
                let buffer = self.buffers[inputBus]
                buffer.frameLength = frameCount
                switch pullInput(
                    actionFlags,
                    timestamp,
                    frameCount,
                    inputBus,
                    buffer.mutableAudioBufferList
                ) {
                case noErr:
                    break
                case let status:
                    return status
                }

                let hardwareFormat = hardwareFormats[inputBus]
                let channels = Int(hardwareFormat.mChannelsPerFrame)
                let byteCount = Int(frameCount) * Int(hardwareFormat.mBytesPerFrame)
                let target = UnsafeMutableAudioBufferListPointer(output)[inputBus]
                guard target.mNumberChannels == channels,
                      target.mDataByteSize >= byteCount,
                      let targetData = target.mData?.assumingMemoryBound(to: Float.self),
                      let sourceData = buffer.floatChannelData
                else {
                    return kAudioUnitErr_FormatNotSupported
                }
                for channel in 0..<channels {
                    let source = sourceData[channel]
                    for frame in 0..<Int(frameCount) {
                        targetData[frame * channels + channel] = source[frame]
                    }
                }
            }

            for var buffer in UnsafeMutableAudioBufferListPointer(outputData) {
                guard let data = buffer.mData else { continue }
                data.initializeMemory(as: UInt8.self, repeating: 0, count: Int(buffer.mDataByteSize))
                buffer.mDataByteSize = UInt32(Int(frameCount) * Int(outputs[0].format.streamDescription.pointee.mBytesPerFrame))
            }
            actionFlags.pointee.insert(.unitRenderAction_OutputIsSilence)
            return noErr
        }
    }

    @usableFromInline
    func configure(
        inputFormats: [AVAudioFormat],
        hardwareFormats: [AudioStreamBasicDescription],
        outputFormat: AVAudioFormat,
        context: IOCycle
    ) throws {
        guard !renderResourcesAllocated,
              inputs.isEmpty,
              outputs.isEmpty,
              inputFormats.count == hardwareFormats.count
        else {
            throw Error(status: kAudioUnitErr_CannotDoInCurrentContext)
        }
        self.context = context
        self.hardwareFormats = hardwareFormats
        inputs = try inputFormats.map(AUAudioUnitBus.init(format:))
        outputs = [try AUAudioUnitBus(format: outputFormat)]
    }

    @usableFromInline
    override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        buffers = try inputs.map {
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: $0.format,
                frameCapacity: maximumFramesToRender
            ) else {
                throw Error(status: kAudioUnitErr_FormatNotSupported)
            }
            return buffer
        }
    }

    @usableFromInline
    override func deallocateRenderResources() {
        buffers.removeAll(keepingCapacity: true)
        super.deallocateRenderResources()
    }
}
