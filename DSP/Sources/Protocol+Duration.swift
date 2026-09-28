//
//  Protocol+Duration.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
import protocol Synchronization.AtomicRepresentable
import typealias Numerics.Rational64
import func CLK.times
public protocol Duration: Sendable, Comparable, Equatable, AdditiveArithmetic {
	@inlinable func divide(by time: CMTime) -> (quotient: Int, remainder: CMTime)
	@inlinable func samples(for duration: CMTime) -> Int
}
extension Duration {
	public func samples(for duration: CMTime) -> Int {
		switch divide(by: duration) {
		case (let q, let r):
            q + .init(r.convertScale(1, method: .roundHalfAwayFromZero).value)
		}
	}
}
extension CMTime: Duration {
	public func divide(by time: CMTime) -> (quotient: Int, remainder: CMTime) {
		times(of: time, rounding: .none)
	}
}
extension Swift.Duration: Duration {
	public func divide(by time: CMTime) -> (quotient: Int, remainder: CMTime) {
		CMTime(duration: self).divide(by: time)
	}
}
extension Float64: Duration {
	public func divide(by time: CMTime) -> (quotient: Int, remainder: CMTime) {
		CMTime(seconds: self, preferredTimescale: time.timescale).divide(by: time)
	}
}
// Independed from Sampling Frequency
@frozen public struct Samples: RawRepresentable & Sendable & BitwiseCopyable & Equatable & Hashable & AtomicRepresentable {
	public let rawValue: Int
	public init(rawValue value: Int) {
		rawValue = value
	}
}
extension Samples: AdditiveArithmetic {
    @inlinable@inline(__always)@_transparent
	public static func+(lhs: Self, rhs: Self) -> Self {
		.init(rawValue: lhs.rawValue + rhs.rawValue)
	}
    @inlinable@inline(__always)@_transparent
	public static func-(lhs: Self, rhs: Self) -> Self {
		.init(rawValue: lhs.rawValue - rhs.rawValue)
	}
    @inlinable@inline(__always)@_transparent
    public static func > (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue > rhs.rawValue
    }
    @inlinable@inline(__always)@_transparent
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    @inlinable@inline(__always)@_transparent
    public static func <= (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue <= rhs.rawValue
    }
    @inlinable@inline(__always)@_transparent
    public static func >= (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue >= rhs.rawValue
    }
    @inlinable@inline(__always)@_transparent
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}
extension Samples: Duration {
    @inlinable@inline(__always)@_transparent
	public func divide(by time: CMTime) -> (quotient: Int, remainder: CMTime) {
		(rawValue, .zero)
	}
}
extension Samples: ExpressibleByIntegerLiteral {
	public init(integerLiteral value: RawValue) {
		rawValue = value
	}
}
