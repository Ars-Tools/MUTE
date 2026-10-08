//
//  Model+Cascade+Design.swift
//  MUTE
//
//  Created by Kota on 10/7/26.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Publishers
@preconcurrency import typealias Combine.AnyPublisher
@preconcurrency import typealias Combine.Just
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import protocol DSP.Stream
import typealias DSP.Filter
import typealias DSP.Instance
import protocol DSP.Frequency
import protocol DSP.Duration
import typealias CLK.CMTime
import func DSP.filter
import func DSP.const
import let simd.M_LN10
import let simd.M_LN2
extension Model.Cascade {
    public struct Rn {
        @usableFromInline
        let rawValue: Array<Section>
        public struct Section: Sendable {
            @usableFromInline
            let closure: @Sendable (CMTime) -> AnyPublisher<Model.Biquad, Never>
        }
    }
    public struct Ar {
        @usableFromInline
        let rawValue: Array<Section>
        public struct Section: Sendable {
            @usableFromInline
            let closure: @Sendable (CMTime, Int, inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int, UnsafeMutableBufferPointer<Float64>) -> Void
            @usableFromInline
            init(closure: @escaping @Sendable (CMTime, Int, inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int, UnsafeMutableBufferPointer<Float64>) -> Void) {
                self.closure = closure
            }
        }
    }
}
// MARK: Kr
extension Model.Cascade.Rn: Filter.BiquadSeries {
    public typealias BiquadSeriesCollection = CollectionOfOne<(b: SIMD3<Float64>, a: SIMD3<Float64>)>
    public typealias BiquadSeriesCoefficients = Publishers.MergeMany<Publishers.Map<AnyPublisher<Model.Biquad, Never>, (Range<Int>, BiquadSeriesCollection)>>
    public typealias A = Array<Float64>
    public typealias B = Array<Float64>
    public typealias Scalar = Float64
    @inlinable
    public func coefficients(for Tₛ: CMTime) -> BiquadSeriesCoefficients {
        Publishers.MergeMany(
            rawValue.enumerated().map {
                let range = Range<Int>($0...$0)
                return $1.closure(Tₛ).map { (range, CollectionOfOne(($0.b, $0.a))) }
            }
        )
    }
    @inlinable
    public var count: Int {
        rawValue.count
    }
}
// MARK: Ar
extension Model.Cascade.Ar: DSP.Stream {
    @inlinable
    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let sections = try rawValue.map {
            try $0.closure(interval, capacity, &instance)
        }
        return { moment, length, target, stride in
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
                for (offset, kernel) in sections.enumerated() {
                    kernel(moment, length, target.advanced(by: 6 * offset * stride), stride, $0)
                }
            }
        }
    }
    @inlinable
    public var count: Int {
        6 * rawValue.count
    }
}
// MARK: BPF
extension Model.Cascade.Rn.Section {
    public static func bpf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, Q)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.BPF(ω₀: $0.increment(for: Tₛ), Q: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func bpf(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64
    ) -> Self {
        bpf(ω₀: ω₀, Q: Just(Q))
    }
    @inlinable
    public static func bpf(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        bpf(ω₀: Just(ω₀), Q: Q)
    }
    @inlinable
    public static func bpf(
        ω₀: Frequency,
        Q: Float64
    ) -> Self {
        bpf(ω₀: Just(ω₀), Q: Just(Q))
    }
    public static func bpf(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, BW)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.BPF(ω₀: $0.increment(for: Tₛ), BW: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func bpf(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64
    ) -> Self {
        bpf(ω₀: ω₀, BW: Just(BW))
    }
    @inlinable
    public static func bpf(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        bpf(ω₀: Just(ω₀), BW: BW)
    }
    @inlinable
    public static func bpf(
        ω₀: Frequency,
        BW: Float64
    ) -> Self {
        bpf(ω₀: Just(ω₀), BW: Just(BW))
    }
}
// MARK: LPF
extension Model.Cascade.Rn.Section { // Kr
    public static func lpf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, Q)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.LPF(ω₀: $0.increment(for: Tₛ), Q: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func lpf(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64
    ) -> Self {
        lpf(ω₀: ω₀, Q: Just(Q))
    }
    @inlinable
    public static func lpf(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        lpf(ω₀: Just(ω₀), Q: Q)
    }
    @inlinable
    public static func lpf(
        ω₀: Frequency,
        Q: Float64
    ) -> Self {
        lpf(ω₀: Just(ω₀), Q: Just(Q))
    }
    public static func lpf(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, BW)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.LPF(ω₀: $0.increment(for: Tₛ), BW: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func lpf(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64
    ) -> Self {
        lpf(ω₀: ω₀, BW: Just(BW))
    }
    @inlinable
    public static func lpf(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        lpf(ω₀: Just(ω₀), BW: BW)
    }
    @inlinable
    public static func lpf(
        ω₀: Frequency,
        BW: Float64
    ) -> Self {
        lpf(ω₀: Just(ω₀), BW: Just(BW))
    }
}
// MARK: HPF
extension Model.Cascade.Rn.Section {
    public static func hpf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, Q)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.HPF(ω₀: $0.increment(for: Tₛ), Q: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func hpf(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64
    ) -> Self {
        hpf(ω₀: ω₀, Q: Just(Q))
    }
    @inlinable
    public static func hpf(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        hpf(ω₀: Just(ω₀), Q: Q)
    }
    @inlinable
    public static func hpf(
        ω₀: Frequency,
        Q: Float64
    ) -> Self {
        hpf(ω₀: Just(ω₀), Q: Just(Q))
    }
    public static func hpf(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, BW)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.HPF(ω₀: $0.increment(for: Tₛ), BW: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func hpf(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64
    ) -> Self {
        hpf(ω₀: ω₀, BW: Just(BW))
    }
    @inlinable
    public static func hpf(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        hpf(ω₀: Just(ω₀), BW: BW)
    }
    @inlinable
    public static func hpf(
        ω₀: Frequency,
        BW: Float64
    ) -> Self {
        hpf(ω₀: Just(ω₀), BW: Just(BW))
    }
}
// MARK: APF
extension Model.Cascade.Rn.Section {
    public static func apf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, Q)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.APF(ω₀: $0.increment(for: Tₛ), Q: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func apf(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64
    ) -> Self {
        apf(ω₀: ω₀, Q: Just(Q))
    }
    @inlinable
    public static func apf(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        apf(ω₀: Just(ω₀), Q: Q)
    }
    @inlinable
    public static func apf(
        ω₀: Frequency,
        Q: Float64
    ) -> Self {
        apf(ω₀: Just(ω₀), Q: Just(Q))
    }
    public static func apf(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, BW)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.APF(ω₀: $0.increment(for: Tₛ), BW: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func apf(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64
    ) -> Self {
        apf(ω₀: ω₀, BW: Just(BW))
    }
    @inlinable
    public static func apf(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        apf(ω₀: Just(ω₀), BW: BW)
    }
    @inlinable
    public static func apf(
        ω₀: Frequency,
        BW: Float64
    ) -> Self {
        apf(ω₀: Just(ω₀), BW: Just(BW))
    }
}
// MARK: BSF
extension Model.Cascade.Rn.Section {
    public static func bsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, Q)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.BSF(ω₀: $0.increment(for: Tₛ), Q: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func bsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64
    ) -> Self {
        bsf(ω₀: ω₀, Q: Just(Q))
    }
    @inlinable
    public static func bsf(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        bsf(ω₀: Just(ω₀), Q: Q)
    }
    @inlinable
    public static func bsf(
        ω₀: Frequency,
        Q: Float64
    ) -> Self {
        bsf(ω₀: Just(ω₀), Q: Just(Q))
    }
    public static func bsf(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, BW)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.BSF(ω₀: $0.increment(for: Tₛ), BW: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func bsf(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64
    ) -> Self {
        bsf(ω₀: ω₀, BW: Just(BW))
    }
    @inlinable
    public static func bsf(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        bsf(ω₀: Just(ω₀), BW: BW)
    }
    @inlinable
    public static func bsf(
        ω₀: Frequency,
        BW: Float64
    ) -> Self {
        bsf(ω₀: Just(ω₀), BW: Just(BW))
    }
}
// MARK: LSF
extension Model.Cascade.Rn.Section {
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, Q, dB)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.LSF(ω₀: $0.increment(for: Tₛ), Q: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω₀: ω₀, Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω₀: ω₀, Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω₀: ω₀, Q: Just(Q), dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω₀: Just(ω₀), Q: Q, dB: dB)
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω₀: Just(ω₀), Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω₀: Just(ω₀), Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        Q: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω₀: Just(ω₀), Q: Just(Q), dB: Just(dB))
    }
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, BW, dB)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.LSF(ω₀: $0.increment(for: Tₛ), BW: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω₀: ω₀, BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω₀: ω₀, BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω₀: ω₀, BW: Just(BW), dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω₀: Just(ω₀), BW: BW, dB: dB)
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω₀: Just(ω₀), BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω₀: Just(ω₀), BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        BW: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω₀: Just(ω₀), BW: Just(BW), dB: Just(dB))
    }
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, S, dB)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.LSF(ω₀: $0.increment(for: Tₛ), S: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω₀: ω₀, S: S, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω₀: ω₀, S: Just(S), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        S: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω₀: ω₀, S: Just(S), dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω₀: Just(ω₀), S: S, dB: dB)
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω₀: Just(ω₀), S: S, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω₀: Just(ω₀), S: Just(S), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω₀: Frequency,
        S: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω₀: Just(ω₀), S: Just(S), dB: Just(dB))
    }
}
// MARK: HSF
extension Model.Cascade.Rn.Section {
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, Q, dB)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.HSF(ω₀: $0.increment(for: Tₛ), Q: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω₀: ω₀, Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω₀: ω₀, Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω₀: ω₀, Q: Just(Q), dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω₀: Just(ω₀), Q: Q, dB: dB)
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω₀: Just(ω₀), Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω₀: Just(ω₀), Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        Q: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω₀: Just(ω₀), Q: Just(Q), dB: Just(dB))
    }
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, BW, dB)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.HSF(ω₀: $0.increment(for: Tₛ), BW: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω₀: ω₀, BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω₀: ω₀, BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω₀: ω₀, BW: Just(BW), dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω₀: Just(ω₀), BW: BW, dB: dB)
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω₀: Just(ω₀), BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω₀: Just(ω₀), BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        BW: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω₀: Just(ω₀), BW: Just(BW), dB: Just(dB))
    }
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, S, dB)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.HSF(ω₀: $0.increment(for: Tₛ), S: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω₀: ω₀, S: S, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω₀: ω₀, S: Just(S), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        S: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω₀: ω₀, S: Just(S), dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω₀: Just(ω₀), S: S, dB: dB)
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω₀: Just(ω₀), S: S, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω₀: Just(ω₀), S: Just(S), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω₀: Frequency,
        S: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω₀: Just(ω₀), S: Just(S), dB: Just(dB))
    }
}
// MARK: PEQ
extension Model.Cascade.Rn.Section {
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, Q, dB)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.PEQ(ω₀: $0.increment(for: Tₛ), Q: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω₀: ω₀, Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω₀: ω₀, Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: Float64
    ) -> Self {
        peq(ω₀: ω₀, Q: Just(Q), dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω₀: Just(ω₀), Q: Q, dB: dB)
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω₀: Just(ω₀), Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω₀: Just(ω₀), Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        Q: Float64,
        dB: Float64
    ) -> Self {
        peq(ω₀: Just(ω₀), Q: Just(Q), dB: Just(dB))
    }
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, BW, dB)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.PEQ(ω₀: $0.increment(for: Tₛ), BW: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω₀: ω₀, BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω₀: ω₀, BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: Float64
    ) -> Self {
        peq(ω₀: ω₀, BW: Just(BW), dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω₀: Just(ω₀), BW: BW, dB: dB)
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω₀: Just(ω₀), BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω₀: Just(ω₀), BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        BW: Float64,
        dB: Float64
    ) -> Self {
        peq(ω₀: Just(ω₀), BW: Just(BW), dB: Just(dB))
    }
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, S, dB)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.PEQ(ω₀: $0.increment(for: Tₛ), S: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω₀: ω₀, S: S, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω₀: ω₀, S: Just(S), dB: dB)
    }
    @inlinable
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        S: Float64,
        dB: Float64
    ) -> Self {
        peq(ω₀: ω₀, S: Just(S), dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω₀: Just(ω₀), S: S, dB: dB)
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω₀: Just(ω₀), S: S, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω₀: Just(ω₀), S: Just(S), dB: dB)
    }
    @inlinable
    public static func peq(
        ω₀: Frequency,
        S: Float64,
        dB: Float64
    ) -> Self {
        peq(ω₀: Just(ω₀), S: Just(S), dB: Just(dB))
    }
}
// MARK: EMA
extension Model.Cascade.Rn.Section {
    public static func ema(
        dB attenuation: some Publisher<Float64, Never>,
        in samples: some Publisher<DSP.Duration, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(attenuation, samples)
        return.init { Tₛ in
            latest.map {
                Model.Biquad.EMA(dB: $0, in: $1.samples(for: Tₛ))
            }.eraseToAnyPublisher()
        }
    }
}
// MARK: RAW
extension Model.Cascade.Rn.Section {
    public static func raw(_ object: Model.Biquad) -> Self {
        let raw = Just(object).eraseToAnyPublisher()
        return.init { Tₛ in
            raw
        }
    }
    public static func raw(b: SIMD3<Float64>, a: SIMD3<Float64>) -> Self {
        .raw(.init(b: b, a: a))
    }
    public static let identity = .raw(b: .init(1, 0, 0), a: .init(1, 0, 0)) as Self
}
public func filter(_ source: Stream, sos series: some Sequence<Model.Cascade.Rn.Section> & Sendable) -> some Stream {
    filter(source, sos: Model.Cascade.Rn(rawValue: .init(series)))
}
@inlinable@_disfavoredOverload
public func filter(_ source: Stream, sos series: Model.Cascade.Rn.Section...) -> some Stream {
    filter(source, sos: series)
}
public func filter(_ source: Stream, sos series: some Sequence<Model.Cascade.Ar.Section>) -> some Stream {
    filter(source, sos: Model.Cascade.Ar(rawValue: .init(series)))
}
@inlinable@_disfavoredOverload
public func filter(_ source: Stream, sos series: Model.Cascade.Ar.Section...) -> some Stream {
    filter(source, sos: series)
}
// MARK: Ar
extension Model.Cascade.Ar.Section {
    @usableFromInline
    typealias Kernel = @Sendable (
        CMTime, Int, UnsafeMutablePointer<Float64>, Int
    ) -> Void
    @usableFromInline
    // Cascade aliases Array<Biquad>, so nested protocols are unavailable.
    // Function plans keep coefficient design within Section.
    typealias PassWidthPlan = @Sendable (
        Kernel, CMTime, Int, inout Workspace
    ) -> Void
    @usableFromInline
    struct Workspace: ~Copyable {
        @usableFromInline var x0: UnsafeMutableBufferPointer<Float64>
        @usableFromInline var x1: UnsafeMutableBufferPointer<Float64>
        @usableFromInline var x2: UnsafeMutableBufferPointer<Float64>
        @usableFromInline var x3: UnsafeMutableBufferPointer<Float64>
        @usableFromInline var x4: UnsafeMutableBufferPointer<Float64>
        @usableFromInline var x5: UnsafeMutableBufferPointer<Float64>
        @inlinable@inline(__always)@_transparent
        init(_ workspace: UnsafeMutableBufferPointer<Float64>, length: Int) {
            x0 = .init(rebasing: workspace[0 * length ..< 1 * length])
            x1 = .init(rebasing: workspace[1 * length ..< 2 * length])
            x2 = .init(rebasing: workspace[2 * length ..< 3 * length])
            x3 = .init(rebasing: workspace[3 * length ..< 4 * length])
            x4 = .init(rebasing: workspace[4 * length ..< 5 * length])
            x5 = .init(rebasing: workspace[5 * length ..< 6 * length])
        }
    }
    @usableFromInline
    struct Coefficients: ~Copyable {
        @usableFromInline var b0: UnsafeMutableBufferPointer<Float64>
        @usableFromInline var b1: UnsafeMutableBufferPointer<Float64>
        @usableFromInline var b2: UnsafeMutableBufferPointer<Float64>
        @usableFromInline var a0: UnsafeMutableBufferPointer<Float64>
        @usableFromInline var a1: UnsafeMutableBufferPointer<Float64>
        @usableFromInline var a2: UnsafeMutableBufferPointer<Float64>
        @inlinable@inline(__always)@_transparent
        init(_ target: UnsafeMutablePointer<Float64>, stride: Int, length: Int) {
            b0 = .init(start: target.advanced(by: 0 * stride), count: length)
            b1 = .init(start: target.advanced(by: 1 * stride), count: length)
            b2 = .init(start: target.advanced(by: 2 * stride), count: length)
            a0 = .init(start: target.advanced(by: 3 * stride), count: length)
            a1 = .init(start: target.advanced(by: 4 * stride), count: length)
            a2 = .init(start: target.advanced(by: 5 * stride), count: length)
        }
    }
}
extension Model.Cascade.Ar.Section {
    @usableFromInline
    static let bandwidth = 0.5 * M_LN2
    @usableFromInline
    static let gain = 0.025 * M_LN10
    @usableFromInline
    static let gainln2 = gain / M_LN2
}
extension Model.Cascade.Ar.Section {
    @inlinable@inline(__always)@_transparent
    static func copy(
        _ source: UnsafeMutableBufferPointer<Float64>,
        _ target: UnsafeMutableBufferPointer<Float64>
    ) {
        switch target.initialize(fromContentsOf: source) {
        case let eof:
            assert(target.startIndex.distance(to: eof) == source.count)
        }
    }
    @inlinable@inline(__always)@_transparent
    static func α(
        BW kernel: Kernel,
        moment: CMTime,
        length: Int,
        workspace: inout Workspace
    ) {
        // ω = 2θ; α_BW = sin(ω) sinh((ln(2)/2) BW ω/sin(ω)).
        // sinc(2θ) = sin(2θ)/(2θ) = sin(θ)cos(θ)/θ.
        vDSP.multiply(workspace.x1, workspace.x2, result: &workspace.x3)
        kernel(moment, length, workspace.x4.baseAddress.unsafelyUnwrapped, length)
        vDSP.multiply(bandwidth, workspace.x4, result: &workspace.x4)
        vDSP.multiply(workspace.x0, workspace.x4, result: &workspace.x4)
        vDSP.divide(workspace.x4, workspace.x3, result: &workspace.x4)
        vForce.sinh(workspace.x4, result: &workspace.x4)
        vDSP.multiply(workspace.x3, workspace.x4, result: &workspace.x3)
        vDSP.multiply(2, workspace.x3, result: &workspace.x3)
    }
    @inlinable@inline(__always)@_transparent
    static func α(
        Q kernel: Kernel,
        moment: CMTime,
        length: Int,
        workspace: inout Workspace
    ) {
        // ω = 2θ; α_Q = sin(ω)/(2Q).
        kernel(moment, length, workspace.x0.baseAddress.unsafelyUnwrapped, length)
        vDSP.divide(workspace.x2, workspace.x0, result: &workspace.x0)
        vDSP.multiply(workspace.x1, workspace.x0, result: &workspace.x3)
    }
    @inlinable@inline(__always)@_transparent
    static func halfAngle(
        _ kernel: Kernel,
        moment: CMTime,
        length: Int,
        factor: Float64,
        workspace: inout Workspace
    ) {
        kernel(moment, length, workspace.x0.baseAddress.unsafelyUnwrapped, length)
        vDSP.multiply(factor, workspace.x0, result: &workspace.x0)
        vForce.sincos(workspace.x0, sinResult: &workspace.x1, cosResult: &workspace.x2)
    }
}

