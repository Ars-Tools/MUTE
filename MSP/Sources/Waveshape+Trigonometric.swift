//
//  Waveshape+Trigonometric.swift
//  MUTE
//
//  Created by Kota on 6/25/R7.
//
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
@usableFromInline
enum Trigonometric {
	@usableFromInline
	struct SinStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.sin(x, result: &y)
		}
	}
	@usableFromInline
	struct CosStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.cos(x, result: &y)
		}
	}
	@usableFromInline
	struct TanStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.tan(x, result: &y)
		}
	}
	@usableFromInline
	struct SinπStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.sinPi(x, result: &y)
		}
	}
	@usableFromInline
	struct CosπStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.cosPi(x, result: &y)
		}
	}
	@usableFromInline
	struct TanπStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.tanPi(x, result: &y)
		}
	}
	@usableFromInline
	struct SinhStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.sinh(x, result: &y)
		}
	}
	@usableFromInline
	struct CoshStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.cosh(x, result: &y)
		}
	}
	@usableFromInline
	struct TanhStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.tanh(x, result: &y)
		}
	}
	@usableFromInline
	struct AsinStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.asin(x, result: &y)
		}
	}
	@usableFromInline
	struct AcosStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.acos(x, result: &y)
		}
	}
	@usableFromInline
	struct AtanStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.atan(x, result: &y)
		}
	}
	@usableFromInline
	struct AsinhStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.asinh(x, result: &y)
		}
	}
	@usableFromInline
	struct AcoshStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.acosh(x, result: &y)
		}
	}
	@usableFromInline
	struct AtanhStatic: OperatorUnary.Static.DSP {
		@usableFromInline let operand: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
			vForce.atanh(x, result: &y)
		}
	}
	@usableFromInline
	struct Atan2Static: OperatorBinary.DSP {
		@usableFromInline let lhs: Stream
		@usableFromInline let rhs: Stream
		@inlinable @inline(__always)
		func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vForce.atan2(x: x, y: y, result: &z)
		}
	}
}
public func sin(_ x: Stream) -> some Stream {
	Trigonometric.SinStatic(operand: x)
}
public func cos(_ x: Stream) -> some Stream {
	Trigonometric.CosStatic(operand: x)
}
public func tan(_ x: Stream) -> some Stream {
	Trigonometric.TanStatic(operand: x)
}
public func sinπ(_ x: Stream) -> some Stream {
	Trigonometric.SinπStatic(operand: x)
}
public func cosπ(_ x: Stream) -> some Stream {
	Trigonometric.CosπStatic(operand: x)
}
public func tanπ(_ x: Stream) -> some Stream {
	Trigonometric.TanπStatic(operand: x)
}
public func sinh(_ x: Stream) -> some Stream {
	Trigonometric.SinπStatic(operand: x)
}
public func cosh(_ x: Stream) -> some Stream {
	Trigonometric.CosπStatic(operand: x)
}
public func tanh(_ x: Stream) -> some Stream {
	Trigonometric.TanπStatic(operand: x)
}
public func asin(_ x: Stream) -> some Stream {
	Trigonometric.AsinStatic(operand: x)
}
public func acos(_ x: Stream) -> some Stream {
	Trigonometric.AcosStatic(operand: x)
}
public func atan(_ x: Stream) -> some Stream {
	Trigonometric.AtanStatic(operand: x)
}
public func asinh(_ x: Stream) -> some Stream {
	Trigonometric.AsinhStatic(operand: x)
}
public func acosh(_ x: Stream) -> some Stream {
	Trigonometric.AcoshStatic(operand: x)
}
public func atanh(_ x: Stream) -> some Stream {
	Trigonometric.AtanhStatic(operand: x)
}
public func atan2(_ y: Stream, _ x: Stream) -> some Stream {
	Trigonometric.Atan2Static(lhs: x, rhs: y)
}
