//
//  Generator+Pulse.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import func NSP.calculus_differentiation
@usableFromInline
enum Pulse {
	@usableFromInline
	struct Ar {
		@usableFromInline let phasor: Stream
	}
}
extension Pulse.Ar: OperatorUnary.Latest.Raw {
	@inlinable
	var operand: Stream {
		phasor
	}
	@inlinable
	var initial: Float64 {
		0
	}
	@inlinable
	func `operator`(x: UnsafePointer<Float64>, ldx: Int,
					y: UnsafeMutablePointer<Float64>, incy: Int,
					z: UnsafeMutablePointer<Float64>, ldz: Int,
					stream: Int, length: Int) {
		withUnsafeTemporaryAllocation(of: Float64.self, capacity: length) {
			for offset in 0..<stream {
				let result = UnsafeMutableBufferPointer(start: z.advanced(by: offset * ldz), count: length)
				vDSP.subtract(result.dropLast(1), result.dropFirst(1), result: &$0[1..<$0.count])
				$0[0] = y[offset * incy] - ( result.first ?? .zero )
				y[offset * incy] = result.last ?? .zero
				vDSP.threshold($0, to: 0, with: .signedConstant(0.5), result: &$0[0..<$0.count])
				vDSP.add(0.5, $0, result: &result[0..<$0.count])
			}
		}
	}
}
public func pulse(phase phasor: Stream) -> some Stream {
	Pulse.Ar(phasor: phasor)
}
public func pulse(freqs: Stream) -> some Stream {
	pulse(phase: phasor(freqs: freqs))
}
public func pulse(freqs: some Publisher<(Int, Frequency), Never> & Sendable, count: Int) -> some Stream {
	pulse(phase: phasor(freqs: freqs, count: count))
}
public func pulse(freqs: some Publisher<Frequency, Never>) -> some Stream {
	pulse(phase: phasor(freqs: freqs))
}
public func pulse(freqs: some AsyncSequence<(Int, Frequency), Never> & Sendable, count: Int) -> some Stream {
	pulse(phase: phasor(freqs: freqs, count: count))
}
public func pulse(freqs: some AsyncSequence<Frequency, Never> & Sendable) -> some Stream {
	pulse(phase: phasor(freqs: freqs))
}
public func pulse(freqs: some Collection<Frequency>) -> some Stream {
	pulse(phase: phasor(freqs: freqs))
}
@_disfavoredOverload
public func pulse(freqs: Frequency...) -> some Stream {
	pulse(phase: phasor(freqs: freqs))
}
