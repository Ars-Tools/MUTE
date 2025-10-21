//
//  AVF+PCMBuffer.swift
//  MUTE
//
//  Created by Kota on 7/6/R7.
//
@preconcurrency import typealias AVFoundation.AVAudioPCMBuffer
import typealias CoreAudio.UnsafeMutableAudioBufferListPointer
import func CoreMedia.CMTimeMultiplyByFloat64
import func CoreMedia.CMTimeCompare
import func Accelerate.vecLib.cblas_dcopy
import func Accelerate.vecLib.vDSP_vspdp
import func Accelerate.vecLib.vDSP_vflt32D
import func Accelerate.vecLib.vDSP_vflt16D
extension AVAudioPCMBuffer: @retroactive @unchecked Sendable {
	@inlinable
	public func copy(count: Int, target: UnsafeMutablePointer<Float64>, leading: Int) {
		switch format.commonFormat {
		case.pcmFormatFloat64:
			let buffer = UnsafeMutableAudioBufferListPointer(mutableAudioBufferList).map(UnsafeBufferPointer<Float64>.init)
			let source = format.isInterleaved ?
			(0..<Int(format.channelCount)).map { idx in
				buffer[buffer.startIndex].baseAddress?.advanced(by: idx)
			} : buffer.map(\.baseAddress)
			for (offset, source) in source.enumerated() {
				cblas_dcopy(min(count, .init(frameLength)), source, stride, target.advanced(by: offset * leading), 1)
			}
		case.pcmFormatFloat32:
			guard let source = floatChannelData else { return }
			for offset in 0..<Int(format.channelCount) {
				vDSP_vspdp(source[offset], stride, target.advanced(by: offset * leading), 1, .init(min(count, .init(frameLength))))
			}
		case.pcmFormatInt32:
			guard let source = int32ChannelData else { return }
			for offset in 0..<Int(format.channelCount) {
				vDSP_vflt32D(source[offset], stride, target.advanced(by: offset * leading), 1, .init(min(count, .init(frameLength))))
			}
		case.pcmFormatInt16:
			guard let source = int16ChannelData else { return }
			for offset in 0..<Int(format.channelCount) {
				vDSP_vflt16D(source[offset], stride, target.advanced(by: offset * leading), 1, .init(min(count, .init(frameLength))))
			}
		case.otherFormat:
			break
		@unknown default:
			break
		}
	}
}
extension AVAudioPCMBuffer: Stream {
	@inlinable
	public var count: Int {
		.init(format.channelCount)
	}
	@inlinable
	public func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		if CMTimeCompare(CMTimeMultiplyByFloat64(interval, multiplier: format.sampleRate), .init(seconds: 1, preferredTimescale: 1)) == .zero, capacity <= .init(frameCapacity) {
			{ [weak self] in
				guard let self else { return }
				copy(count: $1, target: $2, leading: $3)
			}
		} else {
			throw Error.unmatchChannel
		}
	}
}
