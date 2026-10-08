//
//  Biquad.swift
//  MUTE
//
//  Created by Kota on 8/26/R7.
//
import typealias Accelerate.vDSP
import Accelerate.vecLib
import Testing
import simd
import DSP
import CoreMedia
import KSP
import ESP
import MetalPerformanceShadersGraph
@testable import FSP
//@Suite
//struct BiquadTestCase {
//	@Test
//	func fitSOS() throws {
//        let w = [
//            .peq(ω₀: AngularFrequency(rawValue: .init(numerator: 1, denominator: 12)), quality: 6, gain: 18),
//            .peq(ω₀: AngularFrequency(rawValue: .init(numerator: 2, denominator: 12)), quality: 6, gain: -6),
//            .peq(ω₀: AngularFrequency(rawValue: .init(numerator: 4, denominator: 12)), quality: 6, gain: 12),
//        ] as Array<BiquadFilter.Design>
//        print(w.map { $0.coefficients(for: .zero) }.map {
//            [$0.b₀, $0.b₁, $0.b₂, 1, $0.a₁, $0.a₂]
//        })
//        let x = uniform(in: -1 ... 1)
//        let y = filter(x, sos: w)
//        let z = Buffer(stream: 1, period: 1024)
//        try z.import(stream: y, interval: .zero)
//        let dft = DFT.DFS(count: z.period)
//        let magZ = z.unsafeMutableBufferPointer.map {
//            $0.withUnsafeTemporaryComplexBuffer(dft.forward).map(\.magnitude)
//        }[0]
//        let minZ = Hilbert.Transformer(dft: dft).MinimumPhase(response: magZ)
//        let sos = Utils.Fit(response: minZ, with: 3).map {
//            [$0.x, $0.y, $0.z, $1.x, $1.y, $1.z]
//        }
//        print(sos)
////		let response = Array<Float64>(unsafeUninitializedCapacity: 256) {
////			vDSP.formRamp(withInitialValue: -128, increment: 1, result: &$0)
////			vDSP.divide($0, 16, result: &$0)
////			vForce.cosPi($0, result: &$0)
//////			vDSP.formRamp(withInitialValue: -32, increment: 1, result: &$0)
//////			vDSP.divide($0, 32, result: &$0)
//////			vDSP.square($0, result: &$0)
////			vDSP.evaluatePolynomial(usingCoefficients: [3, 0.0, -0.01, 0.0, 0.2, 0, -0.03, 0, 0.12, 0, 0.12], withVariables: $0, result: &$0)
////			$1 = $0.count
////		}
////		print(response)
////        print(Utils.Fit(response: Hilbert.MinimumPhase(response: response), with: 24).map { ($0.x, $0.y, $0.z, $1.x, $1.y, $1.z) })
//	}
//    @Test
//    func fitBEQ() throws {
//        let a = try Buffer(raw: "/tmp/ir.raw", stream: 1)
//        let m = Array(UnsafeBufferPointer(start: a.start, count: a.period))
//        let f = vDSP.ramp(in: 0.0 ... 96000.0, count: m.count)
////        let x = Octave.lnslope(frequency: f, magnitude: m, bandwidth: 100 ... 8000)
////        try x.withUnsafeBufferPointer(Data.init(buffer:)).write(to: .init(filePath: "/tmp/slope.raw"))
//    }
//    @Test
//    func fitPEQ() {
//        let response = Array<Float64>(unsafeUninitializedCapacity: 2048) {
//            vDSP.formRamp(in: -12 ... 12, result: &$0)
//            vDSP.square($0, result: &$0)
//            vDSP.negative($0, result: &$0)
//            vForce.exp($0, result: &$0)
//            vDSP.add(multiplication: ($0, 0.2), 1.0, result: &$0)
//            $1 = $0.count
//        }
//        let sos = Model.fit(response: response,
//                            frequency: vDSP.ramp(in: 0 ... 1.0, count: response.count),
//                            weight: Array(repeating: 1.0, count: response.count),
//                      initial: (Ramp.logspace(in: 100 / 48000.0 ... 1.0, count: 32), 1.0),
//                            update: (1e-8, 1e-4, 1e-4, 1e-6),
//                            epoch: (10, 10000)) {
//            print($0, $1[0].contents().load(as: Float32.self))
//        }
//        print(sos)
//    }
//    @Test
//    func fitLSLPEQ() throws {
//        let buffer = try Buffer(stream: 1, period: 480000, backing: "/tmp/ru.raw", release: false)
//        let x = uniform(in: -1 ... 1)
//        let y = filter(x, sos:
//                .peq(ω₀: AngularFrequency(rawValue: 0.125), quality: 6, gain: 6),
//                .peq(ω₀: AngularFrequency(rawValue: 0.250), quality: 6, gain: 6),
//                .peq(ω₀: AngularFrequency(rawValue: 0.375), quality: 6, gain: 6)
//        )
//        try buffer.import(stream: y, interval: .init(value: 1, timescale: 1024))
//        let p = Buffer(stream: 8, period: buffer.period)
//        let object = lsl_create(p.stream)
//        defer { lsl_destroy(object) }
//        lsl_reset(object)
//        lsl_lambda(object, 0.999)
//        lsl_p(object, buffer.start, p.start, p.period, buffer.period)
//        print(p[0..., p.period - 1])
//        
//    }
//    @Test
//    func logsp() {
//        let sp = Ramp.logspace(in: 16...256, count: 4)
//        print(sp)
//    }
//}
