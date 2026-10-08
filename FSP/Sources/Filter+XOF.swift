//
//  Filter+XOF.swift
//  MUTE
//
//  Created by Kota on 10/8/26.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Just
import typealias CoreMedia.CMTime
import protocol DSP.Frequency
import protocol DSP.Stream
import func DSP.`repeat`
import func DSP.filter
import typealias DSP.Filter
// Linkwitz-Riley cross-over filters
public func filter(_ source: Stream, xof M: Array<some Publisher<Frequency, Never>>) -> some Stream {
    let Q = Just(0.5.squareRoot())
    return filter(`repeat`(source, count: M.count+1), sos: (0..<M.count+1).map { channel in
        Model.Cascade.Rn(rawValue: (0..<M.count).reduce(into: Array<Model.Cascade.Rn.Section>()) { accum, index in
            if channel < index {
                accum.append(.apf(ω₀: M[index], Q: Q))
                accum.append(.identity)
            } else if channel > index {
                accum.append(.hpf(ω₀: M[index], Q: Q))
                accum.append(.hpf(ω₀: M[index], Q: Q))
            } else {
                accum.append(.lpf(ω₀: M[index], Q: Q))
                accum.append(.lpf(ω₀: M[index], Q: Q))
            }
        })
    }, count: 2 * M.count)
}
@inlinable
public func filter(_ source: Stream, xof model: some Collection<Frequency>) -> some Stream {
    filter(source, xof: model.map(Just.init))
}
@inlinable@_disfavoredOverload
public func filter(_ source: Stream, xof model: Frequency...) -> some Stream {
    filter(source, xof: model)
}
