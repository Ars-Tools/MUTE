//
//  Publisher+Subscriber.swift
//  MUTE
//
//  Created by Kota on 7/23/R7.
//
import Testing
import MIDI
import Synchronization
import Dispatch
@Suite
struct RS {
	let client: Client
	init() throws {
		client = .default
	}
	@Test(.timeLimit(.minutes(1)))
	func sync() throws {
		let source = "Test Source"
		let signal = DispatchSemaphore(value: 0)
		let done = Atomic<Bool>(false)
		let pubs = try Publisher(name: source, as: ._1_0)
		let send = try Subscriber(name: "subscriber", as: ._1_0)
		let wait = try send.subscribe(from: source).sink {
			#expect($0 == 0)
			switch MSG_1_0(rawValue: $1).map(\.message) {
			case.some(.noteOn(0x40, 0x60)):
				done.store(true, ordering: .releasing)
				signal.signal()
			default:
				Issue.record()
			}
		}
		try pubs.publish(msg: payload)
		signal.wait()
		#expect(done.load(ordering: .acquiring) == true)
		wait.cancel()
	}
	var payload: MIDI.Buffer {
		.init(msg: [MSG_1_0(note: 0x40, velocity: 0x60, channel: 0)], as: ._2_0, at: 0)
	}
}
