//
//  Waveshape+Sign.swift
//  MUTE
//
//  Created by Kota on 6/25/R7.
//
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
@usableFromInline
enum Sign {
	@usableFromInline
	struct Abs: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.absolute(x, result: &y)
		}
	}
	@usableFromInline
	struct Nabs: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.negativeAbsolute(x, result: &y)
		}
	}
	@usableFromInline
	struct Copysign: OperatorBinary.DSP {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vForce.copysign(magnitudes: x, signs: y, result: &z)
		}
	}
	@usableFromInline
	struct Mod: OperatorBinary.DSP {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vForce.truncatingRemainder(dividends: x, divisors: y, result: &z)
		}
	}
}
public func abs(_ x: Stream) -> some Stream {
	Sign.Abs(operand: x)
}
public func nabs(_ x: Stream) -> some Stream {
	Sign.Nabs(operand: x)
}
public func copysign(magnitudes: Stream, signs: Stream) -> some Stream {
	Sign.Copysign(lhs: magnitudes, rhs: signs)
}
