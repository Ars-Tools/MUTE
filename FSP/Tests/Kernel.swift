//
//  Kernel.swift
//  MUTE
//
//  Created by Kota on 9/6/R7.
//
import Testing
import DSP
import ESP
import NSP
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Numerics.Complex128
@testable import FSP
@Suite
struct KernelTestCases {
    @Test(
        arguments: [1024]
    )
    func fit(count: Int) {
        let (b0, b1, b2, a1, a2) = BiquadFilter.Design.peq(ω₀: AngularFrequency(rawValue: .init(numerator: 1, denominator: 9)), quality: 0.5.squareRoot(), gain: 12)
            .coefficients(for: .zero)
        print(b0, b1, b2, a1, a2)
        var S = SIMD4<Float64>()
        let x = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:))
//        let x = Array<Float64>(unsafeUninitializedCapacity: count) {
//            $1 = $0.count
//            $0.initialize(repeating: .zero)
//            $0[0] = 1
//        }
        let y = Array<Float64>(unsafeUninitializedCapacity: count) {
            $1 = $0.count
            biquad_filter_convolve_static(.init(b0, b1, b2),
                                          .init(1.0, a1, a2),
                                          x,
                                          $0.baseAddress.unsafelyUnwrapped, &S, $1)
        }
        let dft = DFT.BFS(count: count)
        let magY = y.withUnsafeTemporaryComplexBuffer(dft.forward).map(\.magnitude)
        let minY = ESP.Hilbert.Transformer(dft: dft).MinimumPhase(response: magY)
        do {
            let (b, a) = Utils.fit(response: minY, kernel: (2, 2))
            print(b, a, separator: ", ")
            #expect(roots(poly: b).map(\.magnitude).allSatisfy { $0 < 1 })
            #expect(roots(poly: a).map(\.magnitude).allSatisfy { $0 < 1 })
        }
        do {
            let r = minY.map(\.real)
            let i = minY.map(\.imag)
            let (b, a) = Utils.fit(response: (r, i),
                                   kernel: (2, 2),
                                   iteration: 12)
            print(b, a, separator: ", ")
            #expect(roots(poly: b).map(\.magnitude).allSatisfy { $0 < 1 })
            #expect(roots(poly: a).map(\.magnitude).allSatisfy { $0 < 1 })
        }
        do {
            let (b, a) = Utils.Fit(response: minY,
                                   iteration: 1,
                                   kernel: (2, 2))
            print(b, a, separator: ", ")
//            #expect(roots(poly: b).map(\.magnitude).allSatisfy { $0 < 1 })
//            #expect(roots(poly: a).map(\.magnitude).allSatisfy { $0 < 1 })
        }
    }
	@Test
	func kernel() {
//		let (b, a) = fit(frequency: vDSP.ramp(in: 0...1, count: 9),
//						 response: minimumPhase(mag: [1, 0.25, 0.5, 0.25, 0.125, 0.25, 0.5, 0.125, 0.25]), with: (4, 4))
		
		let response = Array<Float64>(unsafeUninitializedCapacity: 64) {
			vDSP.formRamp(withInitialValue: -32, increment: 1, result: &$0)
			vDSP.divide($0, 8, result: &$0)
			vForce.cosPi($0, result: &$0)
//			vDSP.formRamp(withInitialValue: -128, increment: 1, result: &$0)
//			vDSP.divide($0, 128, result: &$0)
//			vDSP.square($0, result: &$0)
			vDSP.add(multiplication: ($0, 0.40), 0.5, result: &$0)
			$1 = $0.count
		}
//		print("response=", response)
//		print("mpx=", exp(hilbert(freq: vForce.log(response))))
//		print("mpy=", minimum(mag: response))
//		let (b, a) = fit(response: minimum(mag: response), with: (6, 6))
//		print("b=", b)
//		print("a=", a)
		
	}
}
