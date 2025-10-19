//
//  Bridge.swift
//  MUTE
//
//  Created by Kota on 7/23/R7.
//
import CoreFoundation
import Testing
import MIDI
import Synchronization
@Suite(.timeLimit(.minutes(1)))
struct PR {
	let client: Client = .default
	@Test
	func scenario() throws {
		let signal = Atomic<Bool>(false)
		let target = try Receiver(name: "Receiver", as: ._1_0)
		let recv = target.sink {
			#expect($0 == 0)
			switch MSG_1_0(rawValue: $1).map(\.message) {
			case.some(.noteOn(0x40, 0x60)):
				signal.store(true, ordering: .releasing)
			default:
				break
//				Issue.record()
			}
		}
		let source = try Publisher(name: "Publisher", as: ._1_0)
		let event = Bridge.Connection(from: "Publisher", to: "Receiver", as: "Bridge-1").sink {
			if $0 {
				do {
					try source.publish(msg: payload)
				} catch {
					Issue.record()
				}
			}
		}
		withExtendedLifetime((source, target, event, recv)) {
			switch CFRunLoopRunInMode(.some(.defaultMode), 12, false) {
			case.timedOut:
				break
			case.finished:
				Issue.record()
			case.handledSource:
				Issue.record()
			case.stopped:
				Issue.record()
			@unknown default:
				Issue.record()
			}
		}
		#expect(signal.load(ordering: .relaxed) == true)
	}
	var payload: MIDI.Buffer {
		.init(msg: [MSG_1_0(note: 0x40, velocity: 0x60, channel: 0)], as: ._1_0, at: 0)
	}
}
