//
//  Misc.swift
//  MUTE
//
//  Created by Kota on 5/9/R7.
//
import func Accelerate.vDSP_mmovD
import typealias Dispatch.DispatchQueue
@inlinable @inline(__always)
func copy(x: UnsafePointer<Float64>, ldx: Int,
		  y: UnsafeMutablePointer<Float64>, ldy: Int,
		  rows: Int, cols: Int) {
	vDSP_mmovD(x, y, .init(cols), .init(rows), .init(ldx), .init(ldy))
}
@inlinable @inline(__always)
func forEach<C: Collection & Sendable>(element: C, closure: (C.Element) -> Void) where C.Element: Sendable, C.Index: Strideable, C.Index.Stride == Int {
	withoutActuallyEscaping({
		closure(element[element.startIndex.advanced(by: $0)])
	} as (Int) -> Void) {
		DispatchQueue.concurrentPerform(iterations: element.count, execute: unsafeBitCast($0, to: (@Sendable (Int) -> Void).self))
	}
}
/*
 He: without any arguments
 Ne: with constant arguments
 Kr: with control-rate arguments
 Ar: with audio-rate arguments
 Xe: special (like buffer)
 Rn:
 Og: 
 */
