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
        @usableFromInline let length: Int
        @usableFromInline let buffer: Autorelease.Memory
    }
}
extension Placeholder.Buffer {
    @inlinable
    public init(stream: Int, length: Int) {
        self.stream = stream
        self.length = length
        buffer = .init(repeating: 0 as Float64, count: stream * length)
    }
}
extension Placeholder.Buffer {
    @inlinable
    public func set(source: UnsafePointer<Float64>, stride: Int) {
        DSP.copy(x: source, ldx: stride,
                 y: buffer.start.assumingMemoryBound(to: Float64.self), ldy: length,
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
            DSP.copy(x: buffer.start.assumingMemoryBound(to: Float64.self), ldx: length,
                     y: $2, ldy: $3,
                     rows: stream, cols: length)
        }
    }
}
