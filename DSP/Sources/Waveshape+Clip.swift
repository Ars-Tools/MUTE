//
//  Waveshape+Clip.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Synchronization.Mutex
@usableFromInline
enum Clip {
	@usableFromInline
	enum FixNan {
		@usableFromInline
		struct He: OperatorUnary.Static.DSP {
			@usableFromInline let operand: Stream
			@inlinable
			func `operator`(x: some AccelerateBuffer<Float64>, y: inout some AccelerateMutableBuffer<Float64>) {
				vDSP.invertedClip(x, to: -0...0, result: &y)
			}
		}
	}
	@usableFromInline
	enum Bounds {
		@usableFromInline
		struct Kr<Signal: Publisher<(Int, ClosedRange<Float64>), Never> & Sendable> {
			@usableFromInline let source: Stream
			@usableFromInline let signal: Signal
		}
	}
	@usableFromInline
	enum Inv {
		@usableFromInline
		struct Kr<Signal: Publisher<(Int, ClosedRange<Float64>), Never> & Sendable> {
			@usableFromInline let source: Stream
			@usableFromInline let signal: Signal
		}
	}
	@usableFromInline
	enum Sup {
		@usableFromInline
		struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable> {
			@usableFromInline let source: Stream
			@usableFromInline let signal: Signal
		}
		@usableFromInline
		struct Ar {
			@usableFromInline let source: Stream
			@usableFromInline let stream: Stream
		}
	}
	@usableFromInline
	enum Inf {
		@usableFromInline
		struct Kr<Signal: Publisher<(Int, Float64), Never> & Sendable> {
			@usableFromInline let source: Stream
			@usableFromInline let signal: Signal
		}
		@usableFromInline
		struct Ar {
			@usableFromInline let source: Stream
			@usableFromInline let stream: Stream
		}
	}
}
extension Clip.Bounds.Kr: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let ranges = Mutex<Array<ClosedRange<Float64>>>(.init(repeating: .init(uncheckedBounds: (-.infinity, .infinity)), count: source.count))
		let cancel = signal.sink { index, value in
			ranges.withLock {
				switch index {
				case $0.indices:
					$0[index] = value
				default:
					assertionFailure("out of range")
				}
			}
		}
		return {
			kernel($0, $1, $2, $3)
			let ranges = withExtendedLifetime(cancel) { ranges.withLock(\.self) }
			for (offset, source) in ranges.enumerated() {
				var target = UnsafeMutableBufferPointer(start: $2.advanced(by: offset * $3), count: $1)
				vDSP.clip(target, to: source, result: &target)
			}
		}
	}
}
extension Clip.Inv.Kr: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	var dependencies: Array<Stream> {
		.init(arrayLiteral: source)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let ranges = Mutex<Array<ClosedRange<Float64>>>(.init(repeating: -.infinity ... .infinity, count: source.count))
		let cancel = signal.sink { index, value in
			ranges.withLock {
				switch index {
				case $0.indices:
					$0[index] = value
				default:
					assertionFailure("out of range")
				}
			}
		}
		return {
			kernel($0, $1, $2, $3)
			let ranges = withExtendedLifetime(cancel) { ranges.withLock(\.self) }
			for (offset, source) in ranges.enumerated() {
				var target = UnsafeMutableBufferPointer(start: $2.advanced(by: offset * $3), count: $1)
				vDSP.invertedClip(target, to: source, result: &target)
			}
		}
	}
}
extension Clip.Sup.Kr: OperatorBinary.LHSDSP {
	@inlinable
	var lhs: Stream { source }
	@inlinable
	var rhs: Signal { signal }
	@inlinable
	var initial: Float64 {
		.zero
	}
	@inlinable
	func `operator`(x: some AccelerateBuffer<Float64>, y: Float64, z: inout some AccelerateMutableBuffer<Float64>) {
		vDSP.negative(x, result: &z)
		vDSP.threshold(z, to: -y, with: .clampToThreshold, result: &z)
		vDSP.negative(z, result: &z)
	}
}
extension Clip.Sup.Ar: OperatorBinary.DSP {
	@inlinable
	var lhs: Stream {
		source
	}
	@inlinable
	var rhs: Stream {
		stream
	}
	@inlinable
	func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
		x.withUnsafeBufferPointer { x in
			y.withUnsafeBufferPointer { y in
				vDSP.minimum(x, y, result: &z)
			}
		}
	}
}
extension Clip.Inf.Kr: OperatorBinary.LHSDSP {
	@inlinable
	var lhs: Stream { source }
	@inlinable
	var rhs: Signal { signal }
	@inlinable
	var initial: Float64 {
		.zero
	}
	@inlinable
	func `operator`(x: some AccelerateBuffer<Float64>, y: Float64, z: inout some AccelerateMutableBuffer<Float64>) {
		vDSP.threshold(x, to: y, with: .clampToThreshold, result: &z)
	}
}
extension Clip.Inf.Ar: OperatorBinary.DSP {
	@inlinable
	var lhs: Stream {
		source
	}
	@inlinable
	var rhs: Stream {
		stream
	}
	@inlinable
	func `operator`(x: some AccelerateBuffer<Float64>, y: some AccelerateBuffer<Float64>, z: inout some AccelerateMutableBuffer<Float64>) {
		x.withUnsafeBufferPointer { x in
			y.withUnsafeBufferPointer { y in
				vDSP.maximum(x, y, result: &z)
			}
		}
	}
}
// MARK: Bounds
public func clip(_ source: Stream, range signal: some Publisher<(Int, ClosedRange<Float64>), Never> & Sendable) -> some Stream {
	Clip.Bounds.Kr(source: source, signal: signal)
}
public func clip(_ source: Stream, range: some Publisher<ClosedRange<Float64>, Never>) -> some Stream {
	Clip.Bounds.Kr(source: source, signal: range.repeat(count: source.count))
}
public func clip(_ source: Stream, range: some Sequence<ClosedRange<Float64>>) -> some Stream {
	Clip.Bounds.Kr(source: source, signal: range.prefix(source.count).enumerated().publisher.map(\.self))
}
public func clip(_ source: Stream, range: ClosedRange<Float64>) -> some Stream {
	Clip.Bounds.Kr(source: source, signal: repeatElement(range, count: source.count).enumerated().publisher.map(\.self))
}
// MARK: Sup
public func clip(_ source: Stream, sup signal: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Clip.Sup.Kr(source: source, signal: signal)
}
public func clip(_ source: Stream, sup: some Publisher<Float64, Never>) -> some Stream {
	Clip.Sup.Kr(source: source, signal: sup.repeat(count: source.count))
}
public func clip(_ source: Stream, sup: some Sequence<Float64>) -> some Stream {
	Clip.Sup.Kr(source: source, signal: sup.prefix(source.count).enumerated().publisher.map(\.self))
}
public func clip(_ source: Stream, sup: Float64) -> some Stream {
	Clip.Sup.Kr(source: source, signal: repeatElement(sup, count: source.count).enumerated().publisher.map(\.self))
}
// MARK: Inf
public func clip(_ source: Stream, inf signal: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	Clip.Inf.Kr(source: source, signal: signal)
}
public func clip(_ source: Stream, inf: some Publisher<Float64, Never>) -> some Stream {
	Clip.Inf.Kr(source: source, signal: inf.repeat(count: source.count))
}
public func clip(_ source: Stream, inf: some Sequence<Float64>) -> some Stream {
	Clip.Inf.Kr(source: source, signal: inf.prefix(source.count).enumerated().publisher.map(\.self))
}
public func clip(_ source: Stream, inf: Float64) -> some Stream {
	Clip.Inf.Kr(source: source, signal: repeatElement(inf, count: source.count).enumerated().publisher.map(\.self))
}
// MARK: Inv
public func clip(_ source: Stream, inv signal: some Publisher<(Int, ClosedRange<Float64>), Never> & Sendable) -> some Stream {
	Clip.Inv.Kr(source: source, signal: signal)
}
public func clip(_ source: Stream, inv: some Publisher<ClosedRange<Float64>, Never>) -> some Stream {
	Clip.Inv.Kr(source: source, signal: inv.repeat(count: source.count))
}
public func clip(_ source: Stream, inv: some Sequence<ClosedRange<Float64>>) -> some Stream {
	Clip.Inv.Kr(source: source, signal: inv.prefix(source.count).enumerated().publisher.map(\.self))
}
public func clip(_ source: Stream, inv: ClosedRange<Float64>) -> some Stream {
	Clip.Inv.Kr(source: source, signal: repeatElement(inv, count: source.count).enumerated().publisher.map(\.self))
}
// MARK: Fixnan
public func fixnan(_ source: Stream) -> some Stream {
	clip(source, inv: -0...0)
}
// MARK: Max/Min
@inline(__always)
public func maximum(_ a: Stream, _ b: Stream) -> some Stream {
	Clip.Inf.Ar(source: a, stream: b)
}
@inline(__always)
public func minimum(_ a: Stream, _ b: Stream) -> some Stream {
	Clip.Sup.Ar(source: a, stream: b)
}
@inline(__always)
public func maximum(_ a: Stream, _ b: Float64) -> some Stream {
	clip(a, inf: b)
}
@inline(__always)
public func minimum(_ a: Stream, _ b: Float64) -> some Stream {
	clip(a, sup: b)
}