extension Model.Cascade.Ar.Section {
    @usableFromInline
    typealias PassPlan = @Sendable (inout Workspace, inout Coefficients) -> Void

    @inlinable@inline(__always)@_transparent
    static func lowPassNumerator(workspace w: inout Workspace, coefficients z: inout Coefficients) {
        vDSP.multiply(w.x1, w.x1, result: &z.b0)
        vDSP.multiply(2, z.b0, result: &z.b1)
        copy(z.b0, z.b2)
        vDSP.add(multiplication: (z.b0, 4), -2, result: &z.a1)
    }

    @inlinable@inline(__always)@_transparent
    static func highPassNumerator(workspace w: inout Workspace, coefficients z: inout Coefficients) {
        vDSP.multiply(w.x2, w.x2, result: &z.b0)
        vDSP.multiply(-2, z.b0, result: &z.b1)
        copy(z.b0, z.b2)
        vDSP.multiply(w.x1, w.x1, result: &w.x4)
        vDSP.add(multiplication: (w.x4, 4), -2, result: &z.a1)
    }

    @inlinable@inline(__always)@_transparent
    static func bandPassNumerator(workspace w: inout Workspace, coefficients z: inout Coefficients) {
        copy(w.x3, z.b0)
        vDSP.clear(&z.b1)
        vDSP.negative(w.x3, result: &z.b2)
        vDSP.multiply(w.x1, w.x1, result: &w.x4)
        vDSP.add(multiplication: (w.x4, 4), -2, result: &z.a1)
    }

