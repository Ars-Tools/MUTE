//
//  Visualise+Axes.swift
//  MUTE
//
//  Created by Kota on 1/5/26.
//
@preconcurrency import Metal
@preconcurrency import protocol Combine.Publisher
import protocol SwiftUI.Gesture
import struct Artwork.MTLArtwork
import CoreImage.CIFilterBuiltins
extension Visualise {
    public struct AxesXY {
        @usableFromInline
        let x: Dictionary<Float32, Optional<(Float32, Float32, String)>>
        @usableFromInline
        let y: Dictionary<Float32, Optional<(Float32, Float32, String)>>
    }
}
extension Visualise.AxesXY {
    public init() {
        x = .init(uniqueKeysWithValues: stride(from: -16, through: 16, by: 1).map {
            ($0 / 16.0, .none)
        })
        y = .init(uniqueKeysWithValues: stride(from: -16, through: 16, by: 1).map {
            ($0 / 16.0, .none)
        })
    }
}
extension Visualise.AxesXY: MTLArtwork.`Protocol` {
    public func callAsFunction(as format: MTLPixelFormat, in residency: any MTLResidencySet, signal: some Publisher<(SIMD2<Double>, any Gesture), Never>) throws -> @Sendable (CFTimeInterval, any MTL4RenderCommandEncoder) -> Void {
        let device = residency.device
        let library = try device.makeDefaultLibrary(bundle: .module)
        let compiler = try device.makeCompiler(descriptor: .init())
        
        
        let gridDescriptor = MTL4MeshRenderPipelineDescriptor()
        gridDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            let mesh = MTL4LibraryFunctionDescriptor()
            mesh.library = library
            mesh.name = "xaxis"
            gridDescriptor.meshFunctionDescriptor = mesh
            
            let frag = MTL4LibraryFunctionDescriptor()
            frag.library = library
            frag.name = "white"
            gridDescriptor.fragmentFunctionDescriptor = frag
        }
        let xk = try compiler.makeRenderPipelineState(descriptor: gridDescriptor)
        
        do {
            let mesh = MTL4LibraryFunctionDescriptor()
            mesh.library = library
            mesh.name = "yaxis"
            gridDescriptor.meshFunctionDescriptor = mesh
            
            let frag = MTL4LibraryFunctionDescriptor()
            frag.library = library
            frag.name = "white"
            gridDescriptor.fragmentFunctionDescriptor = frag
        }
        let yk = try compiler.makeRenderPipelineState(descriptor: gridDescriptor)
        
        let xb = device.makeBuffer(length: MemoryLayout<Float32>.stride * x.count + MemoryLayout<UInt32>.size, options: .storageModeShared).unsafelyUnwrapped
        do {
            for (idx, val) in x.keys.enumerated() {
                xb.contents().storeBytes(of: val, toByteOffset: idx * MemoryLayout<Float32>.stride, as: Float32.self)
            }
            xb.contents().storeBytes(of: .init(x.count), toByteOffset: x.count * MemoryLayout<Float32>.stride, as: UInt32.self)
        }
        
        let yb = device.makeBuffer(length: MemoryLayout<Float32>.stride * 64 + MemoryLayout<UInt32>.size, options: .storageModeShared).unsafelyUnwrapped
        do {
            for (idx, val) in y.keys.enumerated() {
                yb.contents().storeBytes(of: val, toByteOffset: idx * MemoryLayout<Float32>.stride, as: Float32.self)
            }
            yb.contents().storeBytes(of: .init(y.count), toByteOffset: y.count * MemoryLayout<Float32>.stride, as: UInt32.self)
        }
        residency.addAllocation(xb)
        residency.addAllocation(yb)
        
        let argDescriptor = MTL4ArgumentTableDescriptor()
        argDescriptor.maxBufferBindCount = 2
        
        let xc = try device.makeArgumentTable(descriptor: argDescriptor)
        xc.setAddress(xb.gpuAddress, index: 0)
        xc.setAddress(xb.gpuAddress + .init(x.count * MemoryLayout<Float32>.stride), index: 1)
        
        let yc = try device.makeArgumentTable(descriptor: argDescriptor)
        yc.setAddress(yb.gpuAddress, index: 0)
        yc.setAddress(yb.gpuAddress + .init(y.count * MemoryLayout<Float32>.stride), index: 1)
        
        let xd = ( x.count * 2 - 1 ) / xk.meshThreadExecutionWidth + 1
        let yd = ( y.count * 2 - 1 ) / yk.meshThreadExecutionWidth + 1
        
        // label
        let context = CIContext(mtlDevice: device)
        let xl = x.compactMap {
            switch $1 {
            case.some((let ypos, let size, let text)):
                    .some(($0, ypos, size, text))
            case.none:
                    .none
            }
        }
        let yl = y.compactMap {
            switch $1 {
            case.some(let label):
                    .some(($0, label))
            case.none:
                    .none
            }
        }
        let typewriter = CIFilter.textImageGenerator()
        typewriter.setDefaults()
        
        let td = MTLTextureDescriptor()
        td.pixelFormat = .bgra8Unorm
        td.textureType = .type2DArray
        td.usage = [.shaderRead, .shaderWrite]
        
        td.arrayLength = xl.count
        
        let view = MTLTextureViewDescriptor()
        view.pixelFormat = .bgra8Unorm
        view.textureType = .type2D
        view.sliceRange = 0..<1
        
        let xlt = device.makeTexture(descriptor: td).unsafelyUnwrapped
        for (xpos, ypos, size, text) in xl {
            xlt.newTextureView(with: view)
            
        }
        
        
        
        return {
            $1.setRenderPipelineState(xk)
            $1.setArgumentTable(xc, stages: .mesh)
            $1.drawMeshThreadgroups(threadgroupsPerGrid: .init(width: xd, height: 1, depth: 1),
                                    threadsPerObjectThreadgroup: .init(width: xk.objectThreadExecutionWidth, height: 1, depth: 1),
                                    threadsPerMeshThreadgroup: .init(width: xk.meshThreadExecutionWidth, height: 1, depth: 1))
            
            $1.setRenderPipelineState(yk)
            $1.setArgumentTable(yc, stages: .mesh)
            $1.drawMeshThreadgroups(threadgroupsPerGrid: .init(width: yd, height: 1, depth: 1),
                                    threadsPerObjectThreadgroup: .init(width: yk.objectThreadExecutionWidth, height: 1, depth: 1),
                                    threadsPerMeshThreadgroup: .init(width: yk.meshThreadExecutionWidth, height: 1, depth: 1))
        }
    }
}
