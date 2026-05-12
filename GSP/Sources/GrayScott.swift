//
//  Gray-Scott.swift
//  MUTE
//
//  Created by Kota on 12/2/25.
//
public struct GrayScott {
    
}
extension GrayScott: Artwork {
    @inlinable
    public func callAsFunction(as format: MTLPixelFormat, in residency: MTLResidencySet) throws -> @Sendable (CFTimeInterval, MTL4CommandBuffer, MTLTexture) -> Void {
        { _, _, _ in
            
        }
    }
}
