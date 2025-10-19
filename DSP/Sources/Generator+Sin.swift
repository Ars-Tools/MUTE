//
//  Generator+Sin.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
@preconcurrency import protocol Combine.Publisher
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func NSP.sinosc_bundle_create
import func NSP.sinosc_bundle_execute
import func NSP.sinosc_bundle_destroy
import func Layout.zip
import func Layout.broadcast
import func simd.__sincospi_stret
import func simd.fma
import func CLK.times
import typealias Auxiliary.Autorelease
@usableFromInline
enum Sin {
	@usableFromInline
	struct Kr<Freq: Publisher<(Int, Frequency), Never> & Sendable, Rate: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline let freqs: Freq
		@usableFromInline let ratio: Rate
		@usableFromInline let count: Int
	}
	@usableFromInline
	struct Ar {
		@usableFromInline let phasor: Stream
		@usableFromInline let offset: Stream
	}
}
extension Sin.Kr: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let factor = Mutex<(Array<Float64>, Array<Float64>, Array<Float64>)>((
			.init(repeating: 1, count: count),
			.init(repeating: 0, count: count),
			.init(repeating: 0, count: count)
		))
		let ratio = ratio.sink { index, value in
			factor.withLock {
				switch (index, index) {
				case ($0.0.indices, $0.1.indices):
					let e = __sincospi_stret(fma(2, value, 1))
					$0.0[index] = e.__cosval
					$0.1[index] = e.__sinval
				default:
					assertionFailure("out of range")
				}
			}
		}
		let freqs = freqs.sink { index, value in
			factor.withLock {
				switch index {
				case $0.2.indices:
					$0.2[index] = value.increment(for: interval)
				default:
					assertionFailure("out of range")
				}
			}
		}
		switch count {
		case ...0:
			throw Error.invalidChannel
		case ..<8:
			return {
				let (c, s, ω) = withExtendedLifetime((ratio, freqs)) { factor.withLock(\.self) }
				let r = vDSP.hypot(c, s)
				let θ = vForce.atan2(x: c, y: s)
				var phasor = UnsafeMutableBufferPointer(start: $2, count: $1)
				vDSP.formRamp(withInitialValue: .init($0.times(of: interval, rounding: .some(.roundHalfAwayFromZero)).quotient), increment: 1, result: &phasor)
				for (r, θ, ω, var target) in zip(r, θ, ω, fold(start: $2, count: $1, stream: count, period: $3)).reversed() {
					vDSP.add(multiplication: (phasor, 2 * .pi * ω), -θ, result: &target)
					vForce.cos(target, result: &target)
					vDSP.multiply(r, target, result: &target)
				}
			}
		default:
			let memory = Autorelease.Object(object: sinosc_bundle_create(count)) {
				sinosc_bundle_destroy($0)
			}
			return {
				let (c, s, ω) = withExtendedLifetime((ratio, freqs)) { factor.withLock(\.self) }
				sinosc_bundle_execute(memory.reference,
									  c, 1,
									  s, 1,
									  ω, 1,
									  $2, $3,
									  $0.samples(for: interval), $1)
			}
		}
	}
}
extension Sin.Ar: OperatorBinary.DSP {
	@inlinable
	var lhs: Stream {
		phasor
	}
	@inlinable
	var rhs: Stream {
		offset
	}
	@inlinable
	func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
		vDSP.multiply(subtraction: (x, y), 2, result: &z)
		vForce.sinPi(z, result: &z)
	}
}
// Phase Ar
public func sin(phase: Stream, ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Sin.Ar(phasor: phase, offset: const(ratio, count: phase.count))
}
public func sin(phase: Stream, ratio: some Publisher<Float64, Never>) -> some Stream {
	sin(phase: phase, ratio: ratio.repeat(count: phase.count))
}
public func sin(phase: Stream, ratio: some Collection<Float64>) -> some Stream {
	sin(phase: phase, ratio: ratio.prefix(count: phase.count))
}
@_disfavoredOverload
public func sin(phase: Stream, ratio: Float64...) -> some Stream {
	sin(phase: phase, ratio: ratio)
}
public func sin(phase: Stream, ratio: Stream) -> some Stream {
	Sin.Ar(phasor: phase, offset: ratio)
}
// Freqs Ar
public func sin(freqs: Stream, ratio: some Publisher<(Int, Float64), Never> & Sendable, count: Int) -> some Stream {
	sin(phase: phasor(freqs: freqs), ratio: ratio)
}
public func sin(freqs: Stream, ratio: some Publisher<Float64, Never>) -> some Stream {
	sin(phase: phasor(freqs: freqs), ratio: ratio)
}
public func sin(freqs: Stream, ratio: some Collection<Float64>) -> some Stream {
	sin(phase: phasor(freqs: freqs), ratio: ratio)
}
@_disfavoredOverload
public func sin(freqs: Stream, ratio: Float64...) -> some Stream {
	sin(phase: phasor(freqs: freqs), ratio: ratio)
}
// Pub<Freq>
public func sin(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: some Publisher<(Int, Float64), Never> & Sendable, count: Int) -> some Stream {
	Sin.Kr(freqs: freqs, ratio: ratio, count: count)
}
public func sin(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: some Publisher<Float64, Never>, count: Int) -> some Stream {
	sin(freqs: freqs, ratio: ratio.repeat(count: count), count: count)
}
public func sin(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: some Collection<Float64>) -> some Stream {
	Sin.Kr(freqs: freqs, ratio: ratio.enumerated().publisher.map(\.self), count: ratio.count)
}
@_disfavoredOverload
public func sin(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: Float64...) -> some Stream {
	sin(freqs: freqs, ratio: ratio)
}
public func sin(freqs: some Publisher<(Int, Frequency), Never> & Sendable, ratio: Stream) -> some Stream {
	Sin.Ar(phasor: phasor(freqs: freqs, count: ratio.count), offset: ratio)
}
// Pub<Freq>
public func sin(freqs: some Publisher<Frequency, Never>, ratio: some Publisher<(Int, Float64), Never> & Sendable, count: Int) -> some Stream {
	sin(freqs: freqs.repeat(count: count), ratio: ratio, count: count)
}
public func sin(freqs: some Publisher<Frequency, Never>, ratio: some Publisher<Float64, Never>, count: Int) -> some Stream {
	sin(freqs: freqs.repeat(count: count), ratio: ratio.repeat(count: count), count: count)
}
public func sin(freqs: some Publisher<Frequency, Never>, ratio: some Collection<Float64>) -> some Stream {
	Sin.Kr(freqs: freqs.repeat(count: ratio.count), ratio: ratio.enumerated().publisher.map(\.self), count: ratio.count)
}
@_disfavoredOverload
public func sin(freqs: some Publisher<Frequency, Never>, ratio: Float64...) -> some Stream {
	sin(freqs: freqs, ratio: ratio)
}
public func sin(freqs: some Publisher<Frequency, Never>) -> some Stream {
	sin(freqs: freqs, ratio: 0.25)
}
public func sin(freqs: some Publisher<Frequency, Never>, ratio: Stream) -> some Stream {
	sin(freqs: freqs.repeat(count: ratio.count), ratio: ratio)
}
//
public func sin(freqs: some Collection<Frequency>, ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Sin.Kr(freqs: freqs.enumerated().publisher.map(\.self), ratio: ratio, count: freqs.count)
}
public func sin(freqs: some Collection<Frequency>, ratio: some Publisher<Float64, Never>) -> some Stream {
	sin(freqs: freqs, ratio: ratio.repeat(count: freqs.count))
}
public func sin(freqs: some Collection<Frequency>, ratio: some Collection<Float64>) -> some Stream {
	sin(freqs: freqs, ratio: ratio.prefix(count: freqs.count))
}
@_disfavoredOverload
public func sin(freqs: some Collection<Frequency>, ratio: Float64...) -> some Stream {
	sin(freqs: freqs, ratio: ratio)
}
public func sin(freqs: some Collection<Frequency>, ratio: Stream) -> some Stream {
	Sin.Ar(phasor: phasor(freqs: freqs), offset: ratio)
}
//
@_disfavoredOverload
public func sin(freqs: Frequency..., ratio: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Sin.Kr(freqs: freqs.enumerated().publisher.map(\.self), ratio: ratio, count: freqs.count)
}
@_disfavoredOverload
public func sin(freqs: Frequency..., ratio: some Publisher<Float64, Never>) -> some Stream {
	sin(freqs: freqs, ratio: ratio.repeat(count: freqs.count))
}
@_disfavoredOverload
public func sin(freqs: Frequency..., ratio: some Collection<Float64>) -> some Stream {
	sin(freqs: freqs, ratio: ratio.prefix(count: freqs.count))
}
@_disfavoredOverload
public func sin(freqs: Frequency..., ratio: Float64...) -> some Stream {
	sin(freqs: freqs, ratio: ratio)
}

@_disfavoredOverload
public func sin(freqs: Frequency..., ratio: Stream) -> some Stream {
	sin(phase: phasor(freqs: freqs), ratio: ratio)
}
