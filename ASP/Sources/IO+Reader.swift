//
//  IO+Reader.swift
//  MUTE
//
//  Created by Kota on 7/16/R7.
//
@preconcurrency import typealias Foundation.URL
@preconcurrency import typealias Foundation.NSError
@preconcurrency import typealias AVFoundation.AVAudioFramePosition
@preconcurrency import typealias AVFoundation.AVAudioCommonFormat
@preconcurrency import typealias AVFoundation.AVAudioFile
@preconcurrency import typealias AVFoundation.AVAudioConverter
@preconcurrency import typealias AVFoundation.AVAudioBuffer
@preconcurrency import typealias AVFoundation.AVAudioPacketCount
@preconcurrency import typealias AVFoundation.AVAudioConverterInputStatus
@preconcurrency import typealias AVFoundation.UnsafeMutableAudioBufferListPointer
@preconcurrency import protocol Combine.Publisher
import typealias CoreMedia.CMTime
import func CoreMedia.CMTimeMultiplyByFloat64
import protocol DSP.Stream
import typealias DSP.Instance
import typealias Accelerate.vDSP
import func NSP.utility_clear
import os.log
public struct Playback: Sendable {
	@usableFromInline let rawValue: AVAudioFile
	@usableFromInline let infinite: Bool
}
extension Playback {
    @inlinable
	public init(path: URL, loop: Bool = true) throws {
		rawValue = try.init(forReading: path)
		infinite = loop
	}
}
extension Playback {
    @inlinable
	public var framePosition: some Publisher<AVAudioFramePosition, Never> {
		rawValue.publisher(for: \.framePosition, options: [.initial, .new])
	}
}
extension Playback {
    @usableFromInline
	static let subsystem = OSLog(subsystem: #file, category: .pointsOfInterest)
}
extension Playback: Stream {
    @inlinable
	public var count: Int {
		.init(rawValue.processingFormat.channelCount)
	}
    @inlinable
	public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let stream = Int(rawValue.processingFormat.channelCount)
		guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat64,
										 sampleRate: .init(interval.timescale) / .init(interval.value),
                                         discreteChannels: stream,
										 interleaved: false) else {
			throw Error.unsupportedFormat
		}
		guard let converter = AVAudioConverter(from: rawValue.processingFormat, to: format) else {
			throw Error.converterNotAllocated
		}
		let loader = if infinite {
			{
				switch AVAudioPCMBuffer(pcmFormat: rawValue.processingFormat, frameCapacity: $0) {
				case.some(let buffer):
					while rawValue.isOpen {
						do {
							try rawValue.read(into: buffer)
							$1.pointee = .haveData
							return.some(buffer)
						} catch {
							rawValue.framePosition = 0
							continue
						}
					}
					fallthrough
				case.none:
					$1.pointee = .endOfStream
					return.none
				}
			}
		} else {
			{
				switch AVAudioPCMBuffer(pcmFormat: rawValue.processingFormat, frameCapacity: $0) {
				case.some(let buffer) where rawValue.isOpen:
					do {
						try rawValue.read(into: buffer)
						$1.pointee = .haveData
						return.some(buffer)
					} catch {
						$1.pointee = .noDataNow
						return.none
					}
				case.some,.none:
					$1.pointee = .endOfStream
					return.none
				}
			}
		} as @Sendable (AVAudioPacketCount, UnsafeMutablePointer<AVAudioConverterInputStatus>) -> Optional<AVAudioBuffer>
		return {
			guard let target = AVAudioPCMBuffer(pcmFormat: format, length: $1, target: $2, stride: $3) else {
				return os_log(.error, log: type(of: self).subsystem, "AVAudioPCMBuffer Not Allocated")
			}
			var error: NSError?
			switch converter.convert(to: target, error: &error, withInputFrom: loader) {
			case.haveData:
				assert(target.frameLength == target.frameCapacity)
			case.error,.endOfStream:
				os_log(.error, log: type(of: self).subsystem, "no longer load signal")
				fallthrough
			case.inputRanDry:				
				utility_clear(stream, $1, $2, $3)
			@unknown default:
				break
			}
		}
	}
}
