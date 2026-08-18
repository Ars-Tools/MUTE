//
//  Convolvers.swift
//  MUTE
//
//  Created by Kota on 8/6/26.
//
import Accelerate
import Numerics
import NSP
public enum Convolvers: Sendable {}
extension Convolvers {
    public protocol `Protocol`: Sendable {
        func convolve(x: UnsafePointer<Float64>, count xc: Int,
                      y: UnsafePointer<Float64>, count yc: Int,
                      z: UnsafeMutablePointer<Float64>)
        func convolve(x: some AccelerateBuffer<Float64>,
                      y: some AccelerateBuffer<Float64>) -> Array<Float64>
    }
}
extension Convolvers.`Protocol` {
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
