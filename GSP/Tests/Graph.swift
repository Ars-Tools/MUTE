//
//  Graph.swift
//  MUTE
//
//  Created by Kota on 10/31/25.
//
import Accelerate
import Testing
import Metal
import CoreImage
@testable import GSP
@Suite
struct GraphTestCases {
    let context: CIContext
    let device: MTLDevice
    let image: MTLTexture
    let queue: MTLCommandQueue
    init() {
        device = MTLCreateSystemDefaultDevice().unsafelyUnwrapped
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                  width: 512,
                                                                  height: 512, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        image = device.makeTexture(descriptor: descriptor).unsafelyUnwrapped
        queue = device.makeCommandQueue().unsafelyUnwrapped
        context = .init(mtlCommandQueue: queue)
    }
    @_transparent
    func store(to url: URL) throws {
        try context.writePNGRepresentation(of: .init(mtlTexture: image).unsafelyUnwrapped,
                                           to: url,
                                           format: .BGRA8,
                                           colorSpace: context.workingColorSpace ?? CGColorSpaceCreateDeviceRGB())
    }
    @Test
    func range() {
        let graph = Graph.LinLin(device: device)
        graph.xrange = -1 ... 1
        print(graph.xrange)
    }
    @Test
    func linlin() throws {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].clearColor = .init(red: 1, green: 1, blue: 0, alpha: 1)
        descriptor.colorAttachments[0].texture = image
        
        let commandBuffer = queue.makeCommandBuffer().unsafelyUnwrapped
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        try store(to: .init(filePath: "/tmp/dump.png"))
        
    }
    @Test
    func loglog() throws {
        let graph = try Graph.LogLog(format: .bgra8Unorm, device: device)
        graph.xrange = 1 ... 16
        graph.yrange = 1 ... 16
        
        let descriptor = MTLTensorDescriptor()
        descriptor.dimensions = .init([16, 16]).unsafelyUnwrapped
        descriptor.dataType = .float32
        descriptor.storageMode = .shared
        descriptor.resourceOptions = .storageModeShared
        descriptor.usage = .render
        
        let x = try device.makeTensor(descriptor: descriptor)
        let y = try device.makeTensor(descriptor: descriptor)
        
        print(x.buffer)
        
        
        
        
        
        
//
//        var xbuf = UnsafeMutableRawBufferPointer(start: x.buffer!.contents(), count: x.buffer!.length).assumingMemoryBound(to: Float32.self)
//        var ybuf = UnsafeMutableRawBufferPointer(start: y.buffer!.contents(), count: y.buffer!.length).assumingMemoryBound(to: Float32.self)
//        
//        vDSP.formRamp(in: 1 ... 16, result: &xbuf)
//        vDSP.formRamp(in: 1 ... 16, result: &ybuf)
//        vDSP.reverse(&ybuf)
//        
//        graph.append(x: x, y: y, color: .red)
//        
//        let mtlCommandBuffer = queue.makeCommandBuffer().unsafelyUnwrapped
//        graph.render(at: 0, to: image, with: mtlCommandBuffer)
//        mtlCommandBuffer.commit()
//        mtlCommandBuffer.waitUntilCompleted()
//        
//        try store(to: .init(filePath: "/tmp/dump.png"))
        
    }
}
