//
//  Parameter.swift
//  MUTE
//
//  Created by Kota on 10/7/26.
//
import func simd.pow
import func simd.sqrt
import func simd.expm1
import func simd.simd_precise_recip
import let simd.M_LN10
public enum Parameter {
    @inlinable@inline(__always)@_transparent
    public static func ripple(dB: Float64) -> Float64 {
        sqrt(expm1(0.1 * M_LN10 * dB))
    }
    @inlinable@inline(__always)@_transparent
    public static func forget(factor: Float64, per sample: Int) -> Float64 {
        pow(factor, simd_precise_recip(.init(sample)))
    }
}
