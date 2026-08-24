//
//  Hilbert.swift
//  MUTE
//
//  Created by Kota on 8/19/26.
//
import Testing
@testable import ESP
@Suite
struct HilbertTestCases {
    @Test
    func analyticSignal() {
        let signal = [0.5, 0.1, 0.9, 0.8, 0.5, 0.8, 0.9, 0.1]
        let analytic = Hilbert.Analytic(signal: signal)
        #expect(signal.count == analytic.count)
        #expect(analytic.map(\.imag.magnitude).contains(where: Float64.ulpOfOne.squareRoot().isLess(than:)))
        #expect(zip(signal, analytic.map(\.real)).map(-).map(\.magnitude).allSatisfy { $0.isLess(than: .ulpOfOne.squareRoot()) })
    }
    @Test
    func minimumPhase() {
        let response = [0.5, 0.1, 0.9, 0.8, 0.5, 0.8, 0.9, 0.1]
        let minPhase = Hilbert.MinimumPhase(response: response)
        #expect(response.count == minPhase.count)
        #expect(zip(response, minPhase.map(\.magnitude)).map(-).map(\.magnitude).allSatisfy { $0.isLess(than: .ulpOfOne.squareRoot()) })
    }
}
