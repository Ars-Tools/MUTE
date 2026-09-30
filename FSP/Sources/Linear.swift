//
//  Linear.swift
//  MUTE
//
//  Created by Kota on 9/3/26.
//
import typealias Numerics.Complex128
import func simd.recip
public enum Linear {
    public protocol `Filter`: Sendable {}
}
extension Linear {
    @usableFromInline
    enum Root {
        case real(Float64)
        case conjugatePair(upper: Complex128)
    }
    public typealias ZPK = (
        z: (Array<Complex128>, Array<Float64>),
        p: (Array<Complex128>, Array<Float64>),
        k: Optional<Float64>
    )
}
extension Linear.Root {
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
