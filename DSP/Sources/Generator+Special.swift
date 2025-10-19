//
//  Generator+Special.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
import typealias Accelerate.vDSP
@usableFromInline
enum Special {
	case Nil(Int)
	case Nch(Int)
	case ElapsedSample
	case ElapsedSecond
	case FrameIndex
	case SampleRate
}
extension Special: Stream {
	@inlinable
	var count: Int {
		switch self {
		case.Nil(let count), .Nch(let count):
			count
		case.ElapsedSample, .ElapsedSecond, .FrameIndex, .SampleRate:
			1
		}
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch self {
		case.Nil(let count):
			{
				for var target in fold(start: $2, count: $1, stream: count, period: $3) {
					vDSP.clear(&target)
				}
			}
		case.Nch(let count):
			{
				for (offset, var target) in fold(start: $2, count: $1, stream: count, period: $3).enumerated() {
					vDSP.fill(&target, with: .init(offset))
				}
			}
		case.ElapsedSample:
			{ moment, length, target, ignore in
				var result = UnsafeMutableBufferPointer(start: target, count: length)
				vDSP.formRamp(withInitialValue: .init(moment.value), increment: 1, result: &result)
			}
		case.ElapsedSecond:
			{ moment, length, target, ignore in
				var result = UnsafeMutableBufferPointer(start: target, count: length)
				vDSP.formRamp(withInitialValue: moment.seconds, increment: interval.seconds, result: &result)
			}
		case.FrameIndex:
			{ moment, length, target, ignore in
				var result = UnsafeMutableBufferPointer(start: target, count: length)
				vDSP.formRamp(withInitialValue: 0, increment: 1, result: &result)
			}
		case.SampleRate:
			{ moment, length, target, ignore in
				var result = UnsafeMutableBufferPointer(start: target, count: length)
				vDSP.fill(&result, with: .init(interval.timescale) / .init(interval.value))
			}
		}
	}
}
public let t: some Stream = Special.ElapsedSecond
public let fs: some Stream = Special.SampleRate
public func N(count: Int) -> some Stream {
	Special.Nch(count)
}
public func φ(count: Int) -> some Stream {
	Special.Nil(count)
}
