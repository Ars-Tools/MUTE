//
//  Model+ZPK.swift
//  MUTE
//
//  Created by Kota on 10/7/26.
//
import typealias Numerics.Complex128
extension Model {
    public struct ZPK: Linear {
        public enum Root: Sendable {
            case real(Float64)
            case conjugatePair(upper: Complex128)
        }
        public var z: (Array<Complex128>, Array<Float64>)
        public var p: (Array<Complex128>, Array<Float64>)
        public var k: Optional<Float64>
    }
}
extension Model.ZPK {
    @inlinable
    init(raw: (
         z: (pair: Array<Complex128>, real: Array<Float64>),
         p: (pair: Array<Complex128>, real: Array<Float64>),
         k: Optional<Float64>
    )) {
        (z, p, k) = raw
    }
    @inlinable
    init(rebalance: (
         z: (pair: Array<Complex128>, real: Array<Float64>),
         p: (pair: Array<Complex128>, real: Array<Float64>),
         k: Optional<Float64>
    )) {
        (z, p, k) = rebalance
    }
    @inlinable
    init(gain: Optional<Float64> = .none) {
        z = (.init(), .init())
        p = (.init(), .init())
        k = gain
    }
}
extension Model.ZPK.Root {
    @inlinable
    init(_ r: Float64) {
        self = .real(r)
    }
    @inlinable
    init(_ r: Float64, _ i: Float64) {
        assert(0.isLess(than: i))
        self = .conjugatePair(upper: .init(real: r, imag: i))
    }
    @inlinable
    var magnitude: Float64 {
        switch self {
        case.real(let r):
            r.magnitude
        case.conjugatePair(let r):
            r.magnitude
        }
    }
}
