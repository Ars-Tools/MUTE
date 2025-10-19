//
//  Framewise.swift
//  MUTE
//
//  Created by Kota on 7/23/R7.
//
import Testing
import Accelerate
@testable import DSP
@Suite
struct FramewiseTestCase {
	@Test
	func winKaiser() {
		let w = Framewise.Window.kaiser(1024 as Samples, 1.33)
		print(w.coefficients(for: .invalid))
	}
	@Test
	func cancel() {
		let t = Task {
			try await Task.sleep(for: .seconds(3))
		}
		t.cancel()
		t.cancel()
		t.cancel()
	}
}
