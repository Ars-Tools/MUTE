//
//  Generators+Parameter.swift
//  MUTE
//
//  Created by Kota on 5/16/R7.
//
import typealias Accelerate.vDSP
@usableFromInline
enum Parameter {
	case ChannelIndex(Int)
	case ElapsedSample
	case ElapsedSecond
	case SampleRate
}
extension Parameter: Stream {
	@inlinable
	var count: Int {
		switch self {
		case.ChannelIndex(let count):
			count
		default:
			1
		}
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch self {
		case.ChannelIndex(let count):
			{
				for index in 0..<count {
					var result = UnsafeMutableBufferPointer(start: $2.advanced(by: index * $3), count: $1)
					vDSP.fill(&result, with: .init(index))
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
		case.SampleRate:
			{ moment, length, target, ignore in
				var result = UnsafeMutableBufferPointer(start: target, count: length)
				vDSP.fill(&result, with: .init(interval.timescale) / .init(interval.value))
			}
		}
	}
}
public let t: some Stream = Parameter.ElapsedSecond
public let fs: some Stream = Parameter.SampleRate
public func ch(count: Int) -> some Stream {
	Parameter.ChannelIndex(count)
}
