//
//  Visualise+LinLin.swift
//  MUTE
//
//  Created by Kota on 1/5/26.
//
@preconcurrency import Metal
@preconcurrency import protocol Combine.Publisher
import protocol SwiftUI.Gesture
import protocol Artwork.Artwork
extension Visualise {
    public struct LinLin {
        @usableFromInline let width: Int
    }
}
extension Visualise.LinLin: Artwork {
    @inlinable
    public func callAsFunction(as format: MTLPixelFormat, in residency: any MTLResidencySet, signal: some Publisher<(SIMD2<Double>, any Gesture), Never>) throws -> @Sendable (CFTimeInterval, any MTL4CommandBuffer, any MTLTexture) -> Void {
        return {
            _ = $2
        }
    }
}
