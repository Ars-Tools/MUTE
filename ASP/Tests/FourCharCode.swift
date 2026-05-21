//
//  OSType.swift
//  MUTE
//
//  Created by Kota on 7/20/R7.
//
import Testing
import AudioUnit
import CoreAudio
import AVFoundation
@testable import ASP
@Suite
struct FourCharCodeTestCase {
	@Test
	func conversion() {
		let raw = "@ars"
		let enc = en(code: raw)
		let dec = de(code: enc)
		#expect(raw == dec)
	}
	@Test(arguments: [
		("aumu", kAudioUnitType_MusicDevice),
//		("tmpt", kAudioUnitSubType_Pitch),
		("appl", kAudioUnitManufacturer_Apple),
	])
	func musicDevice(expected: String, query: CoreAudio.FourCharCode) {
		let dec = de(code: query)
		#expect(dec == expected)
	}
}
@Suite
struct AVFormatTestCases {
    @Test
    func mono() {
        guard case.some(let format) = AVAudioFormat(sampleRate: 192000, discreteChannels: 1024) else {
            Issue.record()
            return
        }
        print(format)
    }
}
