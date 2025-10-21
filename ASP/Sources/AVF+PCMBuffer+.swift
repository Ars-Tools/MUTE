//
//  AVF+PCMBuffer+.swift
//  MUTE
//
//  Created by Kota on 7/16/R7.
//
@_exported @preconcurrency import typealias AVFoundation.AVAudioPCMBuffer
@preconcurrency import typealias AVFoundation.AudioBufferList
@preconcurrency import typealias CoreAudio.UnsafeMutableAudioBufferListPointer
import func Accelerate.vecLib.cblas_dcopy
import func Accelerate.vecLib.vDSP_vspdp
import func Accelerate.vecLib.vDSP_vflt32D
import func Accelerate.vecLib.vDSP_vflt16D
import protocol DSP.Stream
extension AVAudioPCMBuffer {
	// target memory should be held while AVAudioPCMBuffer is alive
	public convenience init?(pcmFormat format: AVAudioFormat, length: Int, target: UnsafeMutablePointer<Float64>, stride: Int, deallocator: Optional<(UnsafeMutablePointer<Float64>) -> Void> = .none) {
		assert(format.commonFormat == .pcmFormatFloat64)
		let buffer = AudioBufferList.allocate(maximumBuffers: .init(format.channelCount))
		defer {
			buffer.unsafePointer.deallocate()
		}
        for (offset, cursor) in Swift.stride(from: target, to: target.advanced(by: Int(format.channelCount) * stride), by: stride).enumerated() {
            buffer[offset] = .init(.init(start: cursor, count: length), numberOfChannels: 1)
		}
		self.init(pcmFormat: format, bufferListNoCopy: buffer.unsafePointer, deallocator: deallocator.map { deallocator in
			{
				UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: $0))
					.lazy
					.map(UnsafeMutableBufferPointer<Float64>.init)
					.first
					.flatMap(\.baseAddress)
					.map(deallocator)
			}
		})
	}
	public convenience init?(pcmFormat format: AVAudioFormat, length: Int, target: UnsafeMutableBufferPointer<Float64>, stride: Int, deallocator: Optional<(UnsafeMutableBufferPointer<Float64>) -> Void> = .none) {
		assert(format.commonFormat == .pcmFormatFloat64)
		let buffer = AudioBufferList.allocate(maximumBuffers: .init(format.channelCount))
		defer {
			buffer.unsafePointer.deallocate()
		}
		for (offset, cursor) in Swift.stride(from: 0, to: Int(format.channelCount) * stride, by: stride).enumerated() {
			buffer[offset] = .init(target.extracting(cursor..<cursor+length), numberOfChannels: 1)
		}
		self.init(pcmFormat: format, bufferListNoCopy: buffer.unsafePointer, deallocator: deallocator.map { deallocator in
			{
				UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: $0))
					.lazy
					.map(UnsafeMutableBufferPointer<Float64>.init)
					.first
					.map(deallocator)
			}
		})
	}
}
extension AVAudioPCMBuffer {
	@inlinable
	var f64: some Sequence<UnsafeMutablePointer<Float64>> {
		UnsafeMutableAudioBufferListPointer(mutableAudioBufferList)
			.map(UnsafeMutableBufferPointer<Float64>.init)
			.compactMap(\.baseAddress)
			.flatMap { (0..<stride).lazy.map($0.advanced(by:)) }
	}
	@inlinable
	var f32: some Sequence<UnsafeMutablePointer<Float32>> {
		repeatElement(floatChannelData, count: .init(format.channelCount)).enumerated().compactMap { $1?[$0] }
	}
	@inlinable
	var i32: some Sequence<UnsafeMutablePointer<Int32>> {
		repeatElement(int32ChannelData, count: .init(format.channelCount)).enumerated().compactMap { $1?[$0] }
	}
	@inlinable
	var i16: some Sequence<UnsafeMutablePointer<Int16>> {
		repeatElement(int16ChannelData, count: .init(format.channelCount)).enumerated().compactMap { $1?[$0] }
	}
}
extension AVAudioPCMBuffer {
	@inlinable
	public func copy(length: Int, target: UnsafeMutablePointer<Float64>, stride period: Int) {
		switch format.commonFormat {
		case.pcmFormatFloat64:
			assert(length <= .init(frameLength))
			for (source, target) in zip(f64, sequence(first: 0, next: period.advanced(by:)).lazy.map(target.advanced(by:))) {
				cblas_dcopy(.init(length), source, stride, target, 1)
			}
		case.pcmFormatFloat32:
			assert(length <= .init(frameLength))
			for (source, target) in zip(f32, sequence(first: 0, next: period.advanced(by:)).lazy.map(target.advanced(by:))) {
				vDSP_vspdp(source, stride, target, 1, .init(length))
			}
		case.pcmFormatInt32:
			assert(length <= .init(frameLength))
			for (source, target) in zip(i32, sequence(first: 0, next: period.advanced(by:)).lazy.map(target.advanced(by:))) {
				vDSP_vflt32D(source, stride, target, 1, .init(length))
			}
		case.pcmFormatInt16:
			assert(length <= .init(frameLength))
			for (source, target) in zip(i16, sequence(first: 0, next: period.advanced(by:)).lazy.map(target.advanced(by:))) {
				vDSP_vflt16D(source, stride, target, 1, .init(length))
			}
		case.otherFormat:
			assertionFailure()
		@unknown default:
			break
		}
	}
}
