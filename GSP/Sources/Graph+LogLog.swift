//
//  Graph+LogLog.swift
//  MUTE
//
//  Created by Kota on 10/31/25.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias SwiftUI.Color
import func simd.log10
import func simd.exp10
@preconcurrency import Metal
extension Graph {
    final class LogLog: Sendable {
        let instance: Mutex<Array<Instance>>
        let pipeline: MTLRenderPipelineState
        let vtable: MTL4ArgumentTable
        let ftable: MTL4ArgumentTable
        let xmapping: Atomic<UInt64>
        let ymapping: Atomic<UInt64>
        init(format: MTLPixelFormat, device: MTLDevice) throws {
            let compiler = try device.makeCompiler(descriptor: .init())
            let library = try compiler.device.makeDefaultLibrary(bundle: .module)
            let vs = MTL4LibraryFunctionDescriptor()
            vs.name = "loglogv"
            vs.library = library
            let fs = MTL4LibraryFunctionDescriptor()
            fs.name = "loglogf"
            fs.library = library
            let descriptor = MTL4RenderPipelineDescriptor()
            descriptor.colorAttachments[0].pixelFormat = format
            descriptor.colorAttachments[0].blendingState = .enabled
            descriptor.rasterSampleCount = 4
            descriptor.vertexFunctionDescriptor = vs
            descriptor.fragmentFunctionDescriptor = fs
            
            
            
            pipeline = try compiler.makeRenderPipelineState(descriptor: descriptor)
            vtable = try compiler.device.makeArgumentTable(descriptor: .init())
            ftable = try compiler.device.makeArgumentTable(descriptor: .init())
            instance = .init(.init())
            xmapping = .init(unsafeBitCast(SIMD2<Float32>(1, 0), to: UInt64.self))
            ymapping = .init(unsafeBitCast(SIMD2<Float32>(1, 0), to: UInt64.self))
        }
    }
}
extension Graph.LogLog {
    @usableFromInline
    struct Instance: Sendable {
        @usableFromInline let x: MTLTensor
        @usableFromInline let y: MTLTensor
        @usableFromInline let z: Color.Resolved
        @usableFromInline let w: Float32
    }
}
extension Graph.LogLog {
    @inlinable
    public var xrange: ClosedRange<Float64> {
        get {
            let αβ = SIMD2<Float64>(unsafeBitCast(xmapping.load(ordering: .acquiring), to: SIMD2<Float32>.self))
            let range = exp10((SIMD2<Float64>(-1, 1) - αβ.y) / αβ.x)
            return range.x ... range.y
        }
        set {
            let αβ = log10(SIMD2<Float64>(newValue.lowerBound, newValue.upperBound))
            xmapping.store(unsafeBitCast(SIMD2<Float32>(SIMD2<Float64>(2.0, -αβ.y-αβ.x) / (αβ.y-αβ.x)), to: UInt64.self),
                           ordering: .releasing)
        }
    }
    @inlinable
    public var yrange: ClosedRange<Float64> {
        get {
            let αβ = SIMD2<Float64>(unsafeBitCast(ymapping.load(ordering: .acquiring), to: SIMD2<Float32>.self))
            let range = exp10((SIMD2<Float64>(-1, 1) - αβ.y) / αβ.x)
            return range.x ... range.y
        }
        set {
            let αβ = log10(SIMD2<Float64>(newValue.lowerBound, newValue.upperBound))
            ymapping.store(unsafeBitCast(SIMD2<Float32>(SIMD2<Float64>(2.0, -αβ.y-αβ.x) / (αβ.y-αβ.x)), to: UInt64.self),
                           ordering: .releasing)
        }
    }
    
}
extension Graph.LogLog {
    public func clear() {
        instance.withLock {
            $0.removeAll()
        }
    }
    public func append(x: MTLTensor, y: MTLTensor, color: Color = .accentColor, alpha: Float32 = 1.0) {
        instance.withLock {
            $0.append(.init(x: x, y: y, z: color.resolve(in: .init()), w: alpha))
        }
    }
}
extension Graph.LogLog {
    public func render(at timestamp: CFTimeInterval, to target: MTLTexture, with mtlCommandBuffer: MTL4CommandBuffer) {
        let descriptor = MTL4RenderPassDescriptor()
        descriptor.colorAttachments[0].texture = target
        descriptor.colorAttachments[0].clearColor = .init()
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        let encoder = mtlCommandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(pipeline)
        encoder?.setArgumentTable(vtable, stages: .vertex)
        encoder?.setArgumentTable(ftable, stages: .vertex)
        encoder?.endEncoding()
    }
    public func render(at timestamp: CFTimeInterval, to target: MTLTexture, with mtlCommandBuffer: MTLCommandBuffer) {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = target
        descriptor.colorAttachments[0].clearColor = .init()
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        
        let m = pipeline.device.makeCommandBuffer()
        let e = m?.makeRenderCommandEncoder(descriptor: .init())
        e?.setRenderPipelineState(pipeline)
        e?.drawPrimitives(primitiveType: .lineStrip, vertexStart: 0, vertexCount: 10)
        e?.endEncoding()
        m?.endCommandBuffer()
        
        let encoder = mtlCommandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.setRenderPipelineState(pipeline)
        withUnsafeBytes(of: xmapping.load(ordering: .acquiring)) {
            encoder?.setVertexBytes($0.baseAddress.unsafelyUnwrapped, length: $0.count, index: 0)
        }
        withUnsafeBytes(of: ymapping.load(ordering: .acquiring)) {
            encoder?.setVertexBytes($0.baseAddress.unsafelyUnwrapped, length: $0.count, index: 1)
        }
        for instance in instance.withLock(\.self) {
            encoder?.setVertexBuffer(instance.x.buffer, offset: instance.x.bufferOffset, index: 2)
            encoder?.setVertexBuffer(instance.y.buffer, offset: instance.y.bufferOffset, index: 3)
            encoder?.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: min(instance.x.dimensions.extents.reduce(1, *),
                                                                                       instance.y.dimensions.extents.reduce(1, *)))
            withUnsafeBytes(of: SIMD4<Float32>(instance.z.linearRed,
                                               instance.z.linearGreen,
                                               instance.z.linearBlue,
                                               instance.w)) {
                encoder?.setFragmentBytes($0.baseAddress.unsafelyUnwrapped, length: $0.count, index: 0)
            }
        }
        encoder?.endEncoding()
    }
}
