//
//  Linear+Direct+GroupDelay.swift
//  MUTE
//
//  Created by Kota on 9/9/26.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Numerics.Complex128
import func Complex.add
import func Complex.sub
import func Complex.mul
import func Complex.div
import func Complex.libcsqrt
import func simd.__cospi
import func simd.pow
import func simd.fma
import func simd.log
import func simd.exp
import func simd.length_squared
import func MKL.vDSP_add
import func MKL.vDSP_fill
import func BLAS.copy
import func LAPACK.hseqr
extension Linear.Direct {
    @usableFromInline
    struct GroupDelay {
        @usableFromInline let g: Array<Float64> // ∂θ
        @usableFromInline let p: Array<Float64> // a.k.a. power-spectrum polynomial
    }
}
