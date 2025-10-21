//
//  Protocols+Frequency.swift
//  MUTE
//
//  Created by Kota on 5/9/R7.
//
import protocol Synchronization.AtomicRepresentable
import func CoreMedia.CMTimeGetSeconds
import func CoreMedia.CMTimeMultiply
import func CoreMedia.CMTimeMultiplyByRatio
import func CoreMedia.CMTimeMultiplyByFloat64
import typealias Numerics.Rational64
import typealias Numerics.Rational128
public protocol Frequency: Sendable {
	@inlinable func multiply(time: CMTime) -> CMTime
	@inlinable func increment(for time: CMTime) -> Float64
}
extension Frequency {
	@inlinable @inline(__always)
	public func increment(for time: CMTime) -> Float64 {
		CMTimeGetSeconds(multiply(time: time))
	}
}
extension Int32: Frequency {
	@inlinable @inline(__always)
	public func multiply(time: CMTime) -> CMTime {
		CMTimeMultiply(time, multiplier: self)
	}
}
extension Rational64: Frequency {
	@inlinable @inline(__always)
	public func multiply(time: CMTime) -> CMTime {
		CMTimeMultiplyByRatio(time, multiplier: numerator, divisor: denominator)
	}
}
extension Float64: Frequency {
	@inlinable @inline(__always)
	public func multiply(time: CMTime) -> CMTime {
		CMTimeMultiplyByFloat64(time, multiplier: self)
	}
}
// Independed from Sampling Frequency
public struct AngularFrequency: RawRepresentable & Sendable & BitwiseCopyable & Equatable & Hashable & AtomicRepresentable {
	public let rawValue: Rational128
	public init(rawValue value: RawValue) {
		rawValue = value
	}
}
extension AngularFrequency: AdditiveArithmetic {
	public static func+(lhs: Self, rhs: Self) -> Self {
		.init(rawValue: lhs.rawValue + rhs.rawValue)
	}
	public static func-(lhs: Self, rhs: Self) -> Self {
		.init(rawValue: lhs.rawValue - rhs.rawValue)
	}
	public static let zero: AngularFrequency = .init(rawValue: .zero)
}
extension AngularFrequency: Frequency {
	@inlinable
	public func multiply(time: CMTime) -> CMTime {
		.init(value: .init(rawValue.numerator), timescale: .init(rawValue.denominator))
	}
}
