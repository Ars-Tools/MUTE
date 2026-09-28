//
//  Special+Cascade.swift
//  MUTE
//
//  Created by Kota on 9/28/26.
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
import typealias CLK.CMTime
import func DSP.filter
import func DSP.stack
extension Filter {
    public enum Cascade {
        public struct Kr {
            @usableFromInline
            let rawValue: Array<Section>
            public struct Section: Sendable {
                @usableFromInline
                let closure: @Sendable (CMTime) -> AnyPublisher<Linear.Biquad, Never>
            }
        }
        public struct Ar {
            @usableFromInline
            let rawValue: Array<Section>
            public struct Section: Sendable {
                @usableFromInline
                let closure: @Sendable (CMTime, Int, inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int, UnsafeMutableBufferPointer<Float64>) -> Void
            }
        }
    }
}
// MARK: Kr
extension Filter.Cascade.Kr: Filter.BiquadSeries {
    public typealias Biquad = CollectionOfOne<(b: SIMD3<Float64>, a: SIMD3<Float64>)>
    public typealias Sections = Publishers.MergeMany<Publishers.Map<AnyPublisher<Linear.Biquad, Never>, (Range<Int>, Biquad)>>
    public typealias A = Array<Float64>
    public typealias B = Array<Float64>
    public typealias Scalar = Float64
    @inlinable
    public func sections(for Tₛ: CMTime) -> Sections {
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
extension Filter.Cascade.Ar: DSP.Stream {
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
extension Filter.Cascade.Kr.Section {
    public static func bpf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, Q)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.BPF(ω₀: $0.increment(for: Tₛ), Q: $1)
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
                Linear.Biquad.BPF(ω₀: $0.increment(for: Tₛ), BW: $1)
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
extension Filter.Cascade.Kr.Section { // Kr
    public static func lpf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, Q)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.LPF(ω₀: $0.increment(for: Tₛ), Q: $1)
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
                Linear.Biquad.LPF(ω₀: $0.increment(for: Tₛ), BW: $1)
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
extension Filter.Cascade.Kr.Section {
    public static func hpf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, Q)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.HPF(ω₀: $0.increment(for: Tₛ), Q: $1)
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
                Linear.Biquad.HPF(ω₀: $0.increment(for: Tₛ), BW: $1)
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
extension Filter.Cascade.Kr.Section {
    public static func apf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, Q)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.APF(ω₀: $0.increment(for: Tₛ), Q: $1)
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
                Linear.Biquad.APF(ω₀: $0.increment(for: Tₛ), BW: $1)
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
extension Filter.Cascade.Kr.Section {
    public static func bsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω₀, Q)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.BSF(ω₀: $0.increment(for: Tₛ), Q: $1)
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
                Linear.Biquad.BSF(ω₀: $0.increment(for: Tₛ), BW: $1)
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
extension Filter.Cascade.Kr.Section {
    public static func lsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, Q, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.LSF(ω₀: $0.increment(for: Tₛ), Q: $1, dB: $2)
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
                Linear.Biquad.LSF(ω₀: $0.increment(for: Tₛ), BW: $1, dB: $2)
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
                Linear.Biquad.LSF(ω₀: $0.increment(for: Tₛ), S: $1, dB: $2)
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
extension Filter.Cascade.Kr.Section {
    public static func hsf(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, Q, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.HSF(ω₀: $0.increment(for: Tₛ), Q: $1, dB: $2)
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
                Linear.Biquad.HSF(ω₀: $0.increment(for: Tₛ), BW: $1, dB: $2)
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
                Linear.Biquad.HSF(ω₀: $0.increment(for: Tₛ), S: $1, dB: $2)
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
extension Filter.Cascade.Kr.Section {
    public static func peq(
        ω₀: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω₀, Q, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.PEQ(ω₀: $0.increment(for: Tₛ), Q: $1, dB: $2)
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
                Linear.Biquad.PEQ(ω₀: $0.increment(for: Tₛ), BW: $1, dB: $2)
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
                Linear.Biquad.PEQ(ω₀: $0.increment(for: Tₛ), S: $1, dB: $2)
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

// MARK: RAW
extension Filter.Cascade.Kr.Section {
    public static func raw(_ object: Linear.Biquad) -> Self {
        let raw = Just(object).eraseToAnyPublisher()
        return.init { _ in
            raw
        }
    }
    public static func raw(b: SIMD3<Float64>, a: SIMD3<Float64>) -> Self {
        .raw(.init(b: b, a: a))
    }
}
prefix operator ∫
public prefix func ∫(x: Stream) -> some Stream { // cumsum(f(t)) without reset trigger
    filter(x, sos: .raw(b: .init(0.5, 0.5, 0), a: .init( 1, -1, 0)))
}
prefix operator ∂
public prefix func ∂(x: Stream) -> some Stream { // diff(f(t)) without reset trigger
    filter(x, sos: .raw(b: .init( 1, 0, -1), a: .init( 1, 1, 0)))
}
public func filter(_ source: Stream, sos series: some Sequence<Filter.Cascade.Kr.Section> & Sendable) -> some Stream {
    filter(source, sos: Filter.Cascade.Kr(rawValue: .init(series)))
}
@inlinable@_disfavoredOverload
public func filter(_ source: Stream, sos series: Filter.Cascade.Kr.Section...) -> some Stream {
    filter(source, sos: series)
}
public func filter(_ source: Stream, sos series: some Sequence<Filter.Cascade.Ar.Section>) -> some Stream {
    filter(source, sos: Filter.Cascade.Ar(rawValue: .init(series)))
}
@inlinable@_disfavoredOverload
public func filter(_ source: Stream, sos series: Filter.Cascade.Ar.Section...) -> some Stream {
    filter(source, sos: series)
}
