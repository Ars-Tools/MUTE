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
import NSP
import MetalPerformanceShadersGraph
@testable import FSP
@Suite
struct BiquadTestCase {
	@Test
	func fitSOS() {
		let response = Array<Float64>(unsafeUninitializedCapacity: 256) {
			vDSP.formRamp(withInitialValue: -128, increment: 1, result: &$0)
			vDSP.divide($0, 32, result: &$0)
			vForce.cosPi($0, result: &$0)
//			vDSP.formRamp(withInitialValue: -32, increment: 1, result: &$0)
//			vDSP.divide($0, 32, result: &$0)
//			vDSP.square($0, result: &$0)
			vDSP.evaluatePolynomial(usingCoefficients: [3, 0.0, -0.01, 0.0, 0.2, 0, -0.03, 0, 0.12, 0, 0.12], withVariables: $0, result: &$0)
			$1 = $0.count
		}
		print(response)
		print(fit(response: minimum(mag: response), with: 24).map { ($0.x, $0.y, $0.z, $1.x, $1.y, $1.z) })
	}
    @Test
    func fitBEQ() throws {
        let a = try Buffer(raw: "/tmp/ir.raw", stream: 1)
        let m = Array(UnsafeBufferPointer(start: a.start, count: a.period))
        let f = vDSP.ramp(in: 0.0 ... 96000.0, count: m.count)
        let x = lnslope(frequency: f, magnitude: m, bandwidth: 100 ... 8000)
        try x.withUnsafeBufferPointer(Data.init(buffer:)).write(to: .init(filePath: "/tmp/slope.raw"))
    }
    @Test
    func fitPEQ() {
        let response = Array<Float64>(unsafeUninitializedCapacity: 2048) {
            vDSP.formRamp(in: -12 ... 12, result: &$0)
            vDSP.square($0, result: &$0)
            vDSP.negative($0, result: &$0)
            vForce.exp($0, result: &$0)
            vDSP.add(multiplication: ($0, 0.2), 1.0, result: &$0)
            $1 = $0.count
        }
        let sos = peq(frequency: vDSP.ramp(in: 0 ... 1.0, count: response.count),
                            magnitude: response,
                            initial: (logspace(in: 100 / 48000.0 ... 1.0, count: 32), 1.0),
                            update: (1e-8, 1e-4, 1e-4, 1e-6),
                            epoch: (10, 10000)) {
            print($0, $1[0].contents().load(as: Float32.self))
        }
        print(sos)
    }
    @Test
    func fitLSLPEQ() throws {
        let buffer = try Buffer(stream: 1, period: 480000, backing: "/tmp/ru.raw", release: false)
        let x = uniform(in: -1 ... 1)
        let y = filter(x, sos:
                .peq(ω₀: AngularFrequency(rawValue: 0.125), quality: 6, gain: 6),
                .peq(ω₀: AngularFrequency(rawValue: 0.250), quality: 6, gain: 6),
                .peq(ω₀: AngularFrequency(rawValue: 0.375), quality: 6, gain: 6)
        )
        try buffer.import(stream: y, interval: .init(value: 1, timescale: 1024))
        let p = Buffer(stream: 8, period: buffer.period)
        let object = lsl_create(p.stream)
        defer { lsl_destroy(object) }
        lsl_reset(object)
        lsl_lambda(object, 0.999)
        lsl_p(object, buffer.start, p.start, p.period, buffer.period)
        print(p[0..., p.period - 1])
        
    }
    @Test
    func logsp() {
        let sp = logspace(in: 16...256, count: 4)
        print(sp)
    }
}
