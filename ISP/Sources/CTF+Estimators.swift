//
//  CTF+Estimators.swift
//  MUTE
//
//  Created by Kota on 9/29/26.
//
@preconcurrency import protocol Accelerate.AccelerateBuffer
extension CTF {
    public enum Estimators {}
}
extension CTF.Estimators {
    public protocol `Protocol`: Sendable {
        func update(sample: Int,
                    x: some AccelerateBuffer<Float64>,
                    y: some AccelerateBuffer<Float64>) throws
        func reset()
        var snapshot: CTF.Snapshot { get }
    }
}
