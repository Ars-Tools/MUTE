//
//  Comb.swift
//  MUTE
//
//  Created by Kota on 10/15/25.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Publishers
@preconcurrency import typealias Combine.Just
import typealias CoreMedia.CMTime
import typealias Synchronization.Atomic
import DSP
import NSP
import protocol DSP.Stream
@usableFromInline
enum Echo {
    @usableFromInline
    struct Kr<Control: Publisher<(Duration, Float64), Never> & Sendable> {
        @usableFromInline let source: Stream
        @usableFromInline let period: Duration
        @usableFromInline let object: Control
    }
}
extension Echo.Kr: Stream {
    @inlinable
    var count: Int {
        source.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        let buffer = Buffer(stream: count, period: capacity + period.samples(for: interval))
        let offset = Atomic<Int>(0)
        let weight = Atomic<Float64>(0)
        let cancel = object.sink {
            offset.store($0.samples(for: interval), ordering: .releasing)
            weight.store($1, ordering: .releasing)
        }
        return {
            kernel($0, $1, $2, $3)
            let cursor = $0.samples(for: interval)
            let (weight, offset) = withExtendedLifetime(cancel) {(
                weight.load(ordering: .acquiring),
                offset.load(ordering: .acquiring)
            )}
            for stream in 0..<buffer.stream {
                periodic_lookup_with_update($2.advanced(by: stream * $3),
                                            $2.advanced(by: stream * $3),
                                            buffer.start.advanced(by: stream * buffer.period),
                                            withUnsafePointer(to: weight, \.self), 0,
                                            cursor,
                                            offset,
                                            buffer.period,
                                            $1)
            }
        }
    }
}
public func filter(_ source: Stream, cmb object: (lag: some Publisher<Duration, Never>, gain: some Publisher<Float64, Never>), period: Duration) -> some Stream {
    Echo.Kr(source: source, period: period, object: Publishers.Zip(object.0, object.1))
}
public func filter(_ source: Stream, apf object: (lag: some Publisher<Duration, Never>, gain: some Publisher<Float64, Never>), period: Duration) -> some Stream {
    fma(filter(source, cmb: object, period: period), object.1.map { fma($0, $0, -1) }, source)
}
public func filter(_ source: Stream, cmb object: (lag: Duration, gain: Float64)) -> some Stream {
    filter(source, cmb: (Just(object.0), Just(object.1)), period: object.0)
}
public func filter(_ source: Stream, apf object: (lag: Duration, gain: Float64)) -> some Stream {
    filter(source, apf: (Just(object.0), Just(object.1)), period: object.0)
}
