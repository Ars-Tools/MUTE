//
//  Graph+LinLin.swift
//  MUTE
//
//  Created by Kota on 10/31/25.
//
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import Metal
import MetalKit
import MetalPerformanceShaders
import MetalPerformancePrimitives
extension Graph {
    struct LinLin {
        let x: MTLBuffer
        let y: MTLBuffer
        let c: MTLBuffer
        let xscale: MTLBuffer
        let yscale: MTLBuffer
//        let kernel: MTLRenderPipelineState
    }
}
extension Graph.LinLin {
    public init(device: MTLDevice) {
        x = device.makeBuffer(length: 16).unsafelyUnwrapped
        y = device.makeBuffer(length: 16).unsafelyUnwrapped
        c = device.makeBuffer(length: 16).unsafelyUnwrapped
        xscale = device.makeBuffer(length: 16).unsafelyUnwrapped
        yscale = device.makeBuffer(length: 16).unsafelyUnwrapped
    }
}
extension Graph.LinLin {
    public var xrange: ClosedRange<Float64> {
        get {
            let αβ = SIMD2<Float64>(xscale.contents().load(as: SIMD2<Float32>.self))
            let range = (SIMD2<Float64>(-1, 1) - αβ.y) / αβ.x
            return range.x ... range.y
        }
        nonmutating set {
            xscale.contents()
                .storeBytes(of: SIMD2<Float32>(SIMD2(2.0, -newValue.upperBound-newValue.lowerBound) / (newValue.upperBound-newValue.lowerBound)),
                            as: SIMD2<Float32>.self)
        }
    }
    public var yrange: ClosedRange<Float64> {
        get {
            let αβ = SIMD2<Float64>(yscale.contents().load(as: SIMD2<Float32>.self))
            let range = (SIMD2<Float64>(-1, 1) - αβ.y) / αβ.x
            return range.x ... range.y
        }
        nonmutating set {
            yscale.contents()
                .storeBytes(of: SIMD2<Float32>(SIMD2(2.0, -newValue.upperBound-newValue.lowerBound) / (newValue.upperBound-newValue.lowerBound)),
                            as: SIMD2<Float32>.self)
        }
    }
}
extension Graph.LinLin {
    func render(to target: MTLTexture, with commandBuffer: MTLCommandBuffer) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 1)
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].texture = target
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        withUnsafeBytes(of: xscale) {
            encoder?.setVertexBytes($0.baseAddress.unsafelyUnwrapped, length: $0.count, index: 0)
        }
        withUnsafeBytes(of: yscale) {
            encoder?.setVertexBytes($0.baseAddress.unsafelyUnwrapped, length: $0.count, index: 1)
        }
        withUnsafeBytes(of: SIMD4<Float32>(repeating: 1)) {
            encoder?.setFragmentBytes($0.baseAddress.unsafelyUnwrapped, length: $0.count, index: 0)
        }
        // axes
        // line
        
        encoder?.endEncoding()
    }
}
