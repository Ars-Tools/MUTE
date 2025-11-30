//
//  Buffer+Pull.swift
//  MUTE
//
//  Created by Kota on 11/29/25.
//
import typealias Synchronization.Mutex
import typealias CoreMedia.CMTime
import typealias CoreMedia.CMTimeRange
import func CoreMedia.CMTimeAdd
import func CoreMedia.CMTimeMultiply
import os.log
extension Buffer {
    @usableFromInline
    final class Pipe<Source: Stream, Period: Duration>: Identifiable, Sendable {
        @usableFromInline let source: Source
        @usableFromInline let period: Period
        @inlinable
        init(source: Source, period: Period) {
            self.source = source
            self.period = period
        }
    }
    @usableFromInline
    final class Push: Identifiable, @unchecked Sendable {
        @usableFromInline var source: Stream
        @usableFromInline let target: Buffer.Object
        @inlinable init(target: Buffer.Object) {
            self.source = φ(count: target.count)
            self.target = target
        }
    }
    @usableFromInline
    final class Pull: Identifiable, @unchecked Sendable {
        @usableFromInline weak var source: Optional<Push>
        @usableFromInline let stream: Int
        @usableFromInline let period: Duration
        @inlinable init(stream: Int, period: Duration) {
            self.stream = stream
            self.period = period
            self.source = .none
        }
    }
}
extension Buffer.Pipe: Buffer.Object {
    @inlinable
    var count: Int {
        source.count
    }
    @usableFromInline
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
        typealias Kernel = @Sendable (CMTime, Int) -> Buffer
        switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
        case.some(let kernel as Kernel):
            return kernel
        case.none:
            let buffer = Buffer(stream: source.count, period: period.samples(for: interval) &+ capacity)
            let update = try source(interval: interval, capacity: capacity, instance: &instance)
            let latest = Mutex<CMTime>(.indefinite)
            let kernel = { moment, length in
                latest.withLock {
                    if !CMTimeRange(start: moment, duration: CMTimeMultiply(interval, multiplier: .init(length))).containsTime($0) {
                        buffer.copy(cursor: moment.samples(for: interval), length: length) {
                            update(CMTimeAdd(moment, CMTimeMultiply(interval, multiplier: .init($0))), $1, $2, $3)
                        }
                        $0 = moment
                    }
                    return buffer
                }
            } as Kernel
            defer {
                instance.updateValue(kernel, forKey: .init(interval: interval, capacity: capacity, identity: id))
            }
            return kernel
        case.some:
            throw TypedError.resourceConflict(of: self, interval: interval, capacity: capacity)
        }
    }
}
extension Buffer.Push: Buffer.Notify {
    
}
extension Buffer.Pull: Buffer.Object {
    @inlinable
    var count: Int {
        stream
    }
    @usableFromInline
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer {
        switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
        case.some(let buffer as Buffer):
            return { moment, length in buffer }
        case.none:
            let buffer = Buffer(stream: stream, period: period.samples(for: interval) &+ capacity)
            instance.updateValue(buffer, forKey: .init(interval: interval, capacity: capacity, identity: id))
            switch source {
            case.some(let source):
                try source(interval: interval, capacity: capacity, instance: &instance) as Void
            case.none:
                os_log(.debug, "buffer will be never kept up date")
            }
            return { moment, length in buffer }
        case.some:
            throw TypedError.resourceConflict(of: self, interval: interval, capacity: capacity)
        }
    }
}
public func buffer(_ upstream: some Stream, capacity: some Duration = 0.0 as Float64) -> some Buffer.Object {
    Buffer.Pipe(source: upstream, period: capacity)
}
public func buffer(_ count: Int, capacity: Duration) -> (some Buffer.Notify, some Buffer.Object) {
    let target = Buffer.Pull(stream: count, period: capacity)
    let source = Buffer.Push(target: target)
    target.source = source
    return (source, target)
}
