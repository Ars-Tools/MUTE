//
//  Waveshape+Rounding.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
@usableFromInline
enum Round {
	@usableFromInline
	struct Ceil: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.ceil(x, result: &y)
		}
	}
	@usableFromInline
	struct Floor: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.floor(x, result: &y)
		}
	}
	@usableFromInline
	struct Round: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.nearestInteger(x, result: &y)
		}
	}
	@usableFromInline
	struct Wrap: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.trunc(x, result: &y)
			vDSP.add(1, y, result: &y)
			vDSP.trunc(y, result: &y)
		}
	}
}
public func floor(_ stream: Stream) -> some Stream {
	Round.Floor(operand: stream)
}
public func round(_ stream: Stream) -> some Stream {
	Round.Round(operand: stream)
}
public func ceil(_ stream: Stream) -> some Stream {
	Round.Ceil(operand: stream)
}
public func wrap(_ stream: Stream) -> some Stream {
	Round.Wrap(operand: stream)
}
