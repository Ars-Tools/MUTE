//
//  AUv3+Bus+Output.swift
//  MUTE
//
//  Created by Kota on 7/4/R7.
//
@preconcurrency import typealias Foundation.NSError
@preconcurrency import typealias AVFoundation.AVAudioFrameCount
@preconcurrency import typealias AVFoundation.AVAudioConverter
@preconcurrency import typealias AVFoundation.AVAudioConverterOutputStatus
@preconcurrency import typealias AVFoundation.AVAudioPCMBuffer
@preconcurrency import let AVFoundation.AVSampleRateConverterAlgorithm_Normal
@preconcurrency import let AVFoundation.AVSampleRateConverterAlgorithm_MinimumPhase
@preconcurrency import typealias AudioUnit.AUAudioUnitBus
@preconcurrency import typealias AudioUnit.AUAudioUnitStatus
@preconcurrency import typealias AudioUnit.UnsafeMutableAudioBufferListPointer
@preconcurrency import typealias AudioUnit.AURenderEvent
@preconcurrency import typealias AudioUnit.AUAudioFrameCount
@preconcurrency import typealias AudioUnit.AudioTimeStamp
@preconcurrency import typealias AudioUnit.AudioBufferList
@preconcurrency import typealias AudioUnit.AURenderPullInputBlock
@preconcurrency import let AudioUnit.kAudio_NoError
@preconcurrency import let AudioUnit.kAudioUnitErr_Uninitialized
@preconcurrency import let AudioUnit.kAudioUnitErr_Unauthorized
@preconcurrency import let AudioUnit.kAudioUnitErr_FormatNotSupported
@preconcurrency import let AudioUnit.kAudioUnitErr_TooManyFramesToProcess
@preconcurrency import let AudioUnit.kAudioUnitErr_CannotDoInCurrentContext
import typealias Accelerate.vDSP
import func Accelerate.cblas_dcopy
import func Accelerate.vDSP_vdpsp
import func Accelerate.vDSP_vfix32D
import func Accelerate.vDSP_vfix16D
import typealias CoreMedia.CMTime
import func CoreMedia.CMTimeMultiplyByFloat64
import protocol DSP.Stream
import typealias DSP.Instance
import typealias Numerics.Rational64
import os.log
public enum Output {
	protocol `Protocol`: AUAudioUnitBus, Sendable {
		func allocate() throws
		func deallocate()
		func callAsFunction(at: Float64, to: AVAudioFrameCount, of: UnsafeMutablePointer<AudioBufferList>) -> AUAudioUnitStatus
	}
	public final class Direct: AUAudioUnitBus, @unchecked Sendable {
		@usableFromInline let source: DSP.Stream
		@usableFromInline var system: Int
		@usableFromInline var kernel: @Sendable (Float64, Int, UnsafeMutableAudioBufferListPointer) -> AUAudioUnitStatus
		public init(sampleRate: Float64, source stream: DSP.Stream) throws {
			source = stream
			system = 0
			kernel = type(of: self).UninitializedKernel
			guard case.some(let format) = AVAudioFormat(sampleRate: sampleRate, discreteChannels: source.count) else {
				throw Error.unsupportedFormat
			}
			try super.init(format: format)
		}
	}
	public final class WithConverter: AUAudioUnitBus, @unchecked Sendable {
		@usableFromInline let source: DSP.Stream
		@usableFromInline let desire: Float64
		@usableFromInline var system: Int
		@usableFromInline var kernel: @Sendable (Float64, Int, UnsafeMutablePointer<AudioBufferList>) -> AUAudioUnitStatus
		public init(sampleRate: Float64, source stream: DSP.Stream) throws {
			source = stream
			system = 0
			kernel = type(of: self).UninitializedKernel
			desire = sampleRate
			switch AVAudioFormat(sampleRate: sampleRate, discreteChannels: source.count) {
			case.some(let format):
				try super.init(format: format)
			case.none:
				throw Error.unsupportedFormat
			}
		}
	}
}
extension Output.Direct {
	@usableFromInline
	static let UninitializedKernel = { _, _, _ in
		kAudioUnitErr_Uninitialized
	} as @Sendable (Float64, Int, UnsafeMutableAudioBufferListPointer) -> AUAudioUnitStatus
	@usableFromInline
	static let subsystem = OSLog(subsystem: String(describing: Output.Direct.self), category: .pointsOfInterest)
}
extension Output.Direct: Output.`Protocol` {
	@inlinable
	func allocate() throws {
		let interval = CMTime(value: 1, timescale: .init(format.sampleRate))
		let channels = Int(format.channelCount)
		let capacity = Int(ownerAudioUnit.maximumFramesToRender)
		var instance = [:] as DSP.Instance
		let source = try source(interval: interval, capacity: capacity, instance: &instance)
		let commit = instance.commit
		system = ownerAudioUnit.token { [index] in
			guard $3 == index else { return }
			switch $0 {
			case.unitRenderAction_PreRender:
				break
			case.unitRenderAction_PostRender:
                let moment = CMTimeMultiplyByFloat64(interval, multiplier: $1.pointee.mSampleTime)
                let length = Int($2)
                DispatchQueue.global(qos: .userInitiated).async {
                    commit(moment: moment, length: length)
                }
			default:
				break
			}
		}
		kernel = switch (format.commonFormat, format.isInterleaved) {
		case(.pcmFormatFloat64, false):
			{ cursor, length, target in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: channels * length) {
					guard let memory = $0.baseAddress else { return kAudioUnitErr_Unauthorized }
					source(CMTimeMultiplyByFloat64(interval, multiplier: cursor), length, memory, length)
					for (offset, target) in target.lazy.map(UnsafeMutableBufferPointer<Float64>.init).enumerated() where .init(length) == target.initialize(fromContentsOf: $0.dropFirst(offset * length).prefix(length)) {
						
					}
					return kAudio_NoError
				}
			}
		case(.pcmFormatFloat64, true):
			{ cursor, length, target in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: channels * length) {
					guard let memory = $0.baseAddress, let target = target.map(UnsafeMutableBufferPointer<Float64>.init).first.flatMap(\.baseAddress) else { return kAudioUnitErr_Unauthorized }
					source(CMTimeMultiplyByFloat64(interval, multiplier: cursor), length, memory, length)
					for offset in 0..<channels {
						cblas_dcopy(.init(length),
									memory.advanced(by: offset * length), 1,
									target.advanced(by: offset), channels)
					}
					return kAudio_NoError
				}
			}
		case(.pcmFormatFloat32, false):
			{ cursor, length, target in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: channels * length) {
					guard let memory = $0.baseAddress else { return kAudioUnitErr_Unauthorized }
					source(CMTimeMultiplyByFloat64(interval, multiplier: cursor), length, memory, length)
					for (offset, var target) in target.lazy.map(UnsafeMutableBufferPointer<Float32>.init).enumerated() {
						vDSP.convertElements(of: $0.dropFirst(offset * length).prefix(length), to: &target)
					}
					return kAudio_NoError
				}
			}
		case(.pcmFormatFloat32, true):
			{ cursor, length, target in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: channels * length) {
					guard let memory = $0.baseAddress, let target = target.map(UnsafeMutableBufferPointer<Float32>.init).first.flatMap(\.baseAddress) else { return kAudioUnitErr_Unauthorized }
					source(CMTimeMultiplyByFloat64(interval, multiplier: cursor), length, memory, length)
					for offset in 0..<channels {
						vDSP_vdpsp(memory.advanced(by: offset * length), 1,
								   target.advanced(by: offset), channels, .init(length))
					}
					return kAudio_NoError
				}
			}
		case(.pcmFormatInt32, false):
			{ cursor, length, target in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: channels * length) {
					guard let memory = $0.baseAddress else { return kAudioUnitErr_Unauthorized }
					source(CMTimeMultiplyByFloat64(interval, multiplier: cursor), length, memory, length)
					for (offset, var target) in target.lazy.map(UnsafeMutableBufferPointer<Int32>.init).enumerated() {
						vDSP.convertElements(of: $0.dropFirst(offset * length).prefix(length), to: &target, rounding: .towardNearestInteger)
					}
					return kAudio_NoError
				}
			}
		case(.pcmFormatInt32, true):
			{ cursor, length, target in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: channels * length) {
					guard let memory = $0.baseAddress, let target = target.map(UnsafeMutableBufferPointer<Int32>.init).first.flatMap(\.baseAddress) else { return kAudioUnitErr_Unauthorized }
					source(CMTimeMultiplyByFloat64(interval, multiplier: cursor), length, memory, length)
					for offset in 0..<channels {
						vDSP_vfix32D(memory.advanced(by: offset * length), 1,
									 target.advanced(by: offset), channels, .init(length))
					}
					return kAudio_NoError
				}
			}
		case(.pcmFormatInt16, false):
			{ cursor, length, target in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: channels * length) {
					guard let memory = $0.baseAddress else { return kAudioUnitErr_Unauthorized }
					source(CMTimeMultiplyByFloat64(interval, multiplier: cursor), length, memory, length)
					for (offset, var target) in target.lazy.map(UnsafeMutableBufferPointer<Int16>.init).enumerated() {
						vDSP.convertElements(of: $0.dropFirst(offset * length).prefix(length), to: &target, rounding: .towardNearestInteger)
					}
					return kAudio_NoError
				}
			}
		case(.pcmFormatInt16, true):
			{ cursor, length, target in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: channels * length) {
					guard let memory = $0.baseAddress, let target = target.map(UnsafeMutableBufferPointer<Int16>.init).first.flatMap(\.baseAddress) else { return kAudioUnitErr_Unauthorized }
					source(CMTimeMultiplyByFloat64(interval, multiplier: cursor), length, memory, length)
					for offset in 0..<channels {
						vDSP_vfix16D(memory.advanced(by: offset * length), 1,
									 target.advanced(by: offset), channels, .init(length))
					}
					return kAudio_NoError
				}
			}
		case(.otherFormat, false):
			throw Error.unsupportedFormat
		case(.otherFormat, true):
			throw Error.unsupportedFormat
		@unknown default:
			throw Error.unsupportedFormat
		}
	}
	@inlinable
	func deallocate() {
		kernel = type(of: self).UninitializedKernel
		ownerAudioUnit.removeRenderObserver(system)
	}
	@inlinable
	func callAsFunction(at moment: Float64, to length: AVAudioFrameCount, of buffer: UnsafeMutablePointer<AudioBufferList>) -> AUAudioUnitStatus {
		autoreleasepool {
			kernel(moment, .init(length), .init(buffer))
		}
	}
}
extension Output.WithConverter {
	@usableFromInline
	static let UninitializedKernel = { _, _, _ in
		kAudioUnitErr_Uninitialized
	} as @Sendable (Float64, Int, UnsafeMutablePointer<AudioBufferList>) -> AUAudioUnitStatus
	@usableFromInline
	static let subsystem = OSLog(subsystem: String(describing: Output.WithConverter.self), category: .pointsOfInterest)
}
extension Output.WithConverter: Output.`Protocol` {
	@inlinable
	func allocate() throws {
		let scheme = if case.some(let source) = AVAudioFormat(commonFormat: .pcmFormatFloat64, sampleRate: desire, discreteChannels: source.count, interleaved: false), case.some(let object) = AVAudioConverter(from: source, to: format) {
			object
		} else {
			throw Error.unsupportedFormat
		}
		let factor = scheme.inputFormat.sampleRate / scheme.outputFormat.sampleRate
		scheme.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_MinimumPhase
		let interval = switch Rational64(continuedFraction: scheme.inputFormat.sampleRate.continuedFractionSequence()) {
		case let ratio:
			CMTime(value: .init(ratio.denominator), timescale: ratio.numerator)
		}
		let capacity = Int(fma(factor, .init(ownerAudioUnit.maximumFramesToRender), 0.5))
		var instance = [:] as DSP.Instance
		let source = try source(interval: interval, capacity: capacity, instance: &instance)
		let commit = instance.commit
		let buffer = switch AVAudioPCMBuffer(pcmFormat: scheme.inputFormat,
											 length: capacity,
											 target: .allocate(capacity: .init(scheme.inputFormat.channelCount) * capacity) as UnsafeMutablePointer<Float64>,
											 stride: capacity,
											 deallocator: .some({$0.deallocate()})) {
		case.some(let buffer):
			buffer
		case.none:
			throw Error.unsupportedFormat
		}
		system = ownerAudioUnit.token { [index] in
			guard $3 == index else { return }
			switch $0 {
			case.unitRenderAction_PreRender:
				break
			case.unitRenderAction_PostRender:
                let moment = CMTimeMultiplyByFloat64(interval, multiplier: $1.pointee.mSampleTime)
                let length = Int($2)
                DispatchQueue.global(qos: .userInitiated).async {
                    commit(moment: moment, length: length)
                }
			default:
				break
			}
		}
		kernel = {
			guard case.some(let target) = AVAudioPCMBuffer(pcmFormat: scheme.outputFormat, bufferListNoCopy: $2, deallocator: .none) else {
				os_log(.error, log: type(of: self).subsystem, "Failed to allocation")
				return kAudioUnitErr_FormatNotSupported
			}
			let moment = CMTimeMultiplyByFloat64(interval, multiplier: $0 * factor).convertScale(.init(scheme.inputFormat.sampleRate), method: .roundTowardPositiveInfinity)
			var error: NSError?
			let status = scheme.convert(to: target, error: &error) {
				switch UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
					.lazy
					.map(UnsafeMutableBufferPointer<Float64>.init)
					.first
					.flatMap(\.baseAddress) {
				case.some(let memory):
					source(moment, .init($0), memory, capacity)
					buffer.frameLength = $0
					$1.pointee = .haveData
					return.some(buffer)
				case.none:
					$1.pointee = .noDataNow
					return.none
				}
			}
			let handle = if case.some = error {
				.error
			} else {
				status
			} as AVAudioConverterOutputStatus
			switch handle {
			case.haveData:
				return kAudio_NoError
			case.inputRanDry:
				os_log(.error, log: type(of: self).subsystem, "AVConverter Status: DRY")
				return kAudioUnitErr_TooManyFramesToProcess
			case.endOfStream:
				os_log(.error, log: type(of: self).subsystem, "AVConverter Status: EOF")
				return kAudioUnitErr_CannotDoInCurrentContext
			case.error:
				os_log(.error, log: type(of: self).subsystem, "AVConverter Status: ERR")
				return kAudioUnitErr_Unauthorized
			@unknown default:
				assertionFailure("not implemented for \(String(reflecting: handle))")
				return kAudioUnitErr_Unauthorized
			}
		}
	}
	@inlinable
	func deallocate() {
		kernel = type(of: self).UninitializedKernel
		ownerAudioUnit.removeRenderObserver(system)
	}
	@inlinable
	func callAsFunction(at moment: Float64, to length: AVAudioFrameCount, of buffer: UnsafeMutablePointer<AudioBufferList>) -> AUAudioUnitStatus {
		autoreleasepool {
			kernel(moment, .init(length), .init(buffer))
		}
	}
}
