//
//  IO+Buffer.swift
//  MUTE
//
//  Created by Kota on 7/16/R7.
//
@preconcurrency import typealias AVFoundation.AVAudioFile
@preconcurrency import typealias AVFoundation.AVAudioPCMBuffer
@preconcurrency import typealias AVFoundation.AVAudioCommonFormat
@preconcurrency import typealias AVFoundation.AVAudioConverter
@preconcurrency import typealias AVFoundation.AudioBufferList
@preconcurrency import typealias AVFoundation.AVAudioConverterInputStatus
@preconcurrency import typealias AVFoundation.AVAudioConverterOutputStatus
@preconcurrency import typealias AVFoundation.AVAudioQuality
@preconcurrency import let AVFoundation.AVSampleRateConverterAlgorithm_Mastering
@preconcurrency import typealias Foundation.URL
@preconcurrency import typealias Foundation.NSError
import typealias DSP.Buffer
import typealias Synchronization.Atomic
import protocol Numerics.RationalNumber
import os.log
extension Buffer {
    @inlinable@_transparent
	public func withUnsafeAudioBuffer<R>(body: (UnsafePointer<AudioBufferList>) throws -> R) rethrows -> R {
		let buffer = AudioBufferList.allocate(maximumBuffers: stream)
		defer {
			buffer.unsafePointer.deallocate()
		}
        for (offset, cursor) in stride(from: start, to: start.advanced(by: stream * period), by: period).enumerated() {
            buffer[offset] = .init(.init(start: cursor, count: period), numberOfChannels: 1)
        }
		return try body(buffer.unsafePointer)
	}
    @inlinable@_transparent
	public func withUnsafeMutableAudioBuffer<R>(body: (UnsafeMutablePointer<AudioBufferList>) throws -> R) rethrows -> R {
		let buffer = AudioBufferList.allocate(maximumBuffers: stream)
		defer {
			buffer.unsafePointer.deallocate()
		}
        for (offset, cursor) in stride(from: start, to: start.advanced(by: stream * period), by: period).enumerated() {
            buffer[offset] = .init(.init(start: cursor, count: period), numberOfChannels: 1)
        }
		return try body(buffer.unsafeMutablePointer)
	}
}
extension Buffer {
    @inlinable
    public static func Import(from path: URL, backing: Optional<String> = .none) throws -> (Float64, Buffer) {
        let loader = try AVAudioFile(forReading: path, commonFormat: .pcmFormatFloat64, interleaved: false)
        let format = loader.processingFormat
        let buffer = switch backing {
        case.some(let storage):
            try Buffer(stream: .init(format.channelCount), period: .init(loader.length), backing: storage, release: true)
        case.none:
            Buffer(stream: .init(format.channelCount), period: .init(loader.length))
        }
        try buffer.withUnsafeMutableAudioBuffer {
            switch AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: $0, deallocator: .none) {
            case.some(let target):
                try loader.read(into: target, frameCount: target.frameLength)
            case.none:
                throw Error.unsupportedFormat
            }
        }
        return (format.sampleRate, buffer)
    }
    @inlinable
    public static func Export(into path: URL, rate: Float64, data: Buffer) throws {
        try data.withUnsafeAudioBuffer {
            guard
                case.some(let format) = AVAudioFormat(commonFormat: .pcmFormatFloat64, sampleRate: rate, discreteChannels: data.stream, interleaved: false),
                case.some(let buffer) = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: $0, deallocator: .none) else {
                throw Error.unsupportedFormat
            }
            try AVAudioFile(forWriting: path, settings: format.settings, commonFormat: .pcmFormatFloat64, interleaved: false).write(from: buffer)
        }
    }
}
extension Buffer {
    @discardableResult
    @inlinable
    public func resample(ratio: some RationalNumber<some BinaryInteger>, to target: Buffer) throws -> Bool {
        guard
            case.some(let input) = AVAudioFormat(commonFormat: .pcmFormatFloat64, sampleRate: .init(ratio.denominator), discreteChannels: stream, interleaved: false),
            case.some(let output) = AVAudioFormat(commonFormat: .pcmFormatFloat64, sampleRate: .init(ratio.numerator), discreteChannels: target.stream, interleaved: false),
            case.some(let target) = AVAudioPCMBuffer(pcmFormat: output, length: target.period, target: target.start, stride: target.period, deallocator: .none),
            case.some(let converter) = AVAudioConverter(from: input, to: output) else {
            throw Error.unsupportedFormat
        }
        converter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
        converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue
        var error: NSError?
        let cursor = Atomic<Int>(0)
        let status = converter.convert(to: target, error: &error) {
            let range = switch cursor.add(.init($0), ordering: .acquiring) {
            case(let old, let new):
                Swift.min(old, period)..<Swift.min(new, period)
            }
            switch range.isEmpty ? .none : AVAudioPCMBuffer(pcmFormat: input, length: range.count, target: start.advanced(by: range.lowerBound), stride: period) {
            case.some(let source):
                source.frameLength = .init(range.count)
                $1.pointee = .haveData
                return.some(source)
            case.none:
                $1.pointee = .endOfStream
                return.none
            }
        }
        if case.some(let error) = error {
            os_log(.error, log: .default, "%{public}@", String(describing: error))
            return false
        } else {
            return switch status {
            case.haveData:
                false
            case.inputRanDry:
                false
            case.endOfStream:
                true
            case.error:
                false
            @unknown default:
                false
            }
        }
    }
}
//extension Buffer {
//	@usableFromInline
//	final class AVAsset: Identifiable, Sendable, RawRepresentable {
//		@usableFromInline let rawValue: AVAudioFile
//		@inlinable
//		init(rawValue: AVAudioFile) {
//			self.rawValue = rawValue
//		}
//	}
//}
//extension Buffer.AVAsset {
//	@usableFromInline
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> Buffer {
//		switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
//		case.some(let buffer as Buffer):
//			return buffer
//		case.some:
//			throw Error.resourceConflict
//		case.none:
//			guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat64,
//											 sampleRate: .init(interval.timescale) / .init(interval.value),
//											 channels: rawValue.processingFormat.channelCount,
//											 interleaved: false) else {
//				throw Error.unsupportedFormat
//			}
//			guard let converter = AVAudioConverter(from: rawValue.processingFormat, to: format) else {
//				throw Error.failedToAllocate(AVAudioConverter.self)
//			}
//			let period = Int((Float64(rawValue.length) * format.sampleRate / rawValue.processingFormat.sampleRate).rounded(.up))
//			let target = Buffer(stream: .init(rawValue.processingFormat.channelCount), period: period)
//			var error: NSError?
//			assert(rawValue.isOpen)
//			rawValue.framePosition = 0
//			let status = target.withUnsafeAudioBuffer {
//				switch AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: $0, deallocator: .none) {
//				case.some(let buffer):
//					converter.convert(to: buffer, error: &error) { [unowned self] in
//						switch AVAudioPCMBuffer(pcmFormat: rawValue.processingFormat, frameCapacity: $0) {
//						case.some(let memory):
//							do {
//								try rawValue.read(into: memory)
//								$1.pointee = .haveData
//								return.some(memory)
//							} catch {
//								$1.pointee = .endOfStream
//								return.none
//							}
//						case.none:
//							$1.pointee = .noDataNow
//							return.none
//						}
//					}
//				case.none:
//					.error
//				} as AVAudioConverterOutputStatus
//			}
//			if let error {
//				throw error
//			} else {
//				switch status {
//				case.error:
//					throw Error.failedToAllocate(Buffer.self)
//				default:
//					break
//				}
//			}
//			return target
//		}
//	}
//}
//extension Buffer.AVAsset: Buffer.`Protocol` {
//	@inlinable
//	var count: Int {
//		.init(rawValue.processingFormat.channelCount)
//	}
//	@inlinable
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
//		let buffer = try callAsFunction(interval: interval, capacity: capacity, instance: &instance) as Buffer
//		return { moment, length in buffer }
//	}
//}
//extension Buffer.AVAsset: Stream {
//	@inlinable @inline(__always)
//	public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//		let buffer = try callAsFunction(interval: interval, capacity: capacity, instance: &instance) as Buffer
//		return try buffer.callAsFunction(interval: interval, capacity: capacity, instance: &instance)
//	}
//}
//public func buffer(asset url: URL) throws -> some Buffer.`Protocol` & Stream {
//	try Buffer.AVAsset(rawValue: .init(forReading: url))
//}
//
