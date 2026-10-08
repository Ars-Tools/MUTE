//
//  Kernel.swift
//  MUTE
//
//  Created by Kota on 9/6/R7.
//
import Testing
import DSP
import ESP
import KSP
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
        let (b0, b1, b2, a1, a2) = switch Model.Biquad.PEQ(ω₀: 1/9.0, Q: 0.5.squareRoot(), dB: 12).normalized {
        case let k:
            (k[0], k[1], k[2], k[3], k[4])
        }
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
        let fit = Model.fit(x: (r: Array(repeating: 1.0, count: count),
                                i: Array(repeating: 0.0, count: count)),
                            y: (r: minY.map(\.real), i: minY.map(\.imag)),
                            frequency: (0..<count).map { Float64($0) / Float64(count) },
                            weight: Array(repeating: 1.0, count: count),
                            count: (2, 2))
        print(fit.b, fit.a, separator: ", ")
        #expect(fit.b.count == 3)
        #expect(fit.a.count == 3)
        #expect(Polynomial.roots(poly: fit.b).map(\.magnitude).allSatisfy { $0 < 1 })
        #expect(Polynomial.roots(poly: fit.a).map(\.magnitude).allSatisfy { $0 < 1 })
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
