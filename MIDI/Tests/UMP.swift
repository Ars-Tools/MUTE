//
//  UMP.swift
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
import Testing
import CoreMIDI
import MIDI
@Suite
struct UMPTestCase {
	@Test
	func noteIn_1_0_1() throws {
		let raw = [
			.init(note: 80, velocity: 80, channel: 0),
			.init(note: 80, velocity: 0, channel: 0)
		] as [MSG_1_0]
		let enc = MIDI.Buffer(msg: raw, as: ._1_0, at: 0)
		let dec = enc.withUnsafeEventListPointer(Array.init)
		#expect(dec.count == 2)
		let msg = Array(dec.noteIn_1_0)
		#expect(msg.count == 2)
		#expect(msg[0] == (0, 0, 80, 80))
		#expect(msg[1] == (0, 0, 80, 0))
	}
	@Test
	func noteIn_1_0_2() throws {
		let raw = [
			.init(note: 80, velocity: 80, channel: 0),
			.init(note: 80, velocity: 0, channel: 0)
		] as [MSG_1_0]
		let enc = MIDI.Buffer(msg: raw, as: ._2_0, at: 0)
		let dec = enc.withUnsafeEventListPointer(Array.init)
		#expect(dec.count == 2)
		let msg = Array(dec.noteIn_1_0)
		#expect(msg.count == 2)
		#expect(msg[0] == (0, 0, 80, 80))
		#expect(msg[1] == (0, 0, 80, 0))
	}
	@Test
	func noteIn_2_0() throws {
		let raw = [
			.init(note: 80, velocity: 0x7fff, channel: 0),
			.init(note: 80, velocity: 0x0000, channel: 0)
		] as [MSG_2_0]
		let enc = MIDI.Buffer(msg: raw, as: ._2_0, at: 0)
		let dec = enc.withUnsafeEventListPointer(Array.init)
		#expect(dec.count == 2)
		let msg = Array(dec.noteIn_2_0)
		#expect(msg.count == 2)
		#expect(msg[0] == (0, 0, 80, 0x7fff))
		#expect(msg[1] == (0, 0, 80, 0x0000))
	}
}
