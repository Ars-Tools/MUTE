//
//  AUv3+Bus+Input.swift
//  MUTE
//
//  Created by Kota on 7/4/R7.
//
@preconcurrency import typealias Foundation.NSError
@preconcurrency import typealias AudioUnit.AudioUnitRenderActionFlags
@preconcurrency import typealias AudioUnit.AudioTimeStamp
@preconcurrency import typealias AudioUnit.AudioBufferList
@preconcurrency import typealias AudioUnit.AUAudioUnitBus
@preconcurrency import typealias AVFoundation.AVAudioFrameCount
@preconcurrency import typealias AVFoundation.AVAudioPCMBuffer
@preconcurrency import typealias AVFoundation.AVAudioConverter
@preconcurrency import typealias AVFoundation.AVAudioConverterOutputStatus
@preconcurrency import let AVFoundation.AVSampleRateConverterAlgorithm_Normal
@preconcurrency import let AVFoundation.AVSampleRateConverterAlgorithm_MinimumPhase
@preconcurrency import typealias AudioUnit.AUAudioUnitStatus
@preconcurrency import typealias AudioUnit.AUAudioFrameCount
@preconcurrency import typealias AudioUnit.AURenderPullInputBlock
@preconcurrency import let AudioUnit.kAudio_NoError
@preconcurrency import let AudioUnit.kAudioUnitErr_FormatNotSupported
@preconcurrency import typealias Combine.Publishers
import typealias CoreMedia.CMTime
import protocol DSP.Stream
import typealias DSP.Instance
import typealias Synchronization.Mutex
import typealias Synchronization.Atomic
import typealias Synchronization.AtomicStoreOrdering
import typealias Accelerate.vDSP
import func CoreMedia.CMTimeMultiplyByFloat64
import func NSP.utility_clear
import os.log
public enum Input {
	protocol `Protocol`: AUAudioUnitBus {
		func allocate() throws
		func deallocate()
		func fetch(flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
				   stamp: UnsafePointer<AudioTimeStamp>,
				   count: AUAudioFrameCount,
				   block: @escaping AURenderPullInputBlock) -> AUAudioUnitStatus
	}
	public final class Direct: AUAudioUnitBus, @unchecked Sendable {
		@usableFromInline
		var buffer: AVAudioPCMBuffer
		@inlinable
		public init(sampleRate: Float64, target: Int) throws {
			buffer = .init()
			guard let format = AVAudioFormat(sampleRate: sampleRate, discreteChannels: target) else {
				throw Error.unsupportedFormat
			}
			try super.init(format: format)
		}
	}
	public final class WithConverter: AUAudioUnitBus, @unchecked Sendable {
		@usableFromInline
		var latest: (AudioUnitRenderActionFlags, AudioTimeStamp, AURenderPullInputBlock)
		@inlinable
		public init(sampleRate: Float64, target: Int) throws {
			guard let format = AVAudioFormat(sampleRate: sampleRate, discreteChannels: target) else {
				throw Error.unsupportedFormat
			}
			latest = (
				.init(),
				.init(),
				type(of: self).UninitializedRenderPullInputBlock
			)
			try super.init(format: format)
		}
	}
}
extension Input.Direct {
	@usableFromInline
	static let subsystem = OSLog(subsystem: String(describing: Input.Direct.self), category: .pointsOfInterest)
}
extension Input.Direct: Input.`Protocol` {
	@inlinable
	func allocate() throws {
		buffer = switch AVAudioPCMBuffer(pcmFormat: format, frameCapacity: ownerAudioUnit.maximumFramesToRender) {
		case.some(let buffer):
			buffer
		case.none:
			throw Error.unsupportedFormat
		}
	}
	@inlinable
	func deallocate() {
		buffer = .init()
	}
	@inlinable
	func fetch(flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
			   stamp: UnsafePointer<AudioTimeStamp>,
			   count: AUAudioFrameCount,
			   block: AURenderPullInputBlock) -> AUAudioUnitStatus {
		buffer.frameLength = count
		return block(flags, stamp, count, index, buffer.mutableAudioBufferList)
	}
}
extension Input.Direct: DSP.Stream {
	public var count: Int {
		.init(format.channelCount)
	}
	public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let status = Atomic<Bool>(false)
		let cancel = publisher(for: \.format, options: [.initial, .new]).map {
			CMTimeMultiplyByFloat64(interval, multiplier: $0.sampleRate) == 1
		}.sink {
			status.store($0, ordering: .releasing)
		}
		return { [unowned self] in
			let status = withExtendedLifetime(cancel) { status.load(ordering: .acquiring) }
			guard status else {
				utility_clear(.init(format.channelCount), $1, $2, $3)
				return os_log(.error, log: type(of: self).subsystem, "format changed")
			}
			buffer.copy(length: $1, target: $2, stride: $3)
		}
	}
}
extension Input.WithConverter {
	@usableFromInline
	static let subsystem = OSLog(subsystem: String(describing: Input.WithConverter.self), category: .pointsOfInterest)
	@usableFromInline
	nonisolated(unsafe) static let UninitializedRenderPullInputBlock: AURenderPullInputBlock = { _, _, _, _, _ in
		kAudioUnitErr_FormatNotSupported
	}
}
extension Input.WithConverter: Input.`Protocol` {
	@inlinable
	func allocate() throws {}
	@inlinable
	func deallocate() {}
	@inlinable
	func fetch(flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
					  stamp: UnsafePointer<AudioTimeStamp>,
					  count: AUAudioFrameCount,
					  block: @escaping AURenderPullInputBlock) -> AUAudioUnitStatus {
		latest = (flags.pointee, stamp.pointee, block)
		return kAudio_NoError
	}
}
extension Input.WithConverter: DSP.Stream {
	public var count: Int {
		.init(format.channelCount)
	}
	public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat64,
										 sampleRate: .init(interval.timescale) / .init(interval.value),
                                         discreteChannels: .init(format.channelCount),
										 interleaved: false) else {
			throw Error.unsupportedFormat
		}
		let syntax = Mutex<(AVAudioPCMBuffer, AVAudioConverter)>((.init(), .init()))
		let cancel = Publishers.CombineLatest(publisher(for: \.format, options: [.initial, .new]),
											  ownerAudioUnit.publisher(for: \.maximumFramesToRender, options: [.initial,.new]))
			.map { ($0, AVAudioFrameCount(fma(.init($1), $0.sampleRate / target.sampleRate, 0.5))) }
			.compactMap(AVAudioPCMBuffer.init(pcmFormat:frameCapacity:)).compactMap { source in
				AVAudioConverter(from: source.format, to: target).map { (source, $0) }
			}.sink { b, c in
				c.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_MinimumPhase
				syntax.withLock {
					$0 = (b, c)
				}
			}
		return {
			let (b, c) = withExtendedLifetime(cancel) { syntax.withLock(\.self) }
			guard let target = AVAudioPCMBuffer(pcmFormat: c.outputFormat, length: $1, target: $2, stride: $3) else {
				utility_clear(.init(c.outputFormat.channelCount), $1, $2, $3)
				return os_log(.error, log: type(of: self).subsystem, "no buffer allocated")
			}
			var e: NSError?
            let t = Atomic($0.convertScale(.init(c.inputFormat.sampleRate), method: .roundTowardPositiveInfinity).value)
			let factor = c.inputFormat.sampleRate / c.outputFormat.sampleRate
			let status = c.convert(to: target, error: &e) { [unowned self] in
                var a = AudioTimeStamp(mSampleTime: .init(t.add(.init($0), ordering: .acquiringAndReleasing).oldValue),
									   mHostTime: latest.1.mHostTime,
									   mRateScalar: latest.1.mRateScalar * factor,
									   mWordClockTime: latest.1.mWordClockTime,
									   mSMPTETime: latest.1.mSMPTETime,
									   mFlags: latest.1.mFlags,
									   mReserved: latest.1.mReserved)
				b.frameLength = $0
				switch latest.2(&latest.0, &a, $0, index, b.mutableAudioBufferList) {
				case kAudio_NoError:
					$1.pointee = .haveData
					return.some(b)
				default:
					$1.pointee = .noDataNow
					return.none
				}
			}
			let handle = if case.some = e {
				.error
			} else {
				status
			} as AVAudioConverterOutputStatus
			switch handle {
			case.haveData:
				break
			case.inputRanDry:
				os_log(.error, log: type(of: self).subsystem, "AVConverter Status: DRY")
			case.endOfStream:
				os_log(.error, log: type(of: self).subsystem, "AVConverter Status: EOF")
			case.error:
				os_log(.error, log: type(of: self).subsystem, "AVConverter Status: ERR")
			@unknown default:
				assertionFailure("not implemented for \(String(reflecting: handle))")
			}
		}
	}
}
