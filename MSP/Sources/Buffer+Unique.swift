//
//  Buffer+Unique.swift
//  MUTE
//
//  Created by Kota on 5/23/R7.
//
@preconcurrency import AVFoundation
extension Buffer {
	@usableFromInline
	struct Kr {
		@usableFromInline
		let count: Int
		@usableFromInline
		let synth: @Sendable (Int, CMTime) throws -> Object
	}
}
extension Array<Array<Float64>>: Stream & Buffer.Instance {
	@inlinable
	public func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> (Buffer.Object, Ground) {
		let object = Buffer.Object(stream: count, period: map(\.count).max() ?? 1)
		object.withUnsafeMutablePointer {
			for (i, v) in enumerated() {
				let target = UnsafeMutableBufferPointer(start: $0.advanced(by: i * object.period), count: object.period)
				target[target.initialize(fromContentsOf: v)...].initialize(repeating: .zero)
			}
		}
		return (object, { .init(repeating: .zero, count: $1) })
	}
}
extension Buffer.Kr: Buffer.Instance {
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> (Buffer.Object, Ground) {
		switch try synth(count, interval) {
		case let object where object.stream == count:
			(object, { .init(repeating: .zero, count: $1) })
		default:
			throw Error.unmatchChannel
		}
	}
}
extension AVAudioFile: Buffer.Instance, @unchecked @retroactive Sendable {
	public var count: Int {
		.init(processingFormat.channelCount)
	}
	public func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> (Buffer.Object, Ground) {
		guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat64,
										 sampleRate: .init(interval.timescale) / .init(interval.value),
										 channels: processingFormat.channelCount,
										 interleaved: false) else {
			throw Error.notImplemented
		}
		guard let converter = AVAudioConverter(from: processingFormat, to: format) else {
			throw Error.notImplemented
		}
		let period = Int((Float64(length) * processingFormat.sampleRate * interval.seconds).rounded(.up))
		let object = Buffer.Object(stream: .init(processingFormat.channelCount), period: period)
		var `catch`: NSError?
		let status = object.withUnsafeMutablePointer {
			let abl = AudioBufferList.allocate(maximumBuffers: object.stream)
			defer {
				abl.unsafePointer.deallocate()
			}
			for (offset, element) in abl.indices.enumerated() {
				abl[element] = .init(.init(start: $0.advanced(by: offset * period), count: period), numberOfChannels: 1)
			}
			let pos = framePosition
			defer {
				framePosition = pos
			}
			framePosition = .zero
			return switch AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: abl.unsafePointer, deallocator: .none) {
			case.some(let buffer):
				converter.convert(to: buffer, error: &`catch`) { [unowned self] in
					switch AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: .init($0)) {
					case.some(let buffer):
						do {
							try read(into: buffer, frameCount: $0)
							$1.pointee = .haveData
							return.some(buffer)
						} catch {
							$1.pointee = .endOfStream
							return.none
						}
					case.none:
						$1.pointee = .noDataNow
						return.none
					}
				}
			case.none:
				.error
			} as AVAudioConverterOutputStatus
		}
		switch status {
		case.error:
			throw Error.noBufferAssigned
		default:
			switch `catch` {
			case.some(let error):
				throw error
			case.none:
				return (object, { .init(repeating: .zero, count: $1) })
			}
		}
	}
}
public func buffer(count: Int, synth: @escaping@Sendable(Int, CMTime) throws -> Buffer.Object) -> some Buffer.Instance {
	Buffer.Kr(count: count, synth: synth)
}
