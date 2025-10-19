//
//  Typedefs.swift
//  MUTE
//
//  Created by Kota on 8/14/R7.
//
import protocol Accelerate.AccelerateBuffer
@usableFromInline
enum Error: Swift.Error & Sendable {
	case unmatchChannel
	case invalidChannel
	case lackOfResource(String)
	case failedToAllocate(Any.Type)
}
//@usableFromInline
//struct SplitComplex<Part: AccelerateBuffer<Float64>> {
//	@usableFromInline let r: Part
//	@usableFromInline let i: Part
//}
