//
//  H1.swift
//  MUTE
//
//  Created by Kota on 9/14/26.
//
import Testing
import ISP
import typealias CoreMedia.CMTime
import typealias Numerics.Complex128

//@Suite
//struct CTFH1TestCases {
//    @Test
//    func estimatesTransferCoherenceAndUnobservedBand() {
//        let estimator = Estimators.H1(channelCount: 1,
//                                      frameCount: 3,
//                                      sampleRate: 48_000)
//
//        estimator.update(frame(index: 0,
//                               x: [1, 1, 0],
//                               y: [2, 1, 3]))
//        #expect(estimator.snapshot.valid == [false, false, false])
//
//        estimator.update(frame(index: 1,
//                               x: [1, 1, 0],
//                               y: [2, -1, 4]))
//
//        let snapshot = estimator.snapshot
//        let expectedFrequency: Array<Float64> = (0..<3).map {
//            2 * Float64.pi * 48_000 * Float64($0) / 3
//        }
//        #expect(snapshot.frequency == expectedFrequency)
//        #expect((snapshot.transfer[0] - Complex128(real: 2, imag: 0)).magnitude < 1e-12)
//        #expect(abs(snapshot.coherenceSquared[0] - 1) < 1e-12)
//        #expect(snapshot.residualPower[0] < 1e-12)
//
//        #expect(snapshot.transfer[1] == .zero)
//        #expect(snapshot.coherenceSquared[1] < 1e-12)
//        #expect(abs(snapshot.residualPower[1] - 1) < 1e-12)
//
//        #expect(snapshot.transfer[2] == .zero)
//        #expect(snapshot.coherenceSquared[2] == 0)
//        #expect(snapshot.valid == [true, true, false])
//        #expect(snapshot.effectiveSampleCount == 2)
//    }
//
//    private func frame(index: Int,
//                       x: Array<Complex128>,
//                       y: Array<Complex128>) -> CTF.Frame {
//        .init(time: CMTime(value: .init(index), timescale: 1),
//              frequency: [0, 1.0 / 3.0, 2.0 / 3.0],
//              X: x,
//              Y: y)
//    }
//}
