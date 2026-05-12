//
//  Special+SVF.swift
//  MUTE
//
//  Created by Kota on 5/11/26.
//
@preconcurrency import protocol Combine.Publisher
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias Accelerate.vDSP
import typealias CoreMedia.CMTime
import func Layout.broadcast
import func NSP.state_variable_filter_static
import func NSP.state_variable_filter_active
import protocol DSP.Frequency
import protocol DSP.Stream
import typealias DSP.Instance
extension Special {
    @usableFromInline
    enum SVF {
        @usableFromInline
        struct Kr<Cutoff: Publisher<(Int, Frequency), Never> & Sendable, Factor: Publisher<(Int, Float64), Never> & Sendable> {
            @usableFromInline let source: Stream
            @usableFromInline let cutoff: Cutoff
            @usableFromInline let factor: Factor
        }
        @usableFromInline
        struct Ar {
            @usableFromInline let source: Stream
            @usableFromInline let cutoff: Stream
            @usableFromInline let factor: Stream
        }
    }
}
extension Special.SVF.Kr: Stream {
    @usableFromInline
    var count: Int {
        source.count * 3
    }
    @usableFromInline
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        let latest = Mutex<Array<(SIMD2<Float64>, Float64, Float64)>>(.init(repeating: (.zero, 0.0, 0.5.squareRoot()), count: source.count))
        let cutoff = cutoff.sink { index, value in
            latest.withLock {
                switch index {
                case $0.indices:
                    $0[index].1 = value.increment(for: interval)
                default:
                    assertionFailure("out of range")
                }
            }
        }
        let factor = factor.sink { index, value in
            latest.withLock {
                switch index {
                case $0.indices:
                    $0[index].2 = value
                default:
                    assertionFailure("out of range")
                }
            }
        }
        return { moment, length, target, stride in
            kernel(moment, length, target, stride)
            withExtendedLifetime((cutoff, factor)) {
                latest.withLock {
                    for (offset, element) in $0.indices.enumerated().reversed() {
                        state_variable_filter_static(target.advanced(by: offset * stride),
                                                     target.advanced(by: offset * stride), stride * $0.count,
                                                     $0[element].1, $0[element].2,
                                                     &$0[element].0, length)
                    }
                }
            }
        }
    }
}
extension Special.SVF.Ar: Stream {
    @usableFromInline
    var count: Int {
        broadcast(x: source.count, y: cutoff.count, z: factor.count) * 3
    }
    @usableFromInline
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let xk = try source(interval: interval, capacity: capacity, instance: &instance)
        let yk = try cutoff(interval: interval, capacity: capacity, instance: &instance)
        let zk = try factor(interval: interval, capacity: capacity, instance: &instance)
        let xc = source.count
        let yc = cutoff.count
        let zc = factor.count
        let T₀ = interval.seconds
        switch broadcast(x: xc, y: yc, z: zc) {
        case let wc:
            let latest = Mutex<Array<SIMD2<Float64>>>(.init(repeating: .zero, count: wc))
            return { moment, length, result, ws in
                let l = result.advanced(by: 0 * ws * wc)
                let b = result.advanced(by: 1 * ws * wc)
                let h = result.advanced(by: 2 * ws * wc)
                let ls = broadcast(x: wc, y: xc, z: ws)
                let bs = broadcast(x: wc, y: yc, z: ws)
                let hs = broadcast(x: wc, y: zc, z: ws)
                xk(moment, length, l, ws)
                yk(moment, length, b, ws)
                zk(moment, length, h, ws)
                for offset in 0..<yc {
                    var ω₀ = UnsafeMutableBufferPointer(start: b.advanced(by: offset * ws), count: length)
                    vDSP.multiply(T₀, ω₀, result: &ω₀)
                }
                latest.withLock {
                    for (offset, element) in $0.indices.enumerated().reversed() {
                        state_variable_filter_active(l.advanced(by: offset * ls),
                                                     l.advanced(by: offset * ws), ws,
                                                     b.advanced(by: offset * bs),
                                                     h.advanced(by: offset * hs),
                                                     &$0[element], length)
                    }
                }
            }
        }
    }
}
public func filter(_ source: Stream, svf: (ω₀: some Publisher<(Int, Frequency), Never> & Sendable, quality: some Publisher<(Int, Float64), Never> & Sendable)) -> some Stream {
    Special.SVF.Kr(source: source, cutoff: svf.ω₀, factor: svf.quality)
}
public func filter(_ source: Stream, svf: (ω₀: some Publisher<Frequency, Never>, quality: some Publisher<Float64, Never>)) -> some Stream {
    Special.SVF.Kr(source: source,
                           cutoff: svf.ω₀.repeat(count: source.count),
                           factor: svf.quality.repeat(count: source.count))
}
public func filter(_ source: Stream, svf: (ω₀: Frequency, quality: Float64)) -> some Stream {
    Special.SVF.Kr(source: source,
                           cutoff: `repeat`(svf.ω₀, count: source.count),
                           factor: `repeat`(svf.quality, count: source.count))
}
public func filter(_ source: Stream, svf: (ω₀: Stream, quality: Stream)) -> some Stream {
    Special.SVF.Ar(source: source, cutoff: svf.ω₀, factor: svf.quality)
}
