//
//  Graph+Oversample.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
import func CoreMedia.memmove
import func CoreMedia.CMTimeMultiplyByRatio
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Synchronization.Mutex
import func NSP.vvi0
import func NSP.i0
public enum Oversample {
	@usableFromInline
	struct Ne {
		@usableFromInline let stream: Stream
		@usableFromInline let factor: Int // decimation rate
		@usableFromInline let window: Array<Float64>
	}
	public enum SmoothWindow: Sendable & Hashable {
		case pulse(Int)
		case rect(Int)
		case kaiser(Int, Float64)
		case gauss(Int, Float64)
		case sinc(Int, Float64)
		case raw(Array<Float64>)
	}
}
extension Oversample.Ne: Stream {
	@inlinable
	var count: Int {
		stream.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let Δt = CMTimeMultiplyByRatio(interval, multiplier: 1, divisor: .init(factor))
		let bs = capacity * factor
		let ow = max(0, window.count - factor)
		let period = bs + ow
		let number = stream.count
		let stream = try stream(interval: Δt, capacity: bs, instance: &instance)
		let buffer = Buffer(stream: number, period: period)
		return {
			stream($0, $1 * factor, buffer.start.advanced(by: ow), period)
			for (source, var target) in zip(fold(target: buffer), fold(start: $2, count: $1, stream: number, period: $3)) {
				vDSP.downsample(source, decimationFactor: factor, filter: window, result: &target)
//				memmove(source.baseAddress, source.baseAddress?.advanced(by: $1 * factor), ow * MemoryLayout<Float64>.stride)
			}
			copy(x: buffer.start, ldx: period, y: buffer.start.advanced(by: $1 * factor), ldy: period, rows: number, cols: ow)
		}
	}
}
extension Oversample.SmoothWindow {
	@inlinable
	public var coefficients: Array<Float64> {
		switch self {
		case.pulse(let length):
			.init(unsafeUninitializedCapacity: length) {
				vDSP.clear(&$0)
				$0[length/2] = 1
				$1 = $0.count
			}
		case.rect(let length):
			.init(repeating: 1 / .init(length), count: length)
		case.kaiser(let length, let factor):
			.init(unsafeUninitializedCapacity: length) {
				guard let memory = $0.baseAddress else { return }
				vDSP.formRamp(withInitialValue: -1, increment: 2 / .init($0.count), result: &$0)
				vDSP.square($0, result: &$0)
				vDSP.add(multiplication: ($0, -1), 1, result: &$0)
				vForce.sqrt($0, result: &$0)
				vDSP.multiply(factor * .pi, $0, result: &$0)
				vvi0(memory, memory, $0.count)
				vDSP.divide($0, i0(factor * .pi), result: &$0)
				$1 = $0.count
			}
		case.gauss(let length, let factor):
			.init(unsafeUninitializedCapacity: length) {
				vDSP.formRamp(withInitialValue: .init(-length/2), increment: 1, result: &$0)
				vDSP.square($0, result: &$0)
				vDSP.multiply(-.pi * (factor * factor) / .init(length), $0, result: &$0)
				vForce.exp($0, result: &$0)
				vDSP.multiply(factor / .pi / .init(length).squareRoot(), $0, result: &$0)
				$1 = $0.count
			}
		case.sinc(let length, let factor):
			.init(unsafeUninitializedCapacity: 2 * length) {
				vDSP.formRamp(withInitialValue: .init(-length/2) * factor * .pi, increment: factor * .pi, result: &$0[..<length])
				vForce.sin($0[..<length], result: &$0[length...])
				vDSP.divide($0[length...], $0[..<length], result: &$0[..<length])
				$0[length/2] = 1
				$1 = length
			}
		case.raw(let kernel):
			kernel
		}
	}
}
public func oversample(_ source: Stream, factor: Int, smooth window: some Collection<Float64>) -> some Stream {
	Oversample.Ne(stream: source, factor: factor, window: .init(window))
}
public func oversample(_ source: Stream, factor: Int, smooth window: Oversample.SmoothWindow) -> some Stream {
	oversample(source, factor: factor, smooth: window.coefficients)
}
