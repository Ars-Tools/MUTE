//
//  Filter+ZPK.swift
//  MUTE
//
//  Created by Kota on 10/7/26.
//
import protocol Accelerate.AccelerateBuffer
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Publishers
import typealias Numerics.Complex128
import protocol DSP.Stream
import typealias DSP.Instance
import typealias DSP.Filter
import typealias CLK.CMTime
import func DSP.filter
extension Filter {
    @usableFromInline
    enum ZPK {
        @usableFromInline
        struct Rn<Signal: Publisher<Model.ZPK, Never> & Sendable> {
            @usableFromInline let signal: Signal
            @usableFromInline let count: Int
        }
    }
}
extension Filter.ZPK.Rn: DSP.Filter.BiquadSeries {
    @usableFromInline
    typealias BiquadSeriesCollection = Array<(b: SIMD3<Float64>, a: SIMD3<Float64>)>
    @usableFromInline
    typealias BiquadSeriesCoefficients = Publishers.Map<Signal, (Range<Int>, BiquadSeriesCollection)>
    @usableFromInline
    typealias Scalar = Float64
    @usableFromInline
    typealias B = Array<Float64>
    @usableFromInline
    typealias A = Array<Float64>
    @inlinable
    func coefficients(for Tₛ: CMTime) -> Publishers.Map<Signal, (Range<Int>, BiquadSeriesCollection)> {
        signal.map(Model.Cascade.init).map {
            (0..<$0.count, $0.map { ($0.b, $0.a) })
        }
    }
}
public func filter(_ source: Stream, zpk: some Publisher<Model.ZPK, Never> & Sendable, count: Int) -> some Stream {
    filter(source, sos: Filter.ZPK.Rn.init(signal: zpk, count: count))
}
