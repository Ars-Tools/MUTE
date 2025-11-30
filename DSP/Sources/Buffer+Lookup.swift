//
//  Buffer+Lookup.swift
//  MUTE
//
//  Created by Kota on 7/15/R7.
//
import func Layout.broadcast
import func Layout.zip
import func NSP.periodic_lookup_with_static
import func Accelerate.vDSP_vsmulD
extension Buffer {
    @usableFromInline
    struct Cursor: Sendable {
        @usableFromInline let source: Buffer.Object
        @usableFromInline let elapse: Stream
    }
}
extension Buffer.Cursor: Stream {
    @inlinable
    var count: Int {
        broadcast(x: source.count, y: elapse.count)
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let buffer = try source(interval: interval, capacity: capacity, instance: &instance)
        let kernel = try elapse(interval: interval, capacity: capacity, instance: &instance)
        let factor = Float64(interval.timescale) / Float64(interval.value)
        let xc = source.count
        let yc = elapse.count
        switch broadcast(x: xc, y: yc) {
        case xc:
            return {
                let xb = buffer($0, $1)
                let xs = xb.period
                kernel($0, $1, $2, $3)
                let ys = broadcast(target: xc, source: yc, stride: $3)
                for k in 0..<yc {
                    vDSP_vsmulD($2.advanced(by: k * $3), 1,
                                withUnsafePointer(to: factor, \.self),
                                $2.advanced(by: k * $3), 1, .init($1))
                }
                for k in (0..<xc).reversed() {
                    periodic_lookup_with_static(xb.start.advanced(by: k * xs),
                                                $2.advanced(by: k * ys),
                                                $2.advanced(by: k * $3),
                                                xb.period, $1)
                }
            }
        case yc:
            return {
                let xb = buffer($0, $1)
                let xs = broadcast(target: yc, source: xc, stride: xb.period)
                kernel($0, $1, $2, $3)
                let ys = $3
                for k in (0..<yc).reversed() {
                    vDSP_vsmulD($2.advanced(by: k * $3), 1,
                                withUnsafePointer(to: factor, \.self),
                                $2.advanced(by: k * $3), 1, .init($1))
                    periodic_lookup_with_static(xb.start.advanced(by: k * xs),
                                                $2.advanced(by: k * ys),
                                                $2.advanced(by: k * $3),
                                                xb.period, $1)
                }
            }
        case let zc:
            throw TypedError.invalidChannel(of: self, require: zc)
        }
    }
}
extension Buffer.Object {
    public func callAsFunction(_ elapse: some Stream) -> some Stream {
        Buffer.Cursor(source: self, elapse: elapse)
    }
    public subscript(_ elapse: some Stream) -> some Stream {
        Buffer.Cursor(source: self, elapse: elapse)
    }
}
