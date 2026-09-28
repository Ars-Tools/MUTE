//
//  Special+Duffing.swift
//  MUTE
//
//  Created by Kota on 5/11/26.
//
import typealias CoreMedia.CMTime
import typealias Synchronization.Mutex
import protocol DSP.Stream
import typealias DSP.Filter
import typealias DSP.Instance
import func NSP.duffing_filter_convolve_static
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Publishers
@preconcurrency import typealias Combine.Just
extension Special {
    @usableFromInline
    enum Duffing {
        @usableFromInline
        struct Kr<Signal: Publisher<SIMD2<Float64>, Never> & Sendable, Biquad: Filter.BiquadSeries<Float64>> {
            @usableFromInline let source: Stream
            @usableFromInline let design: Biquad
            @usableFromInline let signal: Signal
        }
    }
}
extension Special.Duffing.Kr: Stream {
    @inlinable
    var count: Int {
        source.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        let stream = source.count
        let length = design.count
        let buffer = Mutex<(
            Array<SIMD3<Float64>>,
            Array<SIMD3<Float64>>,
            SIMD2<Float64>,
            Array<SIMD2<Float64>>)>((
                .init(repeating: .init(1, 0, 0), count: length),
                .init(repeating: .init(1, 0, 0), count: length),
                .init(0, 1),
                .init(repeating: .zero, count: stream * length),
        ))
        instance.store(design.coefficients(for: interval).sink { range, value in
            buffer.withLock {
                $0.0.replaceSubrange(range, with: value.map(\.b))
                $0.1.replaceSubrange(range, with: value.map(\.a))
            }
        }, interval: interval, capacity: capacity)
        instance.store(signal.sink { value in
            buffer.withLock {
                $0.2 = value
            }
        }, interval: interval, capacity: capacity)
        return {
            kernel($0, $1, $2, $3)
            let memory = zip(stride(from: $2, to: $2.advanced(by: stream * $3), by: $3),
                             repeatElement($1, count: stream)).map(UnsafeMutableBufferPointer.init(start:count:))
            buffer.withLock {
                for (offset, memory) in memory.enumerated() {
                    for (cursor, (b, a)) in zip($0.0, $0.1).enumerated() {
                        duffing_filter_convolve_static(b,
                                                       a,
                                                       $0.2,
                                                       memory.baseAddress.unsafelyUnwrapped,
                                                       memory.baseAddress.unsafelyUnwrapped,
                                                       &$0.3[offset * length + cursor],
                                                       memory.count)
                    }
                }
            }
        }
    }
}
public func filter(_ source: Stream, sos sections: some Filter.BiquadSeries<Float64>, duffing αβ: some Publisher<SIMD2<Float64>, Never> & Sendable) -> some Stream {
    Special.Duffing.Kr(source: source, design: sections, signal: αβ)
}
public func filter(_ source: Stream, sos sections: some Filter.BiquadSeries<Float64>, duffing αβ: SIMD2<Float64>) -> some Stream {
    Special.Duffing.Kr(source: source, design: sections, signal: Just(αβ))
}
public func filter(_ source: Stream, sos sections: some Sequence<Filter.Cascade.Rn.Section>, duffing αβ: some Publisher<SIMD2<Float64>, Never> & Sendable) -> some Stream {
    filter(source, sos: Filter.Cascade.Rn(rawValue: .init(sections)), duffing: αβ)
}
public func filter(_ source: Stream, sos sections: some Sequence<Filter.Cascade.Rn.Section>, duffing αβ: SIMD2<Float64>) -> some Stream {
    filter(source, sos: Filter.Cascade.Rn(rawValue: .init(sections)), duffing: Just(αβ))
}
@_disfavoredOverload
public func filter(_ source: Stream, sos sections: Filter.Cascade.Rn.Section..., duffing αβ: some Publisher<SIMD2<Float64>, Never> & Sendable) -> some Stream {
    filter(source, sos: Filter.Cascade.Rn(rawValue: sections), duffing: αβ)
}
@_disfavoredOverload
public func filter(_ source: Stream, sos sections: Filter.Cascade.Rn.Section..., duffing αβ: SIMD2<Float64>) -> some Stream {
    filter(source, sos: Filter.Cascade.Rn(rawValue: sections), duffing: Just(αβ))
}