    @inlinable@inline(__always)@_transparent
    static func bandStopNumerator(workspace w: inout Workspace, coefficients z: inout Coefficients) {
        vDSP.fill(&z.b0, with: 1)
        vDSP.fill(&z.b2, with: 1)
        vDSP.multiply(w.x1, w.x1, result: &w.x4)
        vDSP.add(multiplication: (w.x4, 4), -2, result: &z.a1)
        copy(z.a1, z.b1)
    }

    @inlinable@inline(__always)@_transparent
    static func allPassNumerator(workspace w: inout Workspace, coefficients z: inout Coefficients) {
        vDSP.multiply(w.x1, w.x1, result: &w.x4)
        vDSP.add(multiplication: (w.x4, 4), -2, result: &z.a1)
        copy(z.a2, z.b0)
        copy(z.a1, z.b1)
        copy(z.a0, z.b2)
    }

    @inlinable@inline(__always)@_transparent
    static func denominator(workspace w: inout Workspace, coefficients z: inout Coefficients) {
        vDSP.fill(&w.x5, with: 1)
        vDSP.addSubtract(w.x5, w.x3, addResult: &z.a0, subtractResult: &z.a2)
    }

    @usableFromInline
    typealias ShelfWidthPlan = @Sendable (
        Kernel, CMTime, Int, inout Workspace, inout Coefficients
    ) -> Void

