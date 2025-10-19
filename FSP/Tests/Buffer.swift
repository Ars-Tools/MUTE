//
//  Buffer.swift
//  MUTE
//
//  Created by Kota on 10/14/25.
//
import Accelerate
import Testing
import DSP
@Suite
struct BufferTestCases {
    @Test
    func flush() {
        let buffer = Buffer(stream: 2, period: 1024)
        let value = Float64.random(in: -1...1)
        buffer.start.initialize(repeating: value, count: 2 * 1024)
        buffer.flush(cursor: 768, length: 512)
        #expect(UnsafeBufferPointer(start: buffer.start.advanced(by:  768), count: 256).allSatisfy { $0 == .zero })
        #expect(UnsafeBufferPointer(start: buffer.start.advanced(by:    0), count: 256).allSatisfy { $0 == .zero })
        #expect(UnsafeBufferPointer(start: buffer.start.advanced(by:  256), count: 512).allSatisfy { $0 == value })
        #expect(UnsafeBufferPointer(start: buffer.start.advanced(by: 1792), count: 256).allSatisfy { $0 == .zero })
        #expect(UnsafeBufferPointer(start: buffer.start.advanced(by: 1024), count: 256).allSatisfy { $0 == .zero })
        #expect(UnsafeBufferPointer(start: buffer.start.advanced(by: 1280), count: 512).allSatisfy { $0 == value })
    }
    @Test
    func fetch() {
        let buffer = Buffer(stream: 1, period: 2048)
        let window = Framewise.Window.hanning(512 as Samples).coefficients(for: .indefinite)
        let random = repeatElement(-64 ... 64 as ClosedRange<Int32>, count: window.count).map(Int32.random(in:))
        let source = vDSP.integerToFloatingPoint(random, floatingPointType: Float64.self)
        var target = Array<Float64>(repeating: .zero, count: window.count)
        buffer.copy(cursor: 2048 - 256, length: source.count, source: source, stride: source.count)
        buffer.fetch(cursor: 2048 - 256, length: target.count, window: window, target: &target, stride: target.count)
        #expect(zip(zip(window, source).map(*), target).map(-).map(\.magnitude).allSatisfy { $0 < 1e-6 })
    }
    @Test
    func merge() {
        let buffer = Buffer(stream: 1, period: 2048)
        let window = Framewise.Window.hanning(512 as Samples).coefficients(for: .indefinite)
        let random = repeatElement(-64 ... 64 as ClosedRange<Int32>, count: window.count).map(Int32.random(in:))
        let source = vDSP.integerToFloatingPoint(random, floatingPointType: Float64.self)
        buffer.start.initialize(repeating: 6, count: 2048)
        buffer.merge(cursor: 2048 - 256, length: source.count, window: window, source: source, stride: source.count)
        let result = UnsafeBufferPointer(start: buffer.start, count: 2048)
        let target = zip(window, source).map(*)
        #expect(result[256..<768].allSatisfy { $0 == 6 })
        #expect(zip(result.suffix(256), target.prefix(256)).map(-).allSatisfy { (6 - $0).magnitude < 1e-6  })
        #expect(zip(result.prefix(256), target.suffix(256)).map(-).allSatisfy { (6 - $0).magnitude < 1e-6  })
    }
}
