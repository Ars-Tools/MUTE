//
//  TexTable.swift
//  MUTE
//
//  Created by Kota on 12/3/25.
//
@preconcurrency import Metal
@preconcurrency import MetalPerformanceShaders
@preconcurrency import Combine
@preconcurrency import CoreMedia.CMTime
import Synchronization
import Accelerate
import DSP
import NSP
@usableFromInline
enum TextureTable {
    @usableFromInline
    struct Kr<Index: Publisher<Int, Never> & Sendable>: Sendable {
        @usableFromInline let matrix: MPSMatrix
        @usableFromInline let tensor: MTLTensor
        @usableFromInline let index: Index
    }
}
extension TextureTable.Kr {
    public init(device: MTLDevice, stream: Int, length: Int, index: Index) {
        let descriptor = MPSMatrixDescriptor(rows: stream,
                                             columns: length,
                                             rowBytes: MPSMatrixDescriptor.rowBytes(forColumns: length, dataType: .float32),
                                             dataType: .float32)
        matrix = MPSMatrix(buffer: device.makeBuffer(length: descriptor.matrixBytes, options: .storageModeShared).unsafelyUnwrapped,
                       descriptor: descriptor)
        //
        do {
            let descriptor = MTLTensorDescriptor()
            descriptor.dataType = .float32
            descriptor.usage = .compute
            descriptor.storageMode = .shared
            descriptor.dimensions = .init([stream, length]).unsafelyUnwrapped
            tensor = try!device.makeTensor(descriptor: descriptor)
        }
        self.index = index
    }
    public var texture: MTLTexture {
        matrix.data.makeTexture(descriptor: .texture2DDescriptor(pixelFormat: .r32Float,
                                                                 width: matrix.columns,
                                                                 height: matrix.rows,
                                                                 mipmapped: false),
                                offset: 0,
                                bytesPerRow: matrix.rowBytes).unsafelyUnwrapped
    }
}
extension TextureTable.Kr: DSP.Buffer.Object {
    @inlinable
    var count: Int {
//        shape.y
        1
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
        let buffer = Buffer(stream: 1, period: matrix.columns)
        let offset = Atomic<Int>(.zero)
        let cancel = index.sink {
            offset.store($0 * matrix.rowBytes, ordering: .releasing)
        }
        return { [cancel] moment, length in
            vDSP_vspdp(matrix.data.contents().advanced(by: offset.load(ordering: .acquiring)).assumingMemoryBound(to: Float32.self), 1,
                       buffer.start, 1,
                       .init(matrix.columns))
            return buffer
        }
    }
//    @inlinable
//    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//        let stride = Self.rowBytes(for: shape.y)
//        let offset = Atomic<Int>(0)
//        let cancel = index.sink {
//            offset.store($0, ordering: .releasing)
//        }
//        return { [cancel] in
//            let buffer = Array<Float64>(unsafeUninitializedCapacity: shape.y) {
//                let start = table.contents().advanced(by: offset.load(ordering: .acquiring) * Self.rowBytes(for: shape.x))
//                vDSP.convertElements(of: UnsafeBufferPointer(start: start.assumingMemoryBound(to: Float32.self), count: shape.x),
//                                     to: &$0)
//                $1 = $0.count
//            }
//            for k in (0..<shape.x).reversed() {
//                
//            }
//        }
//    }
}
