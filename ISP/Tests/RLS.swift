//
//  RLS.swift
//  MUTE
//
//  Created by Kota on 9/14/26.
//
import Testing
import ISP
import func Darwin.cos
import func Darwin.sin
import typealias CoreMedia.CMTime
import typealias Numerics.Complex128

//@Suite
//struct CTFRLSTestCases {
//    @Test
//    func estimatesOneFrameDelayedComplexTransfer() {
//        let estimator = Estimators.RLS(order: 1,
//                                       count: 1,
//                                       forgettingFactor: 1)
//        let gain = Complex128(real: 0.75, imag: -0.25)
//        var previous = Complex128.zero
//
//        for index in 0..<2_048 {
//            let phase = Float64(index) * 0.37
//            let x = Complex128(real: cos(phase), imag: sin(phase))
//            let y = index == 0 ? .zero : gain * previous
//            estimator.update(.init(time: CMTime(value: .init(index), timescale: 1),
//                                   frequency: [0],
//                                   X: [x],
//                                   Y: [y]))
//            previous = x
//        }
//
//        #expect((estimator.snapshot.transfer[0] - gain).magnitude < 1e-3)
//        #expect(estimator.snapshot.effectiveSampleCount == 2_047)
//        #expect(estimator.snapshot.valid == [true])
//
//        estimator.reset()
//        #expect(estimator.snapshot.frequency.isEmpty)
//    }
//}
