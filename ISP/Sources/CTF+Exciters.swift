//
//  CTF+Exciters.swift
//  MUTE
//
//  Created by Kota on 9/29/26.
//
import func KSP.rng_uniform
extension CTF {
    public enum Exciters {}
}
extension CTF.Exciters {
    public protocol `Protocol`: Sendable {
        func generate(sample: Int,
                      length: Int,
                      target: UnsafeMutablePointer<Float64>,
                      stride: Int,
                      snapshot: borrowing CTF.Snapshot)
    }
}
extension CTF.Exciters {
    @usableFromInline
    struct Uniform: `Protocol`, @unchecked Sendable {
        @usableFromInline
        let rawValue: ClosedRange<Float64>
        @usableFromInline
        let channels: Int
        @inlinable
        init(for count: Int, in range: ClosedRange<Float64> = -1 ... 1) {
            rawValue = range
            channels = count
        }
        @inlinable
        func generate(sample: Int,
                      length: Int,
                      target: UnsafeMutablePointer<Float64>,
                      stride: Int,
                      snapshot: borrowing CTF.Snapshot) {
            rng_uniform(target, stride,
                        rawValue.lowerBound, rawValue.upperBound,
                        channels, length)
        }
    }
    public static let uniform: some `Protocol` = Uniform(for: 1)
    public static func uniform(for count: Int, in range: ClosedRange<Float64> = -1...1) -> some `Protocol` {
        Uniform(for: count, in: range)
    }
}
