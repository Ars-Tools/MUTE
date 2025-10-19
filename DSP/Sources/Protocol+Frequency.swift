//
//  Protocol+Frequency.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
import protocol Synchronization.AtomicRepresentable
import typealias Accelerate.vDSP
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
@usableFromInline
enum θHz {
	@usableFromInline
	struct Ne {
		@usableFromInline let source: Stream
		@usableFromInline let factor: Float64
	}
}
@usableFromInline
enum Hzθ {
	@usableFromInline
	struct Ne {
		@usableFromInline let source: Stream
		@usableFromInline let factor: Float64
	}
}
extension θHz.Ne: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let stream = source.count
		let factor = factor * interval.seconds
		return {
			kernel($0, $1, $2, $3)
			for var target in fold(start: $2, count: $1, stream: stream, period: $3) {
				vDSP.multiply(factor, target, result: &target)
			}
		}
	}
}
extension Hzθ.Ne: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let stream = source.count
		let factor = factor * interval.seconds
		return {
			kernel($0, $1, $2, $3)
			for var target in fold(start: $2, count: $1, stream: stream, period: $3) {
				vDSP.divide(target, factor, result: &target)
			}
		}
	}
}
public func θ(hz source: Stream) -> some Stream {
	θHz.Ne(source: source, factor: 1)
}
public func hz(θ source: Stream) -> some Stream {
	Hzθ.Ne(source: source, factor: 1)
}