    @inlinable@inline(__always)@_transparent
    static func qualityShelfWidth(_ kernel: Kernel, moment: CMTime, length: Int, workspace w: inout Workspace, coefficients z: inout Coefficients) {
        kernel(moment, length, z.a0.baseAddress.unsafelyUnwrapped, length)
        vForce.sqrt(w.x5, result: &z.b2)
        vDSP.divide(z.b2, z.a0, result: &z.b2)
        vDSP.multiply(w.x2, z.b2, result: &z.b2)
        vDSP.multiply(w.x1, z.b2, result: &z.a2)
    }

    @inlinable@inline(__always)@_transparent
    static func bandwidthShelfWidth(_ kernel: Kernel, moment: CMTime, length: Int, workspace w: inout Workspace, coefficients z: inout Coefficients) {
        vDSP.multiply(w.x1, w.x2, result: &z.a2)
        kernel(moment, length, z.a0.baseAddress.unsafelyUnwrapped, length)
        vDSP.multiply(bandwidth, z.a0, result: &z.a0)
        vDSP.multiply(w.x0, z.a0, result: &z.a0)
        vDSP.divide(z.a0, z.a2, result: &z.a0)
        vForce.sinh(z.a0, result: &z.a0)
        vDSP.multiply(2, z.a0, result: &z.a0)
        vForce.sqrt(w.x5, result: &z.b2)
        vDSP.multiply(z.b2, z.a0, result: &z.a0)
        vDSP.multiply(z.a2, z.a0, result: &z.a2)
    }

    @inlinable@inline(__always)@_transparent
    static func slopeShelfWidth(_ kernel: Kernel, moment: CMTime, length: Int, workspace w: inout Workspace, coefficients z: inout Coefficients) {
        kernel(moment, length, z.a0.baseAddress.unsafelyUnwrapped, length)
        vDSP.divide(1, z.a0, result: &z.a0)
        vDSP.add(-1, z.a0, result: &z.a0)
        vDSP.add(multiplication: (w.x5, w.x5), 1, result: &z.b2)
        vDSP.multiply(z.b2, z.a0, result: &z.b2)
        vDSP.add(multiplication: (w.x5, 2), z.b2, result: &z.b2)
        vForce.sqrt(z.b2, result: &z.b2)
        vDSP.multiply(w.x1, w.x2, result: &z.a2)
        vDSP.multiply(z.a2, z.b2, result: &z.a2)
    }

