//
//  IO+Writer.swift
//  MUTE
//
//  Created by Kota on 7/16/R7.
//
@preconcurrency import func Foundation.autoreleasepool
@preconcurrency import typealias CoreMedia.CMTime
@preconcurrency import func CoreMedia.CMTimeMultiply
@preconcurrency import typealias Foundation.URL
@preconcurrency import typealias Foundation.NSError
@preconcurrency import typealias AVFoundation.AVAudioFramePosition
@preconcurrency import typealias AVFoundation.AVAudioCommonFormat
@preconcurrency import typealias AVFoundation.AVAudioFile
@preconcurrency import typealias AVFoundation.AVAudioConverter
@preconcurrency import typealias AVFoundation.AVAudioBuffer
@preconcurrency import typealias AVFoundation.AVAudioPacketCount
@preconcurrency import typealias AVFoundation.AVAudioConverterInputStatus
@preconcurrency import typealias AVFoundation.AudioBufferList
@preconcurrency import typealias AVFoundation.UnsafeMutableAudioBufferListPointer
import protocol DSP.Stream
import protocol DSP.Duration
import typealias DSP.Samples
import typealias DSP.Instance
extension AVAudioFile {
    @inlinable
	public func write(stream: DSP.Stream, for duration: Duration, process each: Duration) throws {
		assert(framePosition == 0)
		assert(processingFormat.commonFormat == .pcmFormatFloat64)
		var instance = Instance()
		let interval = CMTime(value: 1, timescale: .init(processingFormat.sampleRate))
		let capacity = each.samples(for: interval)
		let channels = Int(processingFormat.channelCount)
		let kernel = try stream(interval: interval, capacity: capacity, instance: &instance)
		let prefix = instance.prefix
		let suffix = instance.suffix
		let period = duration.samples(for: interval)
		try withUnsafeTemporaryAllocation(of: Float64.self, capacity: channels * capacity) {
			guard let memory = $0.baseAddress else {
				throw Error.pcmBufferNotAllocated
			}
			guard case.some(let target) = AVAudioPCMBuffer(pcmFormat: processingFormat, length: capacity, target: memory, stride: capacity) else {
				throw Error.pcmBufferNotAllocated
			}
			while isOpen, framePosition < .init(period) {
				let length = min(capacity, period - .init(framePosition))
				let moment = CMTimeMultiply(interval, multiplier: .init(framePosition))
				prefix(moment: moment, length: length)
				kernel(moment, length, memory, capacity)
				suffix()
				target.frameLength = .init(length)
				try write(from: target)
			}
		}
	}
}
