//
//  GrayScott.swift
//  MUTE
//
//  Created by Kota on 12/2/25.
//
//@preconcurrency import Metal
//import Synchronization
//public struct GrayScott {
//    let wide: Int = 1024
//    let high: Int = 1024
//    public init() {
//    }
//}
//extension GrayScott: Artwork {
//    public func callAsFunction(as format: MTLPixelFormat, in residency: MTLResidencySet) throws -> @Sendable (CFTimeInterval, MTL4CommandBuffer, MTLTexture) -> Void {
//        let device = residency.device
//        
//        let compiler = try device.makeCompiler(descriptor: .init())
//        
//        let library = try compiler.device.makeDefaultLibrary(bundle: .module)
//        let vs = MTL4LibraryFunctionDescriptor()
//        vs.name = "gsvs"
//        vs.library = library
//        let fs = MTL4LibraryFunctionDescriptor()
//        fs.name = "gsfs"
//        fs.library = library
//        
//        let constant = MTLFunctionConstantValues()
////        constant.setConstantValue(withUnsafeBytes(of: 0.04 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 0) // f
////        constant.setConstantValue(withUnsafeBytes(of: 0.06 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 1) // k
////        constant.setConstantValue(withUnsafeBytes(of: 0.05 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 0) // f
////        constant.setConstantValue(withUnsafeBytes(of: 0.06 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 1) // k
//        constant.setConstantValue(withUnsafeBytes(of: 0.04 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 0) // f
//        constant.setConstantValue(withUnsafeBytes(of: 0.06 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 1) // k
//        //                constant.setConstantValue(withUnsafeBytes(of: 0.025 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 0) // f
//        //                constant.setConstantValue(withUnsafeBytes(of: 0.05 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 1) // k
////        constant.setConstantValue(withUnsafeBytes(of: 0.012 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 0) // f
////        constant.setConstantValue(withUnsafeBytes(of: 0.032 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 1) // k
//        constant.setConstantValue(withUnsafeBytes(of: 2e-5 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 2) // Du
//        constant.setConstantValue(withUnsafeBytes(of: 1e-5 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 3) // Dv
//        constant.setConstantValue(withUnsafeBytes(of: 0.01 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 4) // dx
//        constant.setConstantValue(withUnsafeBytes(of: 1.00 as Float32, \.baseAddress.unsafelyUnwrapped), type: .float, index: 5) // dt
//        let csf = MTL4LibraryFunctionDescriptor()
//        csf.name = "gscs"
//        csf.library = library
//        let css = MTL4SpecializedFunctionDescriptor()
//        css.constantValues = constant
//        css.functionDescriptor = csf
//        let csDescriptor = MTL4ComputePipelineDescriptor()
//        csDescriptor.computeFunctionDescriptor = css
//        let kernel = try compiler.makeComputePipelineState(descriptor: csDescriptor)
//        
//        let mtl4RenderPipelineDescriptor = MTL4RenderPipelineDescriptor()
//        mtl4RenderPipelineDescriptor.colorAttachments[0].pixelFormat = format
//        mtl4RenderPipelineDescriptor.colorAttachments[0].blendingState = .disabled
//        mtl4RenderPipelineDescriptor.vertexFunctionDescriptor = vs
//        mtl4RenderPipelineDescriptor.fragmentFunctionDescriptor = fs
//        
//        let pipeline = try compiler.makeRenderPipelineState(descriptor: mtl4RenderPipelineDescriptor)
//        
//        let descriptor = MTLTextureDescriptor()
//        descriptor.usage = [.shaderRead, .shaderWrite]
//        descriptor.width = wide
//        descriptor.height = high
//        descriptor.textureType = .type2DArray
//        descriptor.storageMode = .shared
//        descriptor.pixelFormat = .r32Float
//        descriptor.arrayLength = 2
//        
//        let texture = device.makeTexture(descriptor: descriptor).unsafelyUnwrapped
//        texture.replace(region: .init(origin: .init(x: 256-16, y: 256-16, z: 0), size: .init(width: 32, height: 32, depth: 1)),
//                        mipmapLevel: 0, slice: 0,
//                        withBytes: Array<Float32>(repeating: 0.50, count: 32 * 32 * 2 * 4),
//                        bytesPerRow: MemoryLayout<Float32>.stride * 32,
//                        bytesPerImage: MemoryLayout<Float32>.stride * 32 * 32)
//        texture.replace(region: .init(origin: .init(x: 256-16, y: 256-16, z: 0), size: .init(width: 32, height: 32, depth: 1)),
//                        mipmapLevel: 0, slice: 1,
//                        withBytes: Array<Float32>(repeating: 0.25, count: 32 * 32 * 2 * 4),
//                        bytesPerRow: MemoryLayout<Float32>.stride * 32,
//                        bytesPerImage: MemoryLayout<Float32>.stride * 32 * 32)
//        residency.addAllocation(texture)
//        
//        let uniformDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Uint, width: wide, height: high, mipmapped: false)
//        uniformDescriptor.usage = [.shaderRead, .shaderWrite]
//        uniformDescriptor.storageMode = .shared
//        let uniform = device.makeTexture(descriptor: uniformDescriptor).unsafelyUnwrapped
//        uniform.replace(region: .init(origin: .init(x: 0, y: 0, z: 0), size: .init(width: wide, height: high, depth: 1)), mipmapLevel: 0,
//                        withBytes: repeatElement(UInt32.min...UInt32.max, count: wide * high).map(UInt32.random(in:)), bytesPerRow: MemoryLayout<UInt32>.stride * wide)
//        residency.addAllocation(uniform)
//        
//        let buffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float32>>.stride * 4).unsafelyUnwrapped
//        buffer.contents().assumingMemoryBound(to: SIMD2<Float32>.self)[0] = .init(0, 0)
//        buffer.contents().assumingMemoryBound(to: SIMD2<Float32>.self)[1] = .init(0, 1)
//        buffer.contents().assumingMemoryBound(to: SIMD2<Float32>.self)[2] = .init(1, 0)
//        buffer.contents().assumingMemoryBound(to: SIMD2<Float32>.self)[3] = .init(1, 1)
//        residency.addAllocation(buffer)
//        
//        let cstableDescriptor = MTL4ArgumentTableDescriptor()
//        cstableDescriptor.maxTextureBindCount = 2
//        let cstable = try device.makeArgumentTable(descriptor: cstableDescriptor)
//        cstable.setTexture(texture.gpuResourceID, index: 0)
//        cstable.setTexture(uniform.gpuResourceID, index: 1)
//        
//        let vstableDescriptor = MTL4ArgumentTableDescriptor()
//        vstableDescriptor.maxBufferBindCount = 2
//        let vstable = try device.makeArgumentTable(descriptor: vstableDescriptor)
//        vstable.setAddress(buffer.gpuAddress, index: 0)
//        
//        let rot = device.makeBuffer(length: MemoryLayout<UInt32>.stride).unsafelyUnwrapped
//        vstable.setAddress(rot.gpuAddress, index: 1)
//        let idx = Atomic<UInt32>(.zero)
//        residency.addAllocation(rot)
//        
//        let fstableDescriptor = MTL4ArgumentTableDescriptor()
//        fstableDescriptor.maxTextureBindCount = 1
//        let fstable = try device.makeArgumentTable(descriptor: fstableDescriptor)
//        fstable.setTexture(texture.gpuResourceID, index: 0)
//        
//        
//        
//        return {
//            
////            rot.contents().storeBytes(of: idx.add(1, ordering: .acquiringAndReleasing).oldValue, as: UInt32.self)
//            
//            for _ in 0..<6 {
//                do {
//                    let encoder = $1.makeComputeCommandEncoder()
//                    encoder?.setComputePipelineState(kernel)
//                    encoder?.setArgumentTable(cstable)
//                    encoder?.dispatchThreadgroups(threadgroupsPerGrid: .init(width: 32, height: 32, depth: 1),
//                                                  threadsPerThreadgroup: .init(width: 32, height: 32, depth: 1))
//                    encoder?.endEncoding()
//                }
//            }
//           
//            do {
//                let descriptor = MTL4RenderPassDescriptor()
//                descriptor.colorAttachments[0].texture = $2
//                descriptor.colorAttachments[0].loadAction = .clear
//                descriptor.colorAttachments[0].storeAction = .store
//                descriptor.colorAttachments[0].clearColor = .init(red: 1, green: 1, blue: 1, alpha: 1)
//                
//                let encoder = $1.makeRenderCommandEncoder(descriptor: descriptor).unsafelyUnwrapped
//                encoder.setRenderPipelineState(pipeline)
//                encoder.setArgumentTable(vstable, stages: .vertex)
//                encoder.setArgumentTable(fstable, stages: .fragment)
//                encoder.drawPrimitives(primitiveType: .triangleStrip, vertexStart: 0, vertexCount: 4)
//                encoder.endEncoding()
//            }
//            
//        }
//    }
//}
