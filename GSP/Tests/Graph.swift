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
import simd
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
        
        #expect(x.buffer != nil)
        #expect(y.buffer != nil)
        
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
    @Test
    func axisMapping() {
        let linear = Graph.Axis(-1 ... 1)
        #expect(abs(linear.normalized(0)) < 1.0e-6)

        let logarithmic = Graph.Axis(1 ... 100, scale: .logarithmic())
        #expect(abs(logarithmic.normalized(10)) < 1.0e-5)
    }
    @Test
    func waveformGPUVertices() throws {
        let processor = try GPUProcessor(device: device)
        let viewport = Graph.Viewport(x: .init(0 ... 3), y: .init(-1 ... 1))
        let vertices = try processor.waveformVertices(samples: [0, 1, 0, -1], sampleRate: 1, viewport: viewport)
        #expect(vertices.count == 4)
        #expect(abs(vertices[0].x + 1) < 1.0e-5)
        #expect(abs(vertices[1].y - 1) < 1.0e-5)
    }
    @Test
    func spectrumGPUVertices() throws {
        let processor = try GPUProcessor(device: device)
        let viewport = Graph.Viewport(x: .init(0 ... 2), y: .init(0 ... 1))
        let result = try processor.spectrum(samples: [0, 1, 0, -1], sampleRate: 4, viewport: viewport)
        #expect(result.vertices.count == 3)
        #expect(result.magnitudes[0] < 1.0e-5)
        #expect(result.magnitudes[1] > 0.49)
    }
    @Test
    func poleZeroAndMeshPrepareOnGPU() throws {
        let processor = try GPUProcessor(device: device)
        let poleZero = Graph.PoleZero(
            poles: [SIMD2<Float>(0.5, 0.25)],
            zeros: [SIMD2<Float>(-0.25, 0.5)],
            unitCircleSegments: 8
        )
        let preparedPoleZero = try poleZero.prepare(using: processor)
        #expect(preparedPoleZero.unitCircleCount == 9)
        #expect(preparedPoleZero.poleCount == 1)
        #expect(preparedPoleZero.zeroCount == 1)

        let preparedMesh = try Graph.MeshModel.cube.prepareWireframe(
            using: processor,
            modelViewProjection: matrix_identity_float4x4
        )
        #expect(preparedMesh.indexCount == 72)
    }

    @Test
    func bezierLineAndClose() {
        let seg = Bezier.Seg.line(from: .zero, to: SIMD2<Float>(1, 0))
        #expect(simd_distance(seg.point(0.5), SIMD2<Float>(0.5, 0)) < 1.0e-6)
        #expect(simd_distance(seg.normal(0.5), SIMD2<Float>(0, -1)) < 1.0e-6)

        var path = Bezier.Path()
        path.add(.zero)
        path.add(SIMD2<Float>(1, 0))
        path.add(SIMD2<Float>(1, 1))
        path.close()
        #expect(path.closed)
        #expect(path.segs.count == 3)
    }
}
