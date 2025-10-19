//
//  PeriodicLookup.swift
//  MUTE
//
//  Created by Kota on 10/18/R6.
//
import typealias Accelerate.vDSP
import Testing
import NSP
@Suite
struct LookupTests {
	@Test
	func phasor() {
		let table = [3, 4, 5, 4] as Array<Float64>
//		let index = vDSP.ramp(withInitialValue: 0.0, increment: 1.0 / 16.0, count: 17)
//		var value = Array<Float64>(repeating: .zero, count: 17)
//		periodic_lookup_with_active(table, 0,
//									index, 0,
//									&value, 0,
//									4, 1, 17)
//		#expect(value == [3.0, 3.25, 3.5, 3.75, 4.0, 4.25, 4.5, 4.75, 5.0, 4.75, 4.5, 4.25, 4.0, 3.75, 3.5, 3.25, 3.0])
	}
}
