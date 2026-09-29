//
//  CTF+Snapshot.swift
//  MUTE
//
//  Created by Kota on 9/11/26.
//
import AltVec
import typealias Accelerate.vDSP
import typealias Numerics.Complex128
import func simd.recip
import typealias CLK.CMTime
extension CTF {
    public struct Snapshot: Sendable {
        public var τ: Int // sample index
        public let ω: Array<Float64> // normalized angular frequency [0, 1) -> [0, 2π) or [0, 0.5] -> [0, π]. [0, 0.5] is preferred
        public var ε: Array<Complex128>
        public var x: Array<Complex128>
        public var y: Array<Complex128>
        public var Sεε: Array<Float64>
        public var Sxx: Array<Float64>
        public var Syy: Array<Float64>
        public var Syx: Array<Complex128>
        @inlinable
        public init(angular frequency: Array<Float64>) {
            τ = 0
            ω = frequency
            ε = .init(repeating: .zero, count: ω.count)
            x = .init(repeating: .zero, count: ω.count)
            y = .init(repeating: .zero, count: ω.count)
            Sεε = .init(repeating: .leastNormalMagnitude.squareRoot(), count: ω.count)
            Sxx = .init(repeating: .leastNormalMagnitude.squareRoot(), count: ω.count)
            Syy = .init(repeating: .leastNormalMagnitude.squareRoot(), count: ω.count)
            Syx = .init(repeating: .zero, count: ω.count)
        }
    }
}
extension CTF.Snapshot {
    @inlinable
    public var σ²x: Array<Float64> {
        .init(unsafeUninitializedCapacity: x.count) {
            $1 = $0.count
            guard let target = $0.baseAddress else { return }
            Complex128.mags(x, 1, target, 1, $1)
            vDSP.subtract(Sxx, $0, result: &$0)
            vDSP.threshold($0, to: 0, with: .clampToThreshold, result: &$0)
        }
    }
    @inlinable
    public var σ²y: Array<Float64> {
        .init(unsafeUninitializedCapacity: y.count) {
            $1 = $0.count
            guard let target = $0.baseAddress else { return }
            Complex128.mags(y, 1, target, 1, $1)
            vDSP.subtract(Syy, $0, result: &$0)
            vDSP.threshold($0, to: 0, with: .clampToThreshold, result: &$0)
        }
    }
    @inlinable
    public var σyx: Array<Complex128> {
        .init(unsafeUninitializedCapacity: Syx.count) {
            $1 = $0.count
            guard let target = $0.baseAddress else { return }
            Complex128.Conj(x: x, inc: 1, y: target, inc: 1, length: $1)
            Complex128.Mul(x: y, inc: 1, y: target, inc: 1, z: target, inc: 1, length: $1)
            Complex128.Sub(x: Syx, inc: 1, y: target, inc: 1, z: target, inc: 1, length: $1)
        }
    }
}
extension CTF.Snapshot {
    @inlinable
    public var σxy: Array<Complex128> {
        .init(unsafeUninitializedCapacity: Syx.count) {
            $1 = $0.count
            guard let target = $0.baseAddress else { return }
            Complex128.Conj(x: σyx, inc: 1, y: target, inc: 1, length: $1)
        }
    }
    @inlinable
    public var Sxy: Array<Complex128> {
        .init(unsafeUninitializedCapacity: Syx.count) {
            $1 = $0.count
            guard let target = $0.baseAddress else { return }
            Complex128.Conj(x: Syx, inc: 1, y: target, inc: 1, length: $1)
        }
    }
}


//    public struct Snapshot: Sendable {
//        public let time: CMTime
//        public let frequency: Array<Float64>
//        public let transfer: Array<Complex128>
//        public let inputPower: Array<Float64>
//        public let outputPower: Array<Float64>
//        public let crossSpectrum: Array<Complex128> // Syx = E[Y conj(X)]
//        public let coherenceSquared: Array<Float64>
//        public let residualPower: Array<Float64>
//        public let effectiveSampleCount: Float64
//        public let valid: Array<Bool>
//
//        @inlinable
//        public init(time: CMTime = .zero,
//                    frequency: Array<Float64> = [],
//                    transfer: Array<Complex128> = [],
//                    inputPower: Array<Float64> = [],
//                    outputPower: Array<Float64> = [],
//                    crossSpectrum: Array<Complex128> = [],
//                    coherenceSquared: Array<Float64> = [],
//                    residualPower: Array<Float64> = [],
//                    effectiveSampleCount: Float64 = 0,
//                    valid: Array<Bool> = []) {
//            let count = frequency.count
//            precondition([transfer.count,
//                          inputPower.count,
//                          outputPower.count,
//                          crossSpectrum.count,
//                          coherenceSquared.count,
//                          residualPower.count,
//                          valid.count].allSatisfy { $0 == count })
//            self.time = time
//            self.frequency = frequency
//            self.transfer = transfer
//            self.inputPower = inputPower
//            self.outputPower = outputPower
//            self.crossSpectrum = crossSpectrum
//            self.coherenceSquared = coherenceSquared
//            self.residualPower = residualPower
//            self.effectiveSampleCount = effectiveSampleCount
//            self.valid = valid
//        }
//    }
//}
