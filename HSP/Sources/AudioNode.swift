//
//  AudioNode.swift
//  MUTE
//

import AudioToolbox
import AVFoundation
import CoreAudio

extension AggregateStream {
    @usableFromInline
    func nodes() async throws -> (input: AVAudioUnit, output: AVAudioUnit) {
        let inputHardwareFormats = try inputStreams.map { try $0.virtualFormat }
        let outputHardwareFormats = try outputStreams.map { try $0.virtualFormat }
        let inputFormats = try inputHardwareFormats.map(audioUnitFormat)
        let outputFormats = try outputHardwareFormats.map(audioUnitFormat)
        let sampleRates = Set((inputFormats + outputFormats).map(\.sampleRate))
        guard !inputFormats.isEmpty,
              !outputFormats.isEmpty,
              sampleRates.count == 1,
              let sampleRate = sampleRates.first,
              let renderFormat = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: 1
              )
        else {
            throw Error(status: kAudioUnitErr_FormatNotSupported)
        }

        let inputDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Generator,
            componentSubType: fourCC("HSPi"),
            componentManufacturer: fourCC("@ars"),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let outputDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Mixer,
            componentSubType: fourCC("HSPo"),
            componentManufacturer: fourCC("@ars"),
            componentFlags: 0,
            componentFlagsMask: 0
        )
        AUAudioUnit.registerSubclass(
            InputAudioUnit.self,
            as: inputDescription,
            name: "MUTE HSP Input",
            version: 0
        )
        AUAudioUnit.registerSubclass(
            OutputAudioUnit.self,
            as: outputDescription,
            name: "MUTE HSP Output",
            version: 0
        )

        let cycle = IOCycle()
        let input = try await instantiate(
            inputDescription,
            operation: "instantiate aggregate input node"
        )
        let output = try await instantiate(
            outputDescription,
            operation: "instantiate aggregate output node"
        )
        guard let inputUnit = input.auAudioUnit as? InputAudioUnit,
              let outputUnit = output.auAudioUnit as? OutputAudioUnit
        else {
            throw Error(status: kAudioUnitErr_Uninitialized)
        }
        try inputUnit.configure(
            formats: inputFormats,
            hardwareFormats: inputHardwareFormats,
            context: cycle
        )
        try outputUnit.configure(
            inputFormats: outputFormats,
            hardwareFormats: outputHardwareFormats,
            outputFormat: renderFormat,
            context: cycle
        )

        let maximumFrameCount = AUAudioFrameCount(try device.maximumIOFrameCount)
        inputUnit.maximumFramesToRender = maximumFrameCount
        outputUnit.maximumFramesToRender = maximumFrameCount
        return (input, output)
    }
}

extension AVAudioEngine {
    @usableFromInline
    func attach(input: AVAudioUnit, output: AVAudioUnit) {
        attach(input)
        attach(output)
        connect(
            output,
            to: outputNode,
            fromBus: 0,
            toBus: 0,
            format: output.outputFormat(forBus: 0)
        )
    }

    @usableFromInline
    func withIO<Result>(
        on stream: AggregateStream,
        input: AVAudioUnit,
        output: AVAudioUnit,
        _ body: () throws -> Result
    ) throws -> Result {
        guard let inputUnit = input.auAudioUnit as? InputAudioUnit,
              let outputUnit = output.auAudioUnit as? OutputAudioUnit,
              let cycle = inputUnit.context,
              outputUnit.context === cycle,
              let inputFormat = inputUnit.hardwareFormats.first
        else {
            throw Error(status: kAudioUnitErr_Uninitialized)
        }

        let maximumFrameCount = try AVAudioFrameCount(stream.device.maximumIOFrameCount)
        let renderFormat = output.outputFormat(forBus: 0)
        guard let renderBuffer = AVAudioPCMBuffer(
            pcmFormat: renderFormat,
            frameCapacity: maximumFrameCount
        ) else {
            throw Error(status: kAudioUnitErr_FormatNotSupported)
        }

        do {
            try enableManualRenderingMode(
                .realtime,
                format: renderFormat,
                maximumFrameCount: maximumFrameCount
            )
        } catch let error as NSError {
            throw Error(
                operation: "enable AVAudioEngine realtime manual rendering",
                status: OSStatus(error.code)
            )
        }

        do {
            prepare()
            try start()
        } catch {
            stop()
            disableManualRenderingMode()
            throw error
        }

        let render = manualRenderingBlock
        let bytesPerFrame = inputFormat.mBytesPerFrame
        let ioProc: IOProc
        do {
            ioProc = try IOProc(stream: stream) { _, input, _, output, _ in
                let byteCount = input.pointee.mNumberBuffers == 0
                    ? 0
                    : input.pointee.mBuffers.mDataByteSize
                let frameCount = bytesPerFrame == 0
                    ? 0
                    : AVAudioFrameCount(byteCount / bytesPerFrame)
                guard input.pointee.mBuffers.mData != nil,
                      frameCount > 0,
                      frameCount <= maximumFrameCount
                else {
                    clear(output)
                    return
                }

                cycle.withBuffers(input: input, output: output) {
                    renderBuffer.frameLength = frameCount
                    var status = noErr
                    switch render(
                        frameCount,
                        renderBuffer.mutableAudioBufferList,
                        &status
                    ) {
                    case .success where status == noErr:
                        break
                    default:
                        clear(output)
                    }
                }
            }
        } catch {
            stop()
            disableManualRenderingMode()
            throw error
        }

        defer {
            try? ioProc.stop()
            stop()
            disableManualRenderingMode()
        }
        return try body()
    }
}

@usableFromInline
func clear(_ buffers: UnsafeMutablePointer<AudioBufferList>) {
    for buffer in UnsafeMutableAudioBufferListPointer(buffers) {
        guard let data = buffer.mData else { continue }
        data.initializeMemory(
            as: UInt8.self,
            repeating: 0,
            count: Int(buffer.mDataByteSize)
        )
    }
}

@usableFromInline
func audioUnitFormat(_ description: AudioStreamBasicDescription) throws -> AVAudioFormat {
    guard description.mFormatID == kAudioFormatLinearPCM,
          description.mFormatFlags & kAudioFormatFlagIsFloat != 0,
          description.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0,
          description.mBitsPerChannel == 32,
          let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: description.mSampleRate,
            channels: description.mChannelsPerFrame,
            interleaved: false
          )
    else {
        throw Error(status: kAudioUnitErr_FormatNotSupported)
    }
    return format
}

@usableFromInline
func instantiate(
    _ description: AudioComponentDescription,
    operation: String
) async throws -> AVAudioUnit {
    do {
        return try await AVAudioUnit.instantiate(
            with: description,
            options: .loadInProcess
        )
    } catch let error as NSError {
        throw Error(operation: operation, status: OSStatus(error.code))
    }
}

@usableFromInline
func fourCC(_ value: StaticString) -> OSType {
    precondition(value.utf8CodeUnitCount == 4)
    return value.withUTF8Buffer {
        $0.reduce(0) { ($0 << 8) | OSType($1) }
    }
}
