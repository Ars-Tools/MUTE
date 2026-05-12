//
//  AVF+Format+.swift
//  MUTE
//
//  Created by Kota on 7/16/R7.
//
@_exported @preconcurrency import typealias AVFoundation.AVAudioFormat
@preconcurrency import typealias AVFoundation.AVAudioCommonFormat
@preconcurrency import typealias AVFoundation.AudioChannelLayout
@preconcurrency import typealias AVFoundation.AVAudioChannelLayout
@preconcurrency import let AVFoundation.kAudioChannelLabel_Mono
@preconcurrency import let AVFoundation.kAudioChannelLayoutTag_DiscreteInOrder
extension AVAudioFormat: @retroactive @unchecked Sendable {
	public convenience init?(sampleRate: Float64, monoChannels count: Int) {
		let layout = AudioChannelLayout.allocate(maximumDescriptions: count)
		defer {
			layout.unsafePointer.deallocate()
		}
		for index in layout.indices {
			layout[index] = .init(mChannelLabel: .init(kAudioChannelLabel_Mono), mChannelFlags: .init(rawValue: 0), mCoordinates: (0, 0, 0))
		}
		self.init(standardFormatWithSampleRate: sampleRate, channelLayout: .init(layout: layout.unsafePointer))
	}
	public convenience init?(commonFormat: AVAudioCommonFormat, sampleRate: Float64, monoChannels count: Int, interleaved: Bool = false) {
		let layout = AudioChannelLayout.allocate(maximumDescriptions: count)
		defer {
			layout.unsafePointer.deallocate()
		}
		for index in layout.indices {
			layout[index] = .init(mChannelLabel: .init(kAudioChannelLabel_Mono), mChannelFlags: .init(rawValue: 0), mCoordinates: (0, 0, 0))
		}
		self.init(commonFormat: commonFormat, sampleRate: sampleRate, interleaved: interleaved, channelLayout: .init(layout: layout.unsafePointer))
	}
}
extension AVAudioFormat {
    public convenience init?(sampleRate: Float64, discreteChannels: Int) {
        switch discreteChannels {
        case 1:
            self.init(standardFormatWithSampleRate: sampleRate, channels: 1)
        case 2:
            self.init(standardFormatWithSampleRate: sampleRate, channels: 2)
        case let count:
            guard case.some(let layout) = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | .init(count)) else {
                return nil
            }
            self.init(standardFormatWithSampleRate: sampleRate, channelLayout: layout)
        }
    }
    public convenience init?(commonFormat: AVAudioCommonFormat, sampleRate: Float64, discreteChannels: Int, interleaved: Bool = false) {
        switch discreteChannels {
        case 1:
            self.init(commonFormat: commonFormat, sampleRate: sampleRate, channels: 1, interleaved: interleaved)
        case 2:
            self.init(commonFormat: commonFormat, sampleRate: sampleRate, channels: 2, interleaved: interleaved)
        case let count:
            guard case.some(let layout) = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | .init(count)) else {
                return nil
            }
            self.init(commonFormat: commonFormat, sampleRate: sampleRate, interleaved: interleaved, channelLayout: layout)
        }
    }
    
}
