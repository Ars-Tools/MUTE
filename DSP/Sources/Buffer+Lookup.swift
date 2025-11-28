//
//  Buffer+Lookup.swift
//  MUTE
//
//  Created by Kota on 7/15/R7.
//
import func Layout.broadcast
import func Layout.zip
import func NSP.periodic_lookup_with_static
import Synchronization
import CoreMedia
import func Accelerate.vDSP_vsmulD
extension Buffer {
    @usableFromInline
    struct Ref: Sendable {
        @usableFromInline let source: Buffer.Object
        @usableFromInline let elapse: Stream
    }
}
extension Buffer.Ref: Stream {
    @inlinable
    public var count: Int {
        broadcast(x: source.count, y: elapse.count)
    }
    @inlinable
    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try elapse(interval: interval, capacity: capacity, instance: &instance)
        let factor = Float64(interval.timescale) / Float64(interval.value)
        let xc = source.count
        let yc = elapse.count
        switch try source(interval: interval, capacity: capacity, instance: &instance) {
        case(let buffer, .some(let update)):
            let locker = Mutex<CMTime>(.invalid)
            switch broadcast(x: xc, y: yc) {
            case xc:
                return { moment, length, target, stride in
                    locker.withLock {
                        if CMTimeRange(start: moment, duration: CMTimeMultiply(interval, multiplier: .init(length))).containsTime($0) {
                            update(moment, length)
                            $0 = moment
                        }
                    }
                    kernel(moment, length, target, stride)
                    for k in 0..<yc {
                        vDSP_vsmulD(target.advanced(by: k * stride), 1, withUnsafePointer(to: factor, \.self), target.advanced(by: k * stride), 1, .init(length))
                    }
                    let ys = broadcast(target: xc, source: yc, stride: stride)
                    for k in 0..<xc {
                        periodic_lookup_with_static(buffer.start.advanced(by: k * buffer.period),
                                                    target.advanced(by: k * ys),
                                                    target.advanced(by: k * stride),
                                                    buffer.period, length)
                    }
                }
            case yc:
                let xs = broadcast(target: yc, source: xc, stride: buffer.period)
                return { moment, length, target, stride in
                    locker.withLock {
                        if CMTimeRange(start: moment, duration: CMTimeMultiply(interval, multiplier: .init(length))).containsTime($0) {
                            update(moment, length)
                            $0 = moment
                        }
                    }
                    kernel(moment, length, target, stride)
                    for k in 0..<yc {
                        vDSP_vsmulD(target.advanced(by: k * stride), 1, withUnsafePointer(to: factor, \.self), target.advanced(by: k * stride), 1, .init(length))
                        periodic_lookup_with_static(buffer.start.advanced(by: k * xs),
                                                    target.advanced(by: k * stride),
                                                    target.advanced(by: k * stride),
                                                    buffer.period, length)
                    }
                }
            default:
                throw Error.invalidChannel
            }
        case(let buffer, .none):
            switch broadcast(x: xc, y: yc) {
            case xc:
                return { moment, length, target, stride in
                    kernel(moment, length, target, stride)
                    for k in 0..<yc {
                        vDSP_vsmulD(target.advanced(by: k * stride), 1, withUnsafePointer(to: factor, \.self), target.advanced(by: k * stride), 1, .init(length))
                    }
                    let ys = broadcast(target: xc, source: yc, stride: stride)
                    for k in 0..<xc {
                        periodic_lookup_with_static(buffer.start.advanced(by: k * buffer.period),
                                                    target.advanced(by: k * ys),
                                                    target.advanced(by: k * stride),
                                                    buffer.period, length)
                    }
                }
            case yc:
                let xs = broadcast(target: yc, source: xc, stride: buffer.period)
                return { moment, length, target, stride in
                    kernel(moment, length, target, stride)
                    for k in 0..<yc {
                        vDSP_vsmulD(target.advanced(by: k * stride), 1, withUnsafePointer(to: factor, \.self), target.advanced(by: k * stride), 1, .init(length))
                        periodic_lookup_with_static(buffer.start.advanced(by: k * xs),
                                                    target.advanced(by: k * stride),
                                                    target.advanced(by: k * stride),
                                                    buffer.period, length)
                    }
                }
            default:
                throw Error.invalidChannel
            }
        }
    }
}
extension Buffer {
    public final class RefWeak: @unchecked Sendable {
        public weak var source: Optional<Buffer.Object & AnyObject>
        @usableFromInline let stream: Int
        @usableFromInline let elapse: Stream
        init(count: Int, elapse: Stream) {
            self.stream = count
            self.elapse = elapse
            self.source = .none
        }
    }
}
extension Buffer.RefWeak: Stream {
    @inlinable
    public var count: Int {
        stream
    }
    @inlinable
    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        guard let source else { throw Error.lackOfResource("buffer") }
        let buffer = try source(interval: interval, capacity: capacity, instance: &instance).0
        let kernel = try elapse(interval: interval, capacity: capacity, instance: &instance)
        let factor = Float64(interval.timescale) / Float64(interval.value)
        let xc = source.count
        let yc = elapse.count
        let zc = count
        let xs = broadcast(target: zc, source: xc, stride: buffer.period)
        return {
            kernel($0, $1, $2, $3)
            for k in 0..<yc {
                vDSP_vsmulD($2.advanced(by: k * $3), 1, withUnsafePointer(to: factor, \.self), $2.advanced(by: k * $3), 1, .init($1))
            }
            let ys = broadcast(target: xc, source: yc, stride: $3)
            for k in 0..<xc {
                periodic_lookup_with_static(buffer.start.advanced(by: k * xs),
                                            $2.advanced(by: k * ys),
                                            $2.advanced(by: k * $3),
                                            buffer.period, $1)
            }
        }
    }
}
extension Buffer.Object {
    public subscript(_ elapse: some Stream) -> some Stream {
        Buffer.Ref(source: self, elapse: elapse)
    }
}
