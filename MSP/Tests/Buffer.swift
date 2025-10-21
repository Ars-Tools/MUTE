//
//  Buffer.swift
//  MUTE
//
//  Created by Kota on 5/16/R7.
//
import Testing
import Synchronization
import AVFoundation
//import MSP
//@Suite
//struct BufferTests {
//	@Test
//	func load() throws {
//		let file = try AVAudioFile(forReading: .init(filePath: "/tmp/01.m4a"))
//		print(file.fileFormat, file.processingFormat.streamDescription.pointee)
//		let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat64, sampleRate: 16000, channels: file.processingFormat.channelCount, interleaved: false).unsafelyUnwrapped
//		let converter = AVAudioConverter(from: file.processingFormat, to: targetFormat).unsafelyUnwrapped
//		let length = Float64(file.length) * targetFormat.sampleRate / file.processingFormat.sampleRate + 1
//		var lc = UnsafeMutableBufferPointer<Float64>.allocate(capacity: .init(length))
//		var rc = UnsafeMutableBufferPointer<Float64>.allocate(capacity: .init(length))
//		let mem = AudioBufferList.allocate(maximumBuffers: 2)
//		defer {
//			lc.deallocate()
//			rc.deallocate()
//		}
//		mem[0] = .init(lc, numberOfChannels: 1)
//		mem[1] = .init(rc, numberOfChannels: 1)
//		
//		let target = AVAudioPCMBuffer(pcmFormat: targetFormat, bufferListNoCopy: mem.unsafePointer, deallocator: .none).unsafelyUnwrapped
//		var err: NSError?
//		let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
//			print(inNumPackets)
//			do {
//				let inputBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: inNumPackets)!
//				try file.read(into: inputBuffer, frameCount: inNumPackets)
//				outStatus.pointee = .haveData
//				return.some(inputBuffer)
//			} catch {
////				print("Error reading audio file: \(error)")
//				outStatus.pointee = .endOfStream
//				return nil
//			}
//		}
//		converter.convert(to: target, error: &err, withInputFrom: inputBlock)
//		print(err)
////		let target = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: )
//		print(Array(lc).dropFirst(16000).prefix(100))
//	}
//}
