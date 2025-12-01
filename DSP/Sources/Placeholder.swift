//
//  Generator+Placeholder.swift
//  MUTE
//
//  Created by Kota on 12/1/25.
//
import typealias Accelerate.vDSP
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias Auxiliary.Autorelease
import os.log
public enum Placeholder {
    public struct Buffer {
        @usableFromInline let stream: Int
        @usableFromInline let period: Int
        @usableFromInline let offset: Int
        @usableFromInline let buffer: Autorelease.Memory
    }
    public final class Memory: Identifiable, @unchecked Sendable {
        public let count: Int
        @usableFromInline var store: Optional<(UnsafePointer<Float64>, Int)>
        @inlinable
        public init(stream: Int) {
            count = stream
            store = .none
        }
    }
}
extension Placeholder.Memory: Effect {
    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws {
        switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
        case.some(is Commit.Element):
            break
        case.none:
            instance.updateValue({ [self] moment, length in
                store = .none
            } as Commit.Element, forKey: .init(interval: interval, capacity: capacity, identity: id))
        case.some:
            throw TypedError.resourceConflict(of: self, interval: interval, capacity: capacity)
        }
    }
}
extension Placeholder.Memory: Stream {
    @inlinable
    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        try callAsFunction(interval: interval, capacity: capacity, instance: &instance) as Void
        return { [self] in
            switch store {
            case.some((let memory, let stride)):
                DSP.copy(x: memory, ldx: stride,
                         y: $2, ldy: $3,
                         rows: count, cols: $1)
            case.none:
                os_log(.error, "placeholder is empty")
                for var target in fold(start: $2, count: $1, stream: count, period: $3) {
                    vDSP.clear(&target)
                }
            }
        }
    }
}
extension Placeholder.Memory {
    @inlinable
    public func set(memory: UnsafePointer<Float64>, stride: Int) {
        store = (memory, stride)
    }
}
extension Placeholder.Buffer {
    @inlinable
    public init(stream: Int, length: Int) {
        self.stream = stream
        period = length
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
    public func set(source: UnsafePointer<Float64>, stride: Int, length: Int) {
        DSP.copy(x: source, ldx: stride,
                 y: memory, ldy: period,
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
            DSP.copy(x: memory, ldx: period,
                     y: $2, ldy: $3,
                     rows: stream, cols: $1)
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
                    period: period,
                    offset: offset + bounds.lowerBound * period * MemoryLayout<Float64>.stride,
                    buffer: buffer)
    }
}
