//
//  Generators+Rec.swift
//  MUTE
//
//  Created by Kota on 5/15/R7.
//
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
@preconcurrency import protocol Combine.Publisher
@usableFromInline
enum Rec {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSDSP {
		@usableFromInline let phasor: Stream
		@usableFromInline let signal: Signal
		@inlinable
		var lhs: Stream { phasor }
		@inlinable
		var rhs: Signal { signal }
		@inlinable
		var initial: Float64 { 0.5 }
		@inlinable
		func`operator`(x: some AccelerateBuffer<Float64>, y: Float64, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.limit(x, limit: y, withOutputConstant: -1, result: &z)
		}
	}
	@usableFromInline
	struct Ar: OperatorBinary.DSP {
		@usableFromInline let phasor: Stream
		@usableFromInline let stream: Stream
		@inlinable
		var lhs: Stream { phasor }
		@inlinable
		var rhs: Stream { stream }
		@inlinable
		func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
			vDSP.subtract(x, y, result: &z)
			vDSP.limit(z, limit: 0, withOutputConstant: -1, result: &z)
		}
	}
}
// Phase
public func rec(phase: Stream, ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Rec.Kr(phasor: phase, signal: ratio)
}
public func rec(phase: Stream, ratio: some Publisher<Float64, Never>) -> some Stream {
	rec(phase: phase, ratio: ratio.repeat(count: phase.count))
}
public func rec(phase: Stream, ratio: some Sequence<Float64>) -> some Stream {
	rec(phase: phase, ratio: ratio.prefix(count: phase.count))
}
public func rec(phase: Stream, ratio: Float64) -> some Stream {
	rec(phase: phase, ratio: `repeat`(ratio, count: phase.count))
}
public func rec(phase: Stream, ratio: Stream) -> some Stream {
	Rec.Ar(phasor: phase, stream: ratio)
}
// Freqs Stream
public func rec(freqs: Stream, ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: Stream, ratio: some Publisher<Float64, Never>) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: Stream, ratio: some Sequence<Float64>) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: Stream, ratio: Float64) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: Stream, ratio: Stream) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
// Freqs Signal
public func rec(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: some Publisher<(Int, Float64), Never> & Sendable, count: Int) -> some Stream {
	rec(phase: phasor(freqs: freqs, count: count), ratio: ratio)
}
public func rec(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: some Publisher<Float64, Never>, count: Int) -> some Stream {
	rec(phase: phasor(freqs: freqs, count: count), ratio: ratio)
}
public func rec(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: some Sequence<Float64>, count: Int) -> some Stream {
	rec(phase: phasor(freqs: freqs, count: count), ratio: ratio)
}
public func rec(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: Float64, count: Int) -> some Stream {
	rec(phase: phasor(freqs: freqs, count: count), ratio: ratio)
}
public func rec(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: Stream) -> some Stream {
	rec(phase: phasor(freqs: freqs, count: ratio.count), ratio: ratio)
}
// Freqs Signal
public func rec(freqs: some Publisher<Frequency, Never>, ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: some Publisher<Frequency, Never>, ratio: some Publisher<Float64, Never>) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: some Publisher<Frequency, Never>, ratio: some Sequence<Float64>) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: some Publisher<Frequency, Never>, ratio: Float64) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: some Publisher<Frequency, Never>, ratio: Stream) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
// Freqs Sequence
public func rec(freqs: some Collection<Frequency>, ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: some Collection<Frequency>, ratio: some Publisher<Float64, Never>) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: some Collection<Frequency>, ratio: some Sequence<Float64>) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: some Collection<Frequency>, ratio: Float64) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
public func rec(freqs: some Collection<Frequency>, ratio: Stream) -> some Stream {
	rec(phase: phasor(freqs: freqs), ratio: ratio)
}
// Freqs
@_disfavoredOverload
public func rec(freqs: Frequency..., ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	rec(freqs: freqs, ratio: ratio)
}
@_disfavoredOverload
public func rec(freqs: Frequency..., ratio: some Publisher<Float64, Never>) -> some Stream {
	rec(freqs: freqs, ratio: ratio)
}
@_disfavoredOverload
public func rec(freqs: Frequency..., ratio: some Sequence<Float64>) -> some Stream {
	rec(freqs: freqs, ratio: ratio)
}
@_disfavoredOverload
public func rec(freqs: Frequency..., ratio: Float64) -> some Stream {
	rec(freqs: freqs, ratio: ratio)
}
@_disfavoredOverload
public func rec(freqs: Frequency..., ratio: Stream) -> some Stream {
	rec(freqs: freqs, ratio: ratio)
}

