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
import protocol DSP.Stream
import typealias DSP.Filter
import protocol DSP.Frequency
import typealias CLK.CMTime
import func DSP.filter
extension Filter {
    public enum Cascade {
        public struct Section: Sendable {
            @usableFromInline
            let closure: @Sendable (CMTime) -> AnyPublisher<Linear.Biquad, Never>
        }
        @usableFromInline
        struct Rn<Series: Collection<Section> & Sendable> {
            @usableFromInline
            let rawValue: Series
        }
    }
}
extension Filter.Cascade.Rn: Filter.BiquadSeries {
    @usableFromInline
    typealias Biquad = CollectionOfOne<(b: SIMD3<Float64>, a: SIMD3<Float64>)>
    @usableFromInline
    typealias Sections = Publishers.MergeMany<Publishers.Map<AnyPublisher<Linear.Biquad, Never>, (Range<Int>, Biquad)>>
    @usableFromInline
    typealias A = Array<Float64>
    @usableFromInline
    typealias B = Array<Float64>
    @usableFromInline
    typealias Scalar = Float64
    @inlinable
    func sections(for Tₛ: CMTime) -> Sections {
        Publishers.MergeMany(
            rawValue.enumerated().map {
                let range = Range<Int>($0...$0)
                return $1.closure(Tₛ).map { (range, CollectionOfOne(($0.b, $0.a))) }
            }
        )
    }
    @inlinable
    var count: Int {
        rawValue.count
    }
}
// MARK: BPF
extension Filter.Cascade.Section {
    public static func bpf(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω, Q)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.BPF(ω₀: $0.increment(for: Tₛ), Q: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func bpf(
        ω: some Publisher<Frequency, Never>,
        Q: Float64
    ) -> Self {
        bpf(ω: ω, Q: Just(Q))
    }
    @inlinable
    public static func bpf(
        ω: Frequency,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        bpf(ω: Just(ω), Q: Q)
    }
    @inlinable
    public static func bpf(
        ω: Frequency,
        Q: Float64
    ) -> Self {
        bpf(ω: Just(ω), Q: Just(Q))
    }
    public static func bpf(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω, BW)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.BPF(ω₀: $0.increment(for: Tₛ), BW: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func bpf(
        ω: some Publisher<Frequency, Never>,
        BW: Float64
    ) -> Self {
        bpf(ω: ω, BW: Just(BW))
    }
    @inlinable
    public static func bpf(
        ω: Frequency,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        bpf(ω: Just(ω), BW: BW)
    }
    @inlinable
    public static func bpf(
        ω: Frequency,
        BW: Float64
    ) -> Self {
        bpf(ω: Just(ω), BW: Just(BW))
    }
}
// MARK: LPF
extension Filter.Cascade.Section {
    public static func lpf(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω, Q)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.LPF(ω₀: $0.increment(for: Tₛ), Q: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func lpf(
        ω: some Publisher<Frequency, Never>,
        Q: Float64
    ) -> Self {
        lpf(ω: ω, Q: Just(Q))
    }
    @inlinable
    public static func lpf(
        ω: Frequency,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        lpf(ω: Just(ω), Q: Q)
    }
    @inlinable
    public static func lpf(
        ω: Frequency,
        Q: Float64
    ) -> Self {
        lpf(ω: Just(ω), Q: Just(Q))
    }
    public static func lpf(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω, BW)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.LPF(ω₀: $0.increment(for: Tₛ), BW: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func lpf(
        ω: some Publisher<Frequency, Never>,
        BW: Float64
    ) -> Self {
        lpf(ω: ω, BW: Just(BW))
    }
    @inlinable
    public static func lpf(
        ω: Frequency,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        lpf(ω: Just(ω), BW: BW)
    }
    @inlinable
    public static func lpf(
        ω: Frequency,
        BW: Float64
    ) -> Self {
        lpf(ω: Just(ω), BW: Just(BW))
    }
}
// MARK: HPF
extension Filter.Cascade.Section {
    public static func hpf(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω, Q)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.HPF(ω₀: $0.increment(for: Tₛ), Q: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func hpf(
        ω: some Publisher<Frequency, Never>,
        Q: Float64
    ) -> Self {
        hpf(ω: ω, Q: Just(Q))
    }
    @inlinable
    public static func hpf(
        ω: Frequency,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        hpf(ω: Just(ω), Q: Q)
    }
    @inlinable
    public static func hpf(
        ω: Frequency,
        Q: Float64
    ) -> Self {
        hpf(ω: Just(ω), Q: Just(Q))
    }
    public static func hpf(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω, BW)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.HPF(ω₀: $0.increment(for: Tₛ), BW: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func hpf(
        ω: some Publisher<Frequency, Never>,
        BW: Float64
    ) -> Self {
        hpf(ω: ω, BW: Just(BW))
    }
    @inlinable
    public static func hpf(
        ω: Frequency,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        hpf(ω: Just(ω), BW: BW)
    }
    @inlinable
    public static func hpf(
        ω: Frequency,
        BW: Float64
    ) -> Self {
        hpf(ω: Just(ω), BW: Just(BW))
    }
}
// MARK: APF
extension Filter.Cascade.Section {
    public static func apf(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω, Q)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.APF(ω₀: $0.increment(for: Tₛ), Q: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func apf(
        ω: some Publisher<Frequency, Never>,
        Q: Float64
    ) -> Self {
        apf(ω: ω, Q: Just(Q))
    }
    @inlinable
    public static func apf(
        ω: Frequency,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        apf(ω: Just(ω), Q: Q)
    }
    @inlinable
    public static func apf(
        ω: Frequency,
        Q: Float64
    ) -> Self {
        apf(ω: Just(ω), Q: Just(Q))
    }
    public static func apf(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω, BW)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.APF(ω₀: $0.increment(for: Tₛ), BW: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func apf(
        ω: some Publisher<Frequency, Never>,
        BW: Float64
    ) -> Self {
        apf(ω: ω, BW: Just(BW))
    }
    @inlinable
    public static func apf(
        ω: Frequency,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        apf(ω: Just(ω), BW: BW)
    }
    @inlinable
    public static func apf(
        ω: Frequency,
        BW: Float64
    ) -> Self {
        apf(ω: Just(ω), BW: Just(BW))
    }
}
// MARK: BSF
extension Filter.Cascade.Section {
    public static func bsf(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω, Q)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.BSF(ω₀: $0.increment(for: Tₛ), Q: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func bsf(
        ω: some Publisher<Frequency, Never>,
        Q: Float64
    ) -> Self {
        bsf(ω: ω, Q: Just(Q))
    }
    @inlinable
    public static func bsf(
        ω: Frequency,
        Q: some Publisher<Float64, Never>
    ) -> Self {
        bsf(ω: Just(ω), Q: Q)
    }
    @inlinable
    public static func bsf(
        ω: Frequency,
        Q: Float64
    ) -> Self {
        bsf(ω: Just(ω), Q: Just(Q))
    }
    public static func bsf(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest(ω, BW)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.BSF(ω₀: $0.increment(for: Tₛ), BW: $1)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func bsf(
        ω: some Publisher<Frequency, Never>,
        BW: Float64
    ) -> Self {
        bsf(ω: ω, BW: Just(BW))
    }
    @inlinable
    public static func bsf(
        ω: Frequency,
        BW: some Publisher<Float64, Never>
    ) -> Self {
        bsf(ω: Just(ω), BW: BW)
    }
    @inlinable
    public static func bsf(
        ω: Frequency,
        BW: Float64
    ) -> Self {
        bsf(ω: Just(ω), BW: Just(BW))
    }
}
// MARK: LSF
extension Filter.Cascade.Section {
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω, Q, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.LSF(ω₀: $0.increment(for: Tₛ), Q: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω: ω, Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω: ω, Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω: ω, Q: Just(Q), dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω: Just(ω), Q: Q, dB: dB)
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω: Just(ω), Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω: Just(ω), Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        Q: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω: Just(ω), Q: Just(Q), dB: Just(dB))
    }
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω, BW, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.LSF(ω₀: $0.increment(for: Tₛ), BW: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω: ω, BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω: ω, BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω: ω, BW: Just(BW), dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω: Just(ω), BW: BW, dB: dB)
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω: Just(ω), BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω: Just(ω), BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        BW: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω: Just(ω), BW: Just(BW), dB: Just(dB))
    }
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω, S, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.LSF(ω₀: $0.increment(for: Tₛ), S: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω: ω, S: S, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω: ω, S: Just(S), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω: some Publisher<Frequency, Never>,
        S: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω: ω, S: Just(S), dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω: Just(ω), S: S, dB: dB)
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        lsf(ω: Just(ω), S: S, dB: Just(dB))
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        lsf(ω: Just(ω), S: Just(S), dB: dB)
    }
    @inlinable
    public static func lsf(
        ω: Frequency,
        S: Float64,
        dB: Float64
    ) -> Self {
        lsf(ω: Just(ω), S: Just(S), dB: Just(dB))
    }
}
// MARK: HSF
extension Filter.Cascade.Section {
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω, Q, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.HSF(ω₀: $0.increment(for: Tₛ), Q: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω: ω, Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω: ω, Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω: ω, Q: Just(Q), dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω: Just(ω), Q: Q, dB: dB)
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω: Just(ω), Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω: Just(ω), Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        Q: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω: Just(ω), Q: Just(Q), dB: Just(dB))
    }
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω, BW, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.HSF(ω₀: $0.increment(for: Tₛ), BW: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω: ω, BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω: ω, BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω: ω, BW: Just(BW), dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω: Just(ω), BW: BW, dB: dB)
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω: Just(ω), BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω: Just(ω), BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        BW: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω: Just(ω), BW: Just(BW), dB: Just(dB))
    }
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω, S, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.HSF(ω₀: $0.increment(for: Tₛ), S: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω: ω, S: S, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω: ω, S: Just(S), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω: some Publisher<Frequency, Never>,
        S: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω: ω, S: Just(S), dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω: Just(ω), S: S, dB: dB)
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        hsf(ω: Just(ω), S: S, dB: Just(dB))
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        hsf(ω: Just(ω), S: Just(S), dB: dB)
    }
    @inlinable
    public static func hsf(
        ω: Frequency,
        S: Float64,
        dB: Float64
    ) -> Self {
        hsf(ω: Just(ω), S: Just(S), dB: Just(dB))
    }
}
// MARK: PEQ
extension Filter.Cascade.Section {
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω, Q, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.PEQ(ω₀: $0.increment(for: Tₛ), Q: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω: ω, Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω: ω, Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        Q: Float64,
        dB: Float64
    ) -> Self {
        peq(ω: ω, Q: Just(Q), dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω: Just(ω), Q: Q, dB: dB)
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        Q: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω: Just(ω), Q: Q, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        Q: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω: Just(ω), Q: Just(Q), dB: dB)
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        Q: Float64,
        dB: Float64
    ) -> Self {
        peq(ω: Just(ω), Q: Just(Q), dB: Just(dB))
    }
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω, BW, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.PEQ(ω₀: $0.increment(for: Tₛ), BW: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω: ω, BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω: ω, BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        BW: Float64,
        dB: Float64
    ) -> Self {
        peq(ω: ω, BW: Just(BW), dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω: Just(ω), BW: BW, dB: dB)
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        BW: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω: Just(ω), BW: BW, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        BW: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω: Just(ω), BW: Just(BW), dB: dB)
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        BW: Float64,
        dB: Float64
    ) -> Self {
        peq(ω: Just(ω), BW: Just(BW), dB: Just(dB))
    }
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        let latest = Publishers.CombineLatest3(ω, S, dB)
        return.init { Tₛ in
            latest.map {
                Linear.Biquad.PEQ(ω₀: $0.increment(for: Tₛ), S: $1, dB: $2)
            }.eraseToAnyPublisher()
        }
    }
    @inlinable
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω: ω, S: S, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω: ω, S: Just(S), dB: dB)
    }
    @inlinable
    public static func peq(
        ω: some Publisher<Frequency, Never>,
        S: Float64,
        dB: Float64
    ) -> Self {
        peq(ω: ω, S: Just(S), dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        S: some Publisher<Float64, Never>,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω: Just(ω), S: S, dB: dB)
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        S: some Publisher<Float64, Never>,
        dB: Float64
    ) -> Self {
        peq(ω: Just(ω), S: S, dB: Just(dB))
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        S: Float64,
        dB: some Publisher<Float64, Never>
    ) -> Self {
        peq(ω: Just(ω), S: Just(S), dB: dB)
    }
    @inlinable
    public static func peq(
        ω: Frequency,
        S: Float64,
        dB: Float64
    ) -> Self {
        peq(ω: Just(ω), S: Just(S), dB: Just(dB))
    }
}

// MARK: RAW
extension Filter.Cascade.Section {
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
public func filter(_ source: Stream, sos series: some Collection<Filter.Cascade.Section> & Sendable) -> some Stream {
    filter(source, sos: Filter.Cascade.Rn(rawValue: series))
}
@inlinable@_disfavoredOverload
public func filter(_ source: Stream, sos series: Filter.Cascade.Section...) -> some Stream {
    filter(source, sos: series)
}
prefix operator ∫
public prefix func ∫(x: Stream) -> some Stream { // cumsum(f(t)) without reset trigger
    filter(x, sos: .raw(b: .init(0.5, 0.5, 0), a: .init( 1, -1, 0)))
}
prefix operator ∂
public prefix func ∂(x: Stream) -> some Stream { // diff(f(t)) without reset trigger
    filter(x, sos: .raw(b: .init( 1, 0, -1), a: .init( 1, 1, 0)))
}