    @usableFromInline
    typealias ShelfPlan = @Sendable (inout Workspace, inout Coefficients) -> Void

    @inlinable@inline(__always)@_transparent
    static func lowShelfCoefficients(workspace w: inout Workspace, coefficients z: inout Coefficients) {
        copy(z.a2, w.x0)
        vDSP.multiply(w.x4, w.x3, result: &z.b2)
        vDSP.add(1, z.b2, result: &w.x1)
        vDSP.add(multiplication: (z.b2, -1), w.x5, result: &w.x2)
        vDSP.add(1, w.x5, result: &z.b2)
        vDSP.add(multiplication: (z.b2, w.x3), -1, result: &z.b1)
        vDSP.multiply(z.b2, w.x3, result: &z.a1)
        vDSP.add(multiplication: (z.a1, -1), w.x5, result: &z.a1)
        vDSP.multiply(2, z.b1, result: &z.b1)
        vDSP.multiply(-2, z.a1, result: &z.a1)
        vDSP.addSubtract(w.x1, w.x0, addResult: &z.b0, subtractResult: &z.b2)
        vDSP.addSubtract(w.x2, w.x0, addResult: &z.a0, subtractResult: &z.a2)
        vDSP.multiply(w.x5, z.b0, result: &z.b0)
        vDSP.multiply(w.x5, z.b1, result: &z.b1)
        vDSP.multiply(w.x5, z.b2, result: &z.b2)
    }

    @inlinable@inline(__always)@_transparent
    static func highShelfCoefficients(workspace w: inout Workspace, coefficients z: inout Coefficients) {
        copy(z.a2, w.x0)
        vDSP.multiply(w.x4, w.x3, result: &z.b2)
        vDSP.add(multiplication: (z.b2, -1), w.x5, result: &w.x1)
        vDSP.add(1, z.b2, result: &w.x2)
        vDSP.add(1, w.x5, result: &z.b2)
        vDSP.multiply(z.b2, w.x3, result: &z.b1)
        vDSP.add(multiplication: (z.b1, -1), w.x5, result: &z.b1)
        vDSP.add(multiplication: (z.b2, w.x3), -1, result: &z.a1)
        vDSP.multiply(-2, z.b1, result: &z.b1)
        vDSP.multiply(2, z.a1, result: &z.a1)
        vDSP.addSubtract(w.x1, w.x0, addResult: &z.b0, subtractResult: &z.b2)
        vDSP.addSubtract(w.x2, w.x0, addResult: &z.a0, subtractResult: &z.a2)
        vDSP.multiply(w.x5, z.b0, result: &z.b0)
        vDSP.multiply(w.x5, z.b1, result: &z.b1)
        vDSP.multiply(w.x5, z.b2, result: &z.b2)
    }

    @inlinable@inline(__always)@_transparent
    static func α(S kernel: Kernel, moment: CMTime, length: Int, workspace w: inout Workspace) {
        // ω = 2θ; A = 10^(dB/40); α_S = sin(ω)/2 sqrt((A + 1/A)(1/S - 1) + 2).
        kernel(moment, length, w.x4.baseAddress.unsafelyUnwrapped, length)
        vDSP.divide(1, w.x4, result: &w.x4)
        vDSP.add(-1, w.x4, result: &w.x4)
        vDSP.divide(1, w.x5, result: &w.x0)
        vDSP.add(w.x5, w.x0, result: &w.x0)
        vDSP.multiply(w.x0, w.x4, result: &w.x0)
        vDSP.add(2, w.x0, result: &w.x0)
        vForce.sqrt(w.x0, result: &w.x0)
        vDSP.multiply(w.x1, w.x2, result: &w.x3)
        vDSP.multiply(w.x3, w.x0, result: &w.x3)
    }
}

extension Model.Cascade.Ar.Section {
    @inlinable@inline(__always)@_transparent
    static func pass(
        _ numerator: @escaping PassPlan,
        _ alpha: @escaping PassWidthPlan,
        ω₀: Stream,
        width: Stream
    ) -> Self {
        .init { interval, capacity, instance in
            guard ω₀.count == 1, width.count == 1 else {
                throw Error.unmatchChannel
            }
            let ω₀k = try ω₀(interval: interval, capacity: capacity, instance: &instance)
            let widthk = try width(interval: interval, capacity: capacity, instance: &instance)
            let factor = .pi * interval.seconds
            return { moment, length, target, stride, workspace in
                var w = Workspace(workspace, length: length)
                var z = Coefficients(target, stride: stride, length: length)
                halfAngle(ω₀k, moment: moment, length: length, factor: factor, workspace: &w)
                alpha(widthk, moment, length, &w)
                denominator(workspace: &w, coefficients: &z)
                numerator(&w, &z)
            }
        }
    }

    @inlinable@inline(__always)@_transparent
    static func shelf(
        _ coefficients: @escaping ShelfPlan,
        _ resonance: @escaping ShelfWidthPlan,
        ω₀: Stream,
        width: Stream,
        dB: Stream
    ) -> Self {
        .init { interval, capacity, instance in
            guard ω₀.count == 1, width.count == 1, dB.count == 1 else {
                throw Error.unmatchChannel
            }
            let ω₀k = try ω₀(interval: interval, capacity: capacity, instance: &instance)
            let widthk = try width(interval: interval, capacity: capacity, instance: &instance)
            let dBk = try dB(interval: interval, capacity: capacity, instance: &instance)
            let factor = .pi * interval.seconds
            return { moment, length, target, stride, workspace in
                var w = Workspace(workspace, length: length)
                var z = Coefficients(target, stride: stride, length: length)
                halfAngle(ω₀k, moment: moment, length: length, factor: factor, workspace: &w)
                vDSP.multiply(w.x1, w.x1, result: &w.x3)
                dBk(moment, length, w.x4.baseAddress.unsafelyUnwrapped, length)
                vDSP.multiply(gain, w.x4, result: &w.x4)
                vForce.expm1(w.x4, result: &w.x4)
                vDSP.add(1, w.x4, result: &w.x5)
                resonance(widthk, moment, length, &w, &z)
                coefficients(&w, &z)
            }
        }
    }

