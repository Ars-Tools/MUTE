//
//  Linear.swift
//  MUTE
//
//  Created by Kota on 9/3/26.
//
import typealias Numerics.Complex128
import func simd.recip
public enum Linear {
    public protocol `Filter` {}
}
extension Linear {
    @usableFromInline // contains positive-side imaginary roots, conjugated roots is required to be computed
    typealias ZPK = (
        zero: (Array<Complex128>, Array<Float64>),
        pole: (Array<Complex128>, Array<Float64>),
        gain: Optional<Float64>
    )
}
