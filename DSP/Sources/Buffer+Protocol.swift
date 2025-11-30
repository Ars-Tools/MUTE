//
//  Buffer+Protocol.swift
//  MUTE
//
//  Created by Kota on 11/27/25.
//
import typealias Synchronization.Mutex
import typealias CoreMedia.CMTime
import typealias CoreMedia.CMTimeRange
import func CoreMedia.CMTimeAdd
import func CoreMedia.CMTimeMultiply
import Auxiliary
extension Buffer {
    public protocol Object: Sendable, Stream {
        @inlinable func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int) -> Buffer
    }
    public protocol Notify: Sendable, Effect {
        @inlinable var source: Stream { get nonmutating set }
        @inlinable var target: Buffer.Object { get }
    }
}
extension Buffer.Object {
    @inlinable
    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try callAsFunction(interval: interval, capacity: capacity, instance: &instance)
        return {
            kernel($0, $1).copy(cursor: $0.samples(for: interval), length: $1, target: $2, stride: $3)
        }
    }
}
extension Buffer.Notify where Self: AnyObject & Identifiable {
    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws {
        switch instance[.init(interval: interval, capacity: capacity, identity: id)] {
        case.some(is Commit.Element):
            break
        case.none:
            let buffer = try target(interval: interval, capacity: capacity, instance: &instance)
            let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
            instance.updateValue({ moment, length in
                buffer(moment, length).copy(cursor: moment.samples(for: interval), length: length) {
                    kernel(CMTimeAdd(moment, CMTimeMultiply(interval, multiplier: .init($0))), $1, $2, $3)
                }
            } as Commit.Element, forKey: .init(interval: interval, capacity: capacity, identity: id))
        case.some:
            throw TypedError.resourceConflict(of: self, interval: interval, capacity: capacity)
        }
    }
}
