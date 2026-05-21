//
//  Protocol.swift
//  MUTE
//
//  Created by Kota on 12/2/25.
//
import SwiftUI
import Metal
//public protocol Artwork: Sendable {
//    func callAsFunction(as format: MTLPixelFormat, in residency: MTLResidencySet) throws -> @Sendable (CFTimeInterval, MTL4CommandBuffer, MTLTexture) -> Void
//}
//extension MTLClearColor: Artwork {
//    public func callAsFunction(as format: MTLPixelFormat, in residency: MTLResidencySet) throws -> @Sendable (CFTimeInterval, MTL4CommandBuffer, MTLTexture) -> Void {
//        {
//            let descriptor = MTL4RenderPassDescriptor()
//            descriptor.colorAttachments[0].clearColor = self
//            descriptor.colorAttachments[0].storeAction = .store
//            descriptor.colorAttachments[0].loadAction = .clear
//            descriptor.colorAttachments[0].texture = $2
//            let encoder = $1.makeRenderCommandEncoder(descriptor: descriptor)
//            encoder?.endEncoding()
//        }
//    }
//}
