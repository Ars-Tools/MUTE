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
    @usableFromInline // contains only positive-side imaginary roots, conjugated roots will be required to compute
    typealias ZPK = (
        zero: (Array<Complex128>, Array<Float64>),
        pole: (Array<Complex128>, Array<Float64>),
        gain: Optional<Float64>
    )
}
extension Linear.Root {
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