    @inlinable@inline(__always)@_transparent
    static func equalizer(
        _ alpha: @escaping PassWidthPlan,
        ω₀: Stream,
        width: Stream,
        dB: Stream
    ) -> Self {
        .init { interval, capacity, instance in
            guard ω₀.count == 1, width.count == 1, dB.count == 1 else {
                throw Error.unmatchChannel
            }
            let ω₀k = try ω₀(interval: interval, capacity: capacity, instance: &instance)
            let widthk = try width(interval: interval, capacity: capacity, instance: &instance)
            let dBk = try dB(interval: interval, capacity: capacity, instance: &instance)
            let factor = .pi * interval.seconds
            return { moment, length, target, stride, workspace in
                var w = Workspace(workspace, length: length)
                var z = Coefficients(target, stride: stride, length: length)
                halfAngle(ω₀k, moment: moment, length: length, factor: factor, workspace: &w)
                dBk(moment, length, w.x5.baseAddress.unsafelyUnwrapped, length)
                vDSP.multiply(gainln2, w.x5, result: &w.x5)
                vForce.exp2(w.x5, result: &w.x5)
                alpha(widthk, moment, length, &w)
                vDSP.fill(&z.b1, with: 1)
                vDSP.multiply(w.x3, w.x5, result: &w.x4)
                vDSP.addSubtract(z.b1, w.x4, addResult: &z.b0, subtractResult: &z.b2)
                vDSP.divide(w.x3, w.x5, result: &w.x4)
                vDSP.addSubtract(z.b1, w.x4, addResult: &z.a0, subtractResult: &z.a2)
                vDSP.multiply(w.x1, w.x1, result: &w.x4)
                vDSP.add(multiplication: (w.x4, 4), -2, result: &z.a1)
                copy(z.a1, z.b1)
            }
        }
    }
}

// MARK: - LPF / HPF / BPF / BSF / APF
extension Model.Cascade.Ar.Section {
    @inlinable@inline(__always)@_transparent
    public static func lpf(ω₀: Stream, Q: Stream) -> Self { pass(lowPassNumerator, α(Q:moment:length:workspace:), ω₀: ω₀, width: Q) }
    @inlinable@inline(__always)@_transparent
    public static func lpf(ω₀: Stream, BW: Stream) -> Self { pass(lowPassNumerator, α(BW:moment:length:workspace:), ω₀: ω₀, width: BW) }
    @inlinable@inline(__always)@_transparent
    public static func hpf(ω₀: Stream, Q: Stream) -> Self { pass(highPassNumerator, α(Q:moment:length:workspace:), ω₀: ω₀, width: Q) }
    @inlinable@inline(__always)@_transparent
    public static func hpf(ω₀: Stream, BW: Stream) -> Self { pass(highPassNumerator, α(BW:moment:length:workspace:), ω₀: ω₀, width: BW) }
    @inlinable@inline(__always)@_transparent
    public static func bpf(ω₀: Stream, Q: Stream) -> Self { pass(bandPassNumerator, α(Q:moment:length:workspace:), ω₀: ω₀, width: Q) }
    @inlinable@inline(__always)@_transparent
    public static func bpf(ω₀: Stream, BW: Stream) -> Self { pass(bandPassNumerator, α(BW:moment:length:workspace:), ω₀: ω₀, width: BW) }
    @inlinable@inline(__always)@_transparent
    public static func bsf(ω₀: Stream, Q: Stream) -> Self { pass(bandStopNumerator, α(Q:moment:length:workspace:), ω₀: ω₀, width: Q) }
    @inlinable@inline(__always)@_transparent
    public static func bsf(ω₀: Stream, BW: Stream) -> Self { pass(bandStopNumerator, α(BW:moment:length:workspace:), ω₀: ω₀, width: BW) }
    @inlinable@inline(__always)@_transparent
    public static func apf(ω₀: Stream, Q: Stream) -> Self { pass(allPassNumerator, α(Q:moment:length:workspace:), ω₀: ω₀, width: Q) }
    @inlinable@inline(__always)@_transparent
    public static func apf(ω₀: Stream, BW: Stream) -> Self { pass(allPassNumerator, α(BW:moment:length:workspace:), ω₀: ω₀, width: BW) }
}

