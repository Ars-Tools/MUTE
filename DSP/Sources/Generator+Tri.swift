//
//  Generator+Tri.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
@usableFromInline
enum Tri {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable>: OperatorBinary.LHSRaw {
		@usableFromInline let phasor: Stream
		@usableFromInline let signal: Signal
		@inlinable
		var lhs: Stream { phasor }
		@inlinable
		var rhs: Signal { signal }
		@inlinable
		var initial: Float64 { 0.5 }
		@inlinable
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Double>, incy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: length) {
				var w = $0
				for offset in 0..<stream {
					let x = UnsafeBufferPointer(start: x.advanced(by: offset * ldx), count: length)
					var z = UnsafeMutableBufferPointer(start: z.advanced(by: offset * ldz), count: length)
					switch y.advanced(by: offset * incy).pointee {
					case ...0:
						vDSP.add(multiplication: (x, -2), 1, result: &z)
					case 1...:
						vDSP.add(multiplication: (x, 2), -1, result: &z)
					case let y:
						vDSP.add(-y, x, result: &w)
						vDSP.threshold(w, to: 0, with: .zeroFill, result: &z)
						vDSP.divide(z, 1 - y, result: &z)
						vDSP.negative(w, result: &w)
						vDSP.threshold(w, to: 0, with: .zeroFill, result: &w)
						vDSP.divide(w, y, result: &w)
						vDSP.add(w, z, result: &z)
						vDSP.add(multiplication: (z, -2), 1, result: &z)
					}
				}
			}
		}
	}
	@usableFromInline
	struct Ar: OperatorBinary.Raw {
		@usableFromInline let phasor: Stream
		@usableFromInline let stream: Stream
		@inlinable
		var lhs: Stream { phasor }
		@inlinable
		var rhs: Stream { stream }
		@inlinable
		func `operator`(x: UnsafePointer<Float64>, ldx: Int, y: UnsafePointer<Float64>, ldy: Int, z: UnsafeMutablePointer<Float64>, ldz: Int, stream: Int, length: Int) {
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * length) {
				var u = $0[..<length]
				var v = $0[length...]
				for offset in 0..<stream {
					let x = UnsafeBufferPointer(start: x.advanced(by: offset * ldx), count: length)
					let y = UnsafeBufferPointer(start: y.advanced(by: offset * ldy), count: length)
					var z = UnsafeMutableBufferPointer(start: z.advanced(by: offset * ldz), count: length)
					
					// u <- clip(u, 0...1)
					vDSP.clip(y, to: 0...1, result: &u)
					
					// v <- x - u
					vDSP.subtract(x, u, result: &v)
					
					// z <- max(v, 0)
					vDSP.threshold(v, to: 0, with: .zeroFill, result: &z)
					
					// v <- max(-v, 0) / u
					vDSP.negative(v, result: &v)
					vDSP.threshold(v, to: 0, with: .zeroFill, result: &v)
					vDSP.divide(v, u, result: &v)
					vDSP.invertedClip(v, to: -0...0, result: &v)
					
					// z <- z / ( 1 - u )
					vDSP.add(multiplication: (u, -1), 1, result: &u)
					vDSP.divide(z, u, result: &z)
					vDSP.invertedClip(z, to: -0...0, result: &z)
					
					// z <- 1 - 2 * ( z + v )
					vDSP.add(z, v, result: &z)
					vDSP.add(multiplication: (z, -2), 1, result: &z)
					
				}
			}
		}
	}
}
// Phase
public func tri(phase: Stream, ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Tri.Kr(phasor: phase, signal: ratio)
}
public func tri(phase: Stream, ratio: some Publisher<Float64, Never>) -> some Stream {
	tri(phase: phase, ratio: ratio.repeat(count: phase.count))
}
public func tri(phase: Stream, ratio: some Sequence<Float64>) -> some Stream {
	tri(phase: phase, ratio: ratio.prefix(count: phase.count))
}
public func tri(phase: Stream, ratio: Float64) -> some Stream {
	tri(phase: phase, ratio: `repeat`(ratio, count: phase.count))
}
public func tri(phase: Stream, ratio: Stream) -> some Stream {
	Tri.Ar(phasor: phase, stream: ratio)
}
// Freqs Stream
public func tri(freqs: Stream, ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: Stream, ratio: some Publisher<Float64, Never>) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: Stream, ratio: some Sequence<Float64>) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: Stream, ratio: Float64) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: Stream, ratio: Stream) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
// Freqs Signal
public func tri(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: some Publisher<(Int, Float64), Never> & Sendable, count: Int) -> some Stream {
	tri(phase: phasor(freqs: freqs, count: count), ratio: ratio)
}
public func tri(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: some Publisher<Float64, Never>, count: Int) -> some Stream {
	tri(phase: phasor(freqs: freqs, count: count), ratio: ratio)
}
public func tri(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: some Sequence<Float64>, count: Int) -> some Stream {
	tri(phase: phasor(freqs: freqs, count: count), ratio: ratio)
}
public func tri(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: Float64, count: Int) -> some Stream {
	tri(phase: phasor(freqs: freqs, count: count), ratio: ratio)
}
public func tri(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: Stream) -> some Stream {
	tri(phase: phasor(freqs: freqs, count: ratio.count), ratio: ratio)
}
// Freqs Signal
public func tri(freqs: some Publisher<Frequency, Never>, ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: some Publisher<Frequency, Never>, ratio: some Publisher<Float64, Never>) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: some Publisher<Frequency, Never>, ratio: some Sequence<Float64>) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: some Publisher<Frequency, Never>, ratio: Float64) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: some Publisher<Frequency, Never>, ratio: Stream) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
// Freqs Sequence
public func tri(freqs: some Collection<Frequency>, ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: some Collection<Frequency>, ratio: some Publisher<Float64, Never>) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: some Collection<Frequency>, ratio: some Sequence<Float64>) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: some Collection<Frequency>, ratio: Float64) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
public func tri(freqs: some Collection<Frequency>, ratio: Stream) -> some Stream {
	tri(phase: phasor(freqs: freqs), ratio: ratio)
}
// Freqs
@_disfavoredOverload
public func tri(freqs: Frequency..., ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	tri(freqs: freqs, ratio: ratio)
}
@_disfavoredOverload
public func tri(freqs: Frequency..., ratio: some Publisher<Float64, Never>) -> some Stream {
	tri(freqs: freqs, ratio: ratio)
}
@_disfavoredOverload
public func tri(freqs: Frequency..., ratio: some Sequence<Float64>) -> some Stream {
	tri(freqs: freqs, ratio: ratio)
}
@_disfavoredOverload
public func tri(freqs: Frequency..., ratio: Float64) -> some Stream {
	tri(freqs: freqs, ratio: ratio)
}
@_disfavoredOverload
public func tri(freqs: Frequency..., ratio: Stream) -> some Stream {
	tri(freqs: freqs, ratio: ratio)
}

