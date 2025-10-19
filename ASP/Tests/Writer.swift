//
//  Writer.swift
//  MUTE
//
//  Created by Kota on 7/16/R7.
//
import Testing
import DSP
import AVFoundation
@Suite
struct WriterTestCases {
	@Test
	func writesin() throws {
		let source = sin(freqs: line(order: .init(position: 220), .init(position: 880, duration: 10)))
		let target = try AVAudioFile(forWriting: URL(filePath: "/tmp/dump.m4a"), settings: [
			AVFormatIDKey: kAudioFormatMPEG4AAC
//			AVFormatIDKey: kAudioFormatAppleLossless
		], commonFormat: .pcmFormatFloat64, interleaved: false)
		try target.write(stream: source, for: 12, process: 0.1)
	}
}
