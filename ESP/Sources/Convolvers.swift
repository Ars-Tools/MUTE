//
//  Convolvers.swift
//  MUTE
//
//  Created by Kota on 8/6/26.
//
import protocol Accelerate.AccelerateBuffer
public enum Convolvers: Sendable {}
extension Convolvers {
    public protocol `Protocol`: Sendable {
        @inlinable
        func convolve(x: UnsafePointer<Float64>, count xc: Int,
                      y: UnsafePointer<Float64>, count yc: Int,
                      z: UnsafeMutablePointer<Float64>)
        @inlinable
        func convolve(x: some AccelerateBuffer<Float64>,
                      y: some AccelerateBuffer<Float64>) -> Array<Float64>
    }
}
extension Convolvers.`Protocol` {
    @inlinable
    public func convolve(x: some AccelerateBuffer<Float64>,
                         y: some AccelerateBuffer<Float64>) -> Array<Float64> {
        x.withUnsafeBufferPointer { x in
            y.withUnsafeBufferPointer { y in
                    .init(unsafeUninitializedCapacity: x.count + y.count - 1) {
                        convolve(x: x.baseAddress.unsafelyUnwrapped, count: x.count,
                                 y: y.baseAddress.unsafelyUnwrapped, count: y.count,
                                 z: $0.baseAddress.unsafelyUnwrapped)
                        $1 = $0.count
                    }
            }
        }        
    }
}
extension Convolvers {
    @inlinable
    public static func convolve(x: UnsafePointer<Float64>, count xc: Int,
                                y: UnsafePointer<Float64>, count yc: Int,
                                z: UnsafeMutablePointer<Float64>) {
        switch xc + yc - 1 {
        case let count where xc * yc < count * ( Int.bitWidth - count.leadingZeroBitCount ):
            Naïve.convolve(x: x, count: xc, y: y, count: yc, z: z)
        default:
            DFT.Fast.convolve(x: x, count: xc, y: y, count: yc, z: z)
        }
    }
    @inlinable
    public static func convolve(x: some AccelerateBuffer<Float64>,
                                y: some AccelerateBuffer<Float64>) -> Array<Float64> {
        switch x.count + y.count - 1 {
        case let count where x.count * y.count < count * ( Int.bitWidth - count.leadingZeroBitCount ):
            Naïve.convolve(x: x, y: y)
        default:
            DFT.Fast.convolve(x: x, y: y)
        }
    }
}
