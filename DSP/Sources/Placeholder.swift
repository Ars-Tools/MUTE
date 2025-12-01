//
//  Generator+Placeholder.swift
//  MUTE
//
//  Created by Kota on 12/1/25.
//
import typealias Auxiliary.Autorelease
public enum Placeholder {
    public struct Buffer {
        @usableFromInline let stream: Int
        @usableFromInline let offset: Int
        @usableFromInline let length: Int
        @usableFromInline let buffer: Autorelease.Memory
    }
}
extension Placeholder.Buffer {
    @inlinable
    public init(stream: Int, length: Int) {
        self.stream = stream
        self.length = length
        offset = 0
        buffer = .init(repeating: 0 as Float64, count: stream * length)
    }
}
extension Placeholder.Buffer {
    @inlinable
    var memory: UnsafeMutablePointer<Float64> {
        buffer.start.advanced(by: offset).assumingMemoryBound(to: Float64.self)
    }
}
extension Placeholder.Buffer {
    @inlinable
    public func set(source: UnsafePointer<Float64>, stride: Int) {
        DSP.copy(x: source, ldx: stride,
                 y: memory, ldy: length,
                 rows: stream, cols: length)
    }
}
extension Placeholder.Buffer: Stream {
    @inlinable
    public var count: Int {
        stream
    }
    @inlinable
    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        {
            DSP.copy(x: memory, ldx: length,
                     y: $2, ldy: $3,
                     rows: stream, cols: length)
        }
    }
}
extension Placeholder.Buffer: RandomAccessCollection {
    @inlinable
    public var startIndex: Int { 0 }
    @inlinable
    public var endIndex: Int { count }
    @inlinable
    public subscript(position: Int) -> Placeholder.Buffer {
        self[position...position]
    }
    public subscript(bounds: some RangeExpression<Int>) -> Placeholder.Buffer {
        let bounds = bounds.relative(to: startIndex..<endIndex)
        return.init(stream: bounds.count,
                    offset: offset + bounds.lowerBound * MemoryLayout<Float64>.stride,
                    length: length,
                    buffer: buffer)
    }
}