// MARK: - LSF / HSF / PEQ
extension Model.Cascade.Ar.Section {
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, Q: Stream, dB: Stream) -> Self { shelf(lowShelfCoefficients, qualityShelfWidth, ω₀: ω₀, width: Q, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, BW: Stream, dB: Stream) -> Self { shelf(lowShelfCoefficients, bandwidthShelfWidth, ω₀: ω₀, width: BW, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, S: Stream, dB: Stream) -> Self { shelf(lowShelfCoefficients, slopeShelfWidth, ω₀: ω₀, width: S, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, Q: Stream, dB: Stream) -> Self { shelf(highShelfCoefficients, qualityShelfWidth, ω₀: ω₀, width: Q, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, BW: Stream, dB: Stream) -> Self { shelf(highShelfCoefficients, bandwidthShelfWidth, ω₀: ω₀, width: BW, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, S: Stream, dB: Stream) -> Self { shelf(highShelfCoefficients, slopeShelfWidth, ω₀: ω₀, width: S, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, Q: Stream, dB: Stream) -> Self { equalizer(α(Q:moment:length:workspace:), ω₀: ω₀, width: Q, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, BW: Stream, dB: Stream) -> Self { equalizer(α(BW:moment:length:workspace:), ω₀: ω₀, width: BW, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, S: Stream, dB: Stream) -> Self { equalizer(α(S:moment:length:workspace:), ω₀: ω₀, width: S, dB: dB) }
}

// MARK: - Constant audio-rate adapters
extension Model.Cascade.Ar.Section {
    @inlinable@inline(__always)@_transparent
    public static func lpf(ω₀: Stream, Q: Float64) -> Self { lpf(ω₀: ω₀, Q: const(Q)) }
    @inlinable@inline(__always)@_transparent
    public static func lpf(ω₀: Float64, Q: Stream) -> Self { lpf(ω₀: const(ω₀), Q: Q) }
    @inlinable@inline(__always)@_transparent
    public static func lpf(ω₀: Float64, Q: Float64) -> Self { lpf(ω₀: const(ω₀), Q: const(Q)) }
    @inlinable@inline(__always)@_transparent
    public static func lpf(ω₀: Stream, BW: Float64) -> Self { lpf(ω₀: ω₀, BW: const(BW)) }
    @inlinable@inline(__always)@_transparent
    public static func lpf(ω₀: Float64, BW: Stream) -> Self { lpf(ω₀: const(ω₀), BW: BW) }
//    public static func lpf(ω₀: Float64, BW: Float64) -> Self { lpf(ω₀: const(ω₀), BW: const(BW)) }
    @inlinable@inline(__always)@_transparent
    public static func hpf(ω₀: Stream, Q: Float64) -> Self { hpf(ω₀: ω₀, Q: const(Q)) }
    @inlinable@inline(__always)@_transparent
    public static func hpf(ω₀: Float64, Q: Stream) -> Self { hpf(ω₀: const(ω₀), Q: Q) }
    @inlinable@inline(__always)@_transparent
    public static func hpf(ω₀: Float64, Q: Float64) -> Self { hpf(ω₀: const(ω₀), Q: const(Q)) }
    @inlinable@inline(__always)@_transparent
    public static func hpf(ω₀: Stream, BW: Float64) -> Self { hpf(ω₀: ω₀, BW: const(BW)) }
    @inlinable@inline(__always)@_transparent
    public static func hpf(ω₀: Float64, BW: Stream) -> Self { hpf(ω₀: const(ω₀), BW: BW) }
//    public static func hpf(ω₀: Float64, BW: Float64) -> Self { hpf(ω₀: const(ω₀), BW: const(BW)) }
    @inlinable@inline(__always)@_transparent
    public static func bpf(ω₀: Stream, Q: Float64) -> Self { bpf(ω₀: ω₀, Q: const(Q)) }
    @inlinable@inline(__always)@_transparent
    public static func bpf(ω₀: Float64, Q: Stream) -> Self { bpf(ω₀: const(ω₀), Q: Q) }
    @inlinable@inline(__always)@_transparent
    public static func bpf(ω₀: Float64, Q: Float64) -> Self { bpf(ω₀: const(ω₀), Q: const(Q)) }
    @inlinable@inline(__always)@_transparent
    public static func bpf(ω₀: Stream, BW: Float64) -> Self { bpf(ω₀: ω₀, BW: const(BW)) }
    @inlinable@inline(__always)@_transparent
    public static func bpf(ω₀: Float64, BW: Stream) -> Self { bpf(ω₀: const(ω₀), BW: BW) }
//    public static func bpf(ω₀: Float64, BW: Float64) -> Self { bpf(ω₀: const(ω₀), BW: const(BW)) }
    @inlinable@inline(__always)@_transparent
    public static func bsf(ω₀: Stream, Q: Float64) -> Self { bsf(ω₀: ω₀, Q: const(Q)) }
    @inlinable@inline(__always)@_transparent
    public static func bsf(ω₀: Float64, Q: Stream) -> Self { bsf(ω₀: const(ω₀), Q: Q) }
    @inlinable@inline(__always)@_transparent
    public static func bsf(ω₀: Float64, Q: Float64) -> Self { bsf(ω₀: const(ω₀), Q: const(Q)) }
    @inlinable@inline(__always)@_transparent
    public static func bsf(ω₀: Stream, BW: Float64) -> Self { bsf(ω₀: ω₀, BW: const(BW)) }
    @inlinable@inline(__always)@_transparent
    public static func bsf(ω₀: Float64, BW: Stream) -> Self { bsf(ω₀: const(ω₀), BW: BW) }
//    public static func bsf(ω₀: Float64, BW: Float64) -> Self { bsf(ω₀: const(ω₀), BW: const(BW)) }
    @inlinable@inline(__always)@_transparent
    public static func apf(ω₀: Stream, Q: Float64) -> Self { apf(ω₀: ω₀, Q: const(Q)) }
    @inlinable@inline(__always)@_transparent
    public static func apf(ω₀: Float64, Q: Stream) -> Self { apf(ω₀: const(ω₀), Q: Q) }
    @inlinable@inline(__always)@_transparent
    public static func apf(ω₀: Float64, Q: Float64) -> Self { apf(ω₀: const(ω₀), Q: const(Q)) }
    @inlinable@inline(__always)@_transparent
    public static func apf(ω₀: Stream, BW: Float64) -> Self { apf(ω₀: ω₀, BW: const(BW)) }
    @inlinable@inline(__always)@_transparent
    public static func apf(ω₀: Float64, BW: Stream) -> Self { apf(ω₀: const(ω₀), BW: BW) }
//    public static func apf(ω₀: Float64, BW: Float64) -> Self { apf(ω₀: const(ω₀), BW: const(BW)) }

    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, Q: Stream, dB: Float64) -> Self { lsf(ω₀: ω₀, Q: Q, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, Q: Float64, dB: Stream) -> Self { lsf(ω₀: ω₀, Q: const(Q), dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, Q: Float64, dB: Float64) -> Self { lsf(ω₀: ω₀, Q: const(Q), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Float64, Q: Stream, dB: Stream) -> Self { lsf(ω₀: const(ω₀), Q: Q, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Float64, Q: Stream, dB: Float64) -> Self { lsf(ω₀: const(ω₀), Q: Q, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Float64, Q: Float64, dB: Stream) -> Self { lsf(ω₀: const(ω₀), Q: const(Q), dB: dB) }
//    public static func lsf(ω₀: Float64, Q: Float64, dB: Float64) -> Self { lsf(ω₀: const(ω₀), Q: const(Q), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, BW: Stream, dB: Float64) -> Self { lsf(ω₀: ω₀, BW: BW, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, BW: Float64, dB: Stream) -> Self { lsf(ω₀: ω₀, BW: const(BW), dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, BW: Float64, dB: Float64) -> Self { lsf(ω₀: ω₀, BW: const(BW), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Float64, BW: Stream, dB: Stream) -> Self { lsf(ω₀: const(ω₀), BW: BW, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Float64, BW: Stream, dB: Float64) -> Self { lsf(ω₀: const(ω₀), BW: BW, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Float64, BW: Float64, dB: Stream) -> Self { lsf(ω₀: const(ω₀), BW: const(BW), dB: dB) }
//    public static func lsf(ω₀: Float64, BW: Float64, dB: Float64) -> Self { lsf(ω₀: const(ω₀), BW: const(BW), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, S: Stream, dB: Float64) -> Self { lsf(ω₀: ω₀, S: S, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, S: Float64, dB: Stream) -> Self { lsf(ω₀: ω₀, S: const(S), dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Stream, S: Float64, dB: Float64) -> Self { lsf(ω₀: ω₀, S: const(S), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Float64, S: Stream, dB: Stream) -> Self { lsf(ω₀: const(ω₀), S: S, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Float64, S: Stream, dB: Float64) -> Self { lsf(ω₀: const(ω₀), S: S, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func lsf(ω₀: Float64, S: Float64, dB: Stream) -> Self { lsf(ω₀: const(ω₀), S: const(S), dB: dB) }
//    public static func lsf(ω₀: Float64, S: Float64, dB: Float64) -> Self { lsf(ω₀: const(ω₀), S: const(S), dB: const(dB)) }

    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, Q: Stream, dB: Float64) -> Self { hsf(ω₀: ω₀, Q: Q, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, Q: Float64, dB: Stream) -> Self { hsf(ω₀: ω₀, Q: const(Q), dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, Q: Float64, dB: Float64) -> Self { hsf(ω₀: ω₀, Q: const(Q), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Float64, Q: Stream, dB: Stream) -> Self { hsf(ω₀: const(ω₀), Q: Q, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Float64, Q: Stream, dB: Float64) -> Self { hsf(ω₀: const(ω₀), Q: Q, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Float64, Q: Float64, dB: Stream) -> Self { hsf(ω₀: const(ω₀), Q: const(Q), dB: dB) }
//    public static func hsf(ω₀: Float64, Q: Float64, dB: Float64) -> Self { hsf(ω₀: const(ω₀), Q: const(Q), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, BW: Stream, dB: Float64) -> Self { hsf(ω₀: ω₀, BW: BW, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, BW: Float64, dB: Stream) -> Self { hsf(ω₀: ω₀, BW: const(BW), dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, BW: Float64, dB: Float64) -> Self { hsf(ω₀: ω₀, BW: const(BW), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Float64, BW: Stream, dB: Stream) -> Self { hsf(ω₀: const(ω₀), BW: BW, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Float64, BW: Stream, dB: Float64) -> Self { hsf(ω₀: const(ω₀), BW: BW, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Float64, BW: Float64, dB: Stream) -> Self { hsf(ω₀: const(ω₀), BW: const(BW), dB: dB) }
//    public static func hsf(ω₀: Float64, BW: Float64, dB: Float64) -> Self { hsf(ω₀: const(ω₀), BW: const(BW), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, S: Stream, dB: Float64) -> Self { hsf(ω₀: ω₀, S: S, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, S: Float64, dB: Stream) -> Self { hsf(ω₀: ω₀, S: const(S), dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Stream, S: Float64, dB: Float64) -> Self { hsf(ω₀: ω₀, S: const(S), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Float64, S: Stream, dB: Stream) -> Self { hsf(ω₀: const(ω₀), S: S, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Float64, S: Stream, dB: Float64) -> Self { hsf(ω₀: const(ω₀), S: S, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func hsf(ω₀: Float64, S: Float64, dB: Stream) -> Self { hsf(ω₀: const(ω₀), S: const(S), dB: dB) }
//    public static func hsf(ω₀: Float64, S: Float64, dB: Float64) -> Self { hsf(ω₀: const(ω₀), S: const(S), dB: const(dB)) }

    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, Q: Stream, dB: Float64) -> Self { peq(ω₀: ω₀, Q: Q, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, Q: Float64, dB: Stream) -> Self { peq(ω₀: ω₀, Q: const(Q), dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, Q: Float64, dB: Float64) -> Self { peq(ω₀: ω₀, Q: const(Q), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Float64, Q: Stream, dB: Stream) -> Self { peq(ω₀: const(ω₀), Q: Q, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Float64, Q: Stream, dB: Float64) -> Self { peq(ω₀: const(ω₀), Q: Q, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Float64, Q: Float64, dB: Stream) -> Self { peq(ω₀: const(ω₀), Q: const(Q), dB: dB) }
//    public static func peq(ω₀: Float64, Q: Float64, dB: Float64) -> Self { peq(ω₀: const(ω₀), Q: const(Q), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, BW: Stream, dB: Float64) -> Self { peq(ω₀: ω₀, BW: BW, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, BW: Float64, dB: Stream) -> Self { peq(ω₀: ω₀, BW: const(BW), dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, BW: Float64, dB: Float64) -> Self { peq(ω₀: ω₀, BW: const(BW), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Float64, BW: Stream, dB: Stream) -> Self { peq(ω₀: const(ω₀), BW: BW, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Float64, BW: Stream, dB: Float64) -> Self { peq(ω₀: const(ω₀), BW: BW, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Float64, BW: Float64, dB: Stream) -> Self { peq(ω₀: const(ω₀), BW: const(BW), dB: dB) }
//    public static func peq(ω₀: Float64, BW: Float64, dB: Float64) -> Self { peq(ω₀: const(ω₀), BW: const(BW), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, S: Stream, dB: Float64) -> Self { peq(ω₀: ω₀, S: S, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, S: Float64, dB: Stream) -> Self { peq(ω₀: ω₀, S: const(S), dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Stream, S: Float64, dB: Float64) -> Self { peq(ω₀: ω₀, S: const(S), dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Float64, S: Stream, dB: Stream) -> Self { peq(ω₀: const(ω₀), S: S, dB: dB) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Float64, S: Stream, dB: Float64) -> Self { peq(ω₀: const(ω₀), S: S, dB: const(dB)) }
    @inlinable@inline(__always)@_transparent
    public static func peq(ω₀: Float64, S: Float64, dB: Stream) -> Self { peq(ω₀: const(ω₀), S: const(S), dB: dB) }
//    public static func peq(ω₀: Float64, S: Float64, dB: Float64) -> Self { peq(ω₀: const(ω₀), S: const(S), dB: const(dB)) }
}
