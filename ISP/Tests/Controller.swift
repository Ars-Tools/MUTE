//
//  Controller.swift
//  MUTE
//
//  Created by Kota on 9/14/26.
//
import Testing
@testable import ISP
import ESP
import NSP
import typealias CoreMedia.CMTime
import func CoreMedia.CMTimeCompare
import typealias Numerics.Complex128

@Suite
struct SISOControllerTestCases {
    struct AnalysisTimeout: Error {}

    /// Wait for the controller's serial analysis queue before overwriting the
    /// two-frame ring in the next simulated I/O callback.
    func wait(for index: Int,
              estimator: Estimators.RLS<ESP.DFT.DFS>) async throws {
        for _ in 0..<1_000 {
            if estimator.snapshot.τ == index {
                return
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw AnalysisTimeout()
    }

    @Test
    func estimatesKnownLongMemoryPlantOnline() async throws {
        let frameCount = 64
        let frameTotal = 384
        let order = 16
        let gain = 0.625
        let feedback = 0.8
        let estimator = Estimators.RLS(dft: ESP.DFT.DFS(count: frameCount),
                                       count: order,
                                       λ: 0.98)
        let controller = CTF.SISOController(
            window: .init(repeating: 1, count: frameCount),
            stride: frameCount,
            capacity: frameCount,
            exciter: Exciters.Uniform(in: -1 ... 1),
            estimator: estimator
        )

        // Give the known plant a feedback delay equal to one complete DFT
        // frame: p[n] = gain * x[n] + feedback * p[n - frameCount].
        // Feeding p into the following I/O callback adds one transport frame,
        // so each bin obeys the exact frame-domain model
        // Y[k] = gain * sum(feedback^(lag - 1) * X[k - lag], lag: 1...).
        // Unlike a short biquad with an arbitrary block boundary, this excites
        // long frame memory without introducing cross-bin boundary leakage.
        let plant = universal_filter_create(1, frameCount + 1, 1)
        defer { universal_filter_destroy(plant) }
        let b = [gain]
        var a = Array(repeating: 0.0, count: frameCount + 1)
        a[0] = 1
        a[frameCount] = -feedback
        var observation = Array(repeating: 0.0, count: frameCount)
        var excitationPower = 0.0

        for frame in 0..<frameTotal {
            // Begin at a nonzero absolute sample index so completion of the
            // first analysis frame is distinguishable from an empty Snapshot.
            let index = (frame + 1) * frameCount
            let excitation = controller.dsp(index: index, input: observation)
            excitationPower += excitation.reduce(0) { $0 + $1 * $1 }

            try await wait(for: index, estimator: estimator)

            excitation.withUnsafeBufferPointer { x in
                observation.withUnsafeMutableBufferPointer { y in
                    universal_filter_static(
                        plant,
                        b, 1,
                        a, 1,
                        x.baseAddress.unsafelyUnwrapped, frameCount,
                        y.baseAddress.unsafelyUnwrapped, frameCount,
                        frameCount
                    )
                }
            }
        }

        let snapshot = estimator.snapshot
        #expect(snapshot.τ == frameTotal * frameCount)
        #expect(snapshot.ω.count == frameCount / 2 + 1)
        #expect(excitationPower > 0)

        // Coefficients are channel-major [frequency bin, frame lag].  The
        // current-frame coefficient is zero because of transport latency;
        // following coefficients are the truncated geometric impulse response
        // gain, gain * feedback, gain * feedback^2, ... at every frequency.
        let binCount = frameCount / 2 + 1
        var coefficients = Array(repeating: Complex128.zero,
                                 count: binCount * order)
        coefficients.withUnsafeMutableBufferPointer {
            rls_filter_coefficients(estimator.core,
                                    .init($0.baseAddress.unsafelyUnwrapped),
                                    order)
        }
        for bin in 0..<binCount {
            #expect(coefficients[bin * order + 0].magnitude < 0.02)
            var expected = gain
            for lag in 1..<order {
                let target = Complex128(real: expected, imag: 0)
                #expect((coefficients[bin * order + lag] - target).magnitude < 0.03)
                expected *= feedback
            }
        }

        // Prediction error then contains only the truncated tail and the
        // exponentially decaying burn-in transient.
        let residualPower = snapshot.Sεε.reduce(0, +)
        let predictedPower = snapshot.Syy.reduce(0, +)
        #expect(residualPower / predictedPower < 0.02)
    }
}

//@Suite
//struct CTFControllerTestCases {
//    final class Capture: Estimators.`Protocol`, @unchecked Sendable {
//        struct Record {
//            let time: CMTime
//            let frequency: Array<Float64>
//            let x0: Float64
//            let y0: Float64
//        }
//        var records: Array<Record> = []
//        var snapshot: CTF.Snapshot = .init()
//
//        func update(_ frame: borrowing CTF.Frame) {
//            records.append(.init(time: frame.time,
//                                 frequency: frame.frequency,
//                                 x0: frame.X[0].real,
//                                 y0: frame.Y[0].real))
//        }
//    }
//
//    final class Ones: Exciters.`Protocol`, @unchecked Sendable {
//        func generate(at time: CMTime,
//                      count: Int,
//                      output: UnsafeMutablePointer<Float64>,
//                      outputLeadingDimension: Int,
//                      snapshot: borrowing CTF.Snapshot) {
//            output.initialize(repeating: 1, count: count)
//        }
//    }
//
//    @Test
//    func emitsEveryCrossedHopWithAlignedXY() {
//        let estimator = Capture()
//        let controller = CTF.Controller(
//            sampleRate: 8,
//            maximumCallbackFrameCount: 3,
//            hopCount: 2,
//            window: Array(repeating: 1, count: 4),
//            dft: ESP.DFT.DFS(count: 4),
//            estimator: estimator,
//            exciter: Ones()
//        )
//        let y0: Array<Float64> = [1, 2, 3]
//        let y1: Array<Float64> = [4, 5, 6]
//        var x0 = Array<Float64>(repeating: .nan, count: 3)
//        var x1 = Array<Float64>(repeating: .nan, count: 3)
//
//        y0.withUnsafeBufferPointer { y in
//            x0.withUnsafeMutableBufferPointer { x in
//                controller(at: .init(value: 0, timescale: 8),
//                           count: 3,
//                           input: y.baseAddress.unsafelyUnwrapped,
//                           inputLeadingDimension: y.count,
//                           output: x.baseAddress.unsafelyUnwrapped,
//                           outputLeadingDimension: x.count)
//            }
//        }
//        y1.withUnsafeBufferPointer { y in
//            x1.withUnsafeMutableBufferPointer { x in
//                controller(at: .init(value: 3, timescale: 8),
//                           count: 3,
//                           input: y.baseAddress.unsafelyUnwrapped,
//                           inputLeadingDimension: y.count,
//                           output: x.baseAddress.unsafelyUnwrapped,
//                           outputLeadingDimension: x.count)
//            }
//        }
//
//        #expect(x0 == [1, 1, 2])
//        #expect(x1 == [2, 2, 2])
//        #expect(estimator.records.count == 2)
//        let expectedFrequency: Array<Float64> = (0..<4).map {
//            2 * Float64.pi * 8 * Float64($0) / 4
//        }
//        #expect(estimator.records[0].frequency == expectedFrequency)
//        #expect(estimator.records[0].x0 == 6)
//        #expect(estimator.records[0].y0 == 10)
//        #expect(estimator.records[1].x0 == 8)
//        #expect(estimator.records[1].y0 == 18)
//        #expect(CMTimeCompare(estimator.records[0].time,
//                             .init(value: 0, timescale: 8)) == 0)
//        #expect(CMTimeCompare(estimator.records[1].time,
//                             .init(value: 2, timescale: 8)) == 0)
//    }
//
//    @Test
//    func resetsAnalysisAcrossTimestampDiscontinuity() {
//        let estimator = Capture()
//        let controller = CTF.Controller(
//            sampleRate: 8,
//            maximumCallbackFrameCount: 3,
//            hopCount: 2,
//            window: Array(repeating: 1, count: 4),
//            dft: ESP.DFT.DFS(count: 4),
//            estimator: estimator,
//            exciter: Ones()
//        )
//        let y = Array<Float64>(repeating: 1, count: 3)
//        var x = Array<Float64>(repeating: 0, count: 3)
//
//        for time in [CMTime(value: 0, timescale: 8),
//                     CMTime(value: 10, timescale: 8)] {
//            y.withUnsafeBufferPointer { y in
//                x.withUnsafeMutableBufferPointer { x in
//                    controller(at: time,
//                               count: 3,
//                               input: y.baseAddress.unsafelyUnwrapped,
//                               inputLeadingDimension: y.count,
//                               output: x.baseAddress.unsafelyUnwrapped,
//                               outputLeadingDimension: x.count)
//                }
//            }
//        }
//
//        #expect(estimator.records.isEmpty)
//    }
//}
