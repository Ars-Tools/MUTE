//
//  Buffer+Object.swift
//  MUTE
//
//  Created by Kota on 11/27/25.
//
import typealias Synchronization.Mutex
import typealias CoreMedia.CMTime
import typealias CoreMedia.CMTimeRange
import func CoreMedia.CMTimeMultiply
extension Buffer {
    public protocol Object: Stream {
        @inlinable func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> (Buffer, Optional<@Sendable(CMTime, Int) -> Void>)
    }
}
extension Buffer.Object {
    @inlinable
    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable(CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        return switch try callAsFunction(interval: interval, capacity: capacity, instance: &instance) {
        case (let buffer, .some(let kernel)):
            {
                kernel($0, $1)
                buffer.copy(cursor: $0.samples(for: interval), length: $1, target: $2, stride: $3)
            }
        case (let buffer, .none):
            {
                buffer.copy(cursor: $0.samples(for: interval), length: $1, target: $2, stride: $3)
            }
        }
    }
}
extension Buffer {
    @usableFromInline
    final class Cache: Identifiable, Sendable {
        @usableFromInline let upstream: Stream
        @usableFromInline let duration: Duration
        init(upstream: Stream, capacity: Duration) {
            self.upstream = upstream
            self.duration = capacity
        }
    }
}
extension Buffer.Cache: Buffer.Object {
    @inlinable
    var count: Int {
        upstream.count
    }
    @usableFromInline
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> (Buffer, Optional<@Sendable(CMTime, Int) -> Void>) {
        switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
        case.some((let buffer, let kernel) as (Buffer, @Sendable(CMTime, Int) -> Void)):
            return (buffer, kernel)
        case.none:
            let source = try upstream(interval: interval, capacity: capacity, instance: &instance)
            let buffer = Buffer(stream: upstream.count, period: capacity + duration.samples(for: interval))
            let locker = Mutex(CMTime.invalid)
            let kernel = { moment, length in
                locker.withLock {
                    if CMTimeRange(start: moment, duration: CMTimeMultiply(interval, multiplier: .init(length))).containsTime($0) {
                        buffer.copy(cursor: moment.samples(for: interval), length: length) {
                            source(moment, length, $0, $1)
                        }
                        $0 = moment
                    }
                }
            } as @Sendable (CMTime, Int) -> Void
            instance.updateValue((buffer, kernel), forKey: .init(interval: interval, capacity: capacity, identity: id))
            return (buffer, kernel)
        case.some:
            throw Error.resourceConflict
        }
    }
}
extension Buffer {
    @usableFromInline
    struct WeakRef: Sendable {
        @usableFromInline weak var rawValue: Optional<Buffer.Object & AnyObject>
    }
}
extension Buffer.WeakRef: Buffer.Object {
    @inlinable
    var count: Int {
        rawValue.map(\.count) ?? 0
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> (Buffer, Optional<@Sendable (CMTime, Int) -> Void>) {
        guard let rawValue else { throw Error.lackOfResource("buffer is nil")}
        return try rawValue.callAsFunction(interval: interval, capacity: capacity, instance: &instance)
    }
}
public func buffer(_ upstream: Stream, capacity: Duration = 0 as Float64) -> some Buffer.Object & AnyObject {
    Buffer.Cache(upstream: upstream, capacity: capacity)
}

//extension Buffer: Buffer.Object {
//    @inlinable
//    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> Buffer {
//        self
//    }
//}
//extension Buffer {
//    final class Handle: Identifiable, Sendable {
//        @usableFromInline let stream: Int
//        @usableFromInline let period: Duration
//        @inlinable
//        init(stream: Int, period: Duration) {
//            self.stream = stream
//            self.period = period
//        }
//    }
//}
//extension Buffer.Object {
//    @inlinable
//    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
//        let buffer = try callAsFunction(interval: interval, capacity: capacity, instance: &instance)
//        return { moment, length in
//            buffer
//        }
//    }
//}
//extension Buffer: Buffer.Object {
//    @inlinable
//    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> Buffer {
//        self
//    }
//}
//extension Buffer {
//    @usableFromInline
//    final class Handle: Identifiable, Sendable {
//        @usableFromInline let stream: Int
//        @usableFromInline let period: Duration
//        @inlinable
//        init(stream: Int, period: Duration) {
//            self.stream = stream
//            self.period = period
//        }
//    }
//}
//extension Buffer.Handle: Buffer.Object {
//    @inlinable
//    var count: Int {
//        stream
//    }
//    @usableFromInline
//    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> Buffer {
//        switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
//        case.some(let buffer as Buffer):
//            return buffer
//        case.none:
//            let buffer = Buffer(stream: stream, period: capacity + period.samples(for: interval))
//            instance.updateValue(buffer, forKey: .init(interval: interval, capacity: capacity, identity: id))
//            return buffer
//        case.some:
//            throw Error.resourceConflict
//        }
//    }
//}
