//
//  Client.swift
//  MUTE
//
//  Created by Kota on 7/18/R7.
//
import Foundation
import Testing
import MIDI
import CoreMIDI
import Combine
@Suite
struct ClientTestCase {
	@Test(.timeLimit(.minutes(1)))
	func main() {
		let source = Client.default.Source.removeDuplicates().sink {
			print($0)
		}
		let target = Client.default.Target.removeDuplicates().sink {
			print($0)
		}
		withExtendedLifetime((source, target)) {
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
	}
}
