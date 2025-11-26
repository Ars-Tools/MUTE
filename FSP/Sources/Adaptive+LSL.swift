//
//  Adaptive+LSL.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
import typealias CoreMedia.CMTime
import protocol DSP.Stream
import typealias DSP.Instance
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias Auxiliary.Autorelease
import func NSP.lsl_create
import func NSP.lsl_destroy
import func NSP.lsl_lambda
import func NSP.lsl_p
import func NSP.lsl_r
import func NSP.lsl_e
import func Layout.broadcast
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Just
@usableFromInline
enum LSL {
	@usableFromInline
	struct PARCOR<Signal: Publisher<Float64, Never> & Sendable> {
		@usableFromInline let y₀: Stream
		@usableFromInline let λ: Signal
		@usableFromInline let count: Int
	}
	@usableFromInline
	struct Residual<Signal: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline let y₀: Stream
		@usableFromInline let λ: Signal
		@usableFromInline let order: Int
	}
	@usableFromInline
	struct Error<Signal: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline let d₀: Stream
		@usableFromInline let y₀: Stream
		@usableFromInline let λ: Signal
		@usableFromInline let order: Int
	}
}
extension LSL.PARCOR: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		guard y₀.count == 1 else { throw Error.invalidChannel }
		let yₖ = try y₀(interval: interval, capacity: capacity, instance: &instance)
		let object = Autorelease.Object(object: lsl_create(count)) {
			lsl_destroy($0)
		}
		let cancel = λ.sink {
			lsl_lambda(object.reference, $0)
		}
		return { [cancel] in
			yₖ($0, $1, $2, $3)
			lsl_p(object.reference,
				  $2,
				  $2, $3,
				  $1)
		}
	}
}
extension LSL.Residual: Stream {
	@inlinable
	var count: Int {
		y₀.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let object = repeatElement(order, count: y₀.count).map {
			Autorelease.Object(object: lsl_create($0)) {
				lsl_destroy($0)
			}
		}
		let yₖ = try y₀(interval: interval, capacity: capacity, instance: &instance)
		let cancel = λ.sink {
			switch $0 {
			case object.indices:
				lsl_lambda(object[$0].reference, $1)
			default:
				assertionFailure("out of range")
			}
		}
		return { [cancel] in
			yₖ($0, $1, $2, $3)
			for (offset, object) in object.enumerated() {
				lsl_r(object.reference,
					  $2.advanced(by: offset * $3),
					  $2.advanced(by: offset * $3),
					  $1)
			}
		}
	}
}
extension LSL.Error: Stream {
	@inlinable
	var count: Int {
		broadcast(x: d₀.count, y: y₀.count)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let dk = try d₀(interval: interval, capacity: capacity, instance: &instance)
		let yk = try y₀(interval: interval, capacity: capacity, instance: &instance)
		let dc = d₀.count
		let yc = y₀.count
		switch broadcast(x: dc, y: yc) {
		case dc:
			let object = repeatElement(order, count: dc).map {
				Autorelease.Object(object: lsl_create($0)) {
					lsl_destroy($0)
				}
			}
			let cancel = λ.sink {
				switch $0 {
				case object.indices:
					lsl_lambda(object[$0].reference, $1)
				default:
					assertionFailure("out of range")
				}
			}
			return { [cancel] moment, length, target, stride in
				dk(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: yc * length) {
					guard let memory = $0.baseAddress else { return }
					let ys = broadcast(target: dc, source: yc, stride: length)
					yk(moment, length, memory, ys)
					for (offset, object) in object.enumerated().reversed() {
						lsl_e(object.reference,
							  memory.advanced(by: offset * ys),
							  target.advanced(by: offset * stride),
							  target.advanced(by: offset * stride),
							  length)
					}
				}
			}
		case yc:
			let object = repeatElement(order, count: yc).map {
				Autorelease.Object(object: lsl_create($0)) {
					lsl_destroy($0)
				}
			}
			let cancel = λ.sink {
				switch $0 {
				case object.indices:
					lsl_lambda(object[$0].reference, $1)
				default:
					assertionFailure("out of range")
				}
			}
			return { [cancel] moment, length, target, stride in
				yk(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: dc * length) {
					guard let memory = $0.baseAddress else { return }
					let ds = broadcast(target: yc, source: dc, stride: length)
					dk(moment, length, memory, ds)
					for (offset, object) in object.enumerated().reversed() {
						lsl_e(object.reference,
							  target.advanced(by: offset * stride),
							  memory.advanced(by: offset * ds),
							  target.advanced(by: offset * stride),
							  length)
					}
				}
			}
		default:
			throw Error.invalidChannel
		}
	}
}
public func kernel(target: Stream, rls order: Int, λ: some Publisher<Float64, Never> & Sendable) -> some Stream {
	LSL.PARCOR(y₀: target, λ: λ, count: order)
}
public func kernel(target: Stream, rls order: Int, λ: Float64) -> some Stream {
	LSL.PARCOR(y₀: target, λ: Just(λ), count: order)
}
public func residual(target: Stream, rls order: Int, λ: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	LSL.Residual(y₀: target, λ: λ, order: order)
}
public func residual(target: Stream, rls order: Int, λ: some Publisher<Float64, Never> & Sendable) -> some Stream {
	LSL.Residual(y₀: target, λ: λ.repeat(count: target.count), order: order)
}
public func residual(target: Stream, rls order: Int, λ: some Sequence<Float64>) -> some Stream {
	LSL.Residual(y₀: target, λ: λ.prefix(count: target.count), order: order)
}
public func residual(target: Stream, rls order: Int, λ: Float64) -> some Stream {
	LSL.Residual(y₀: target, λ: `repeat`(λ, count: target.count), order: order)
}
public func residual(target: Stream, source: Stream, lsl order: Int, λ: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	LSL.Error(d₀: target, y₀: source, λ: λ, order: order)
}
public func residual(target: Stream, source: Stream, lsl order: Int, λ: some Publisher<Float64, Never> & Sendable) -> some Stream {
	LSL.Error(d₀: target, y₀: source, λ: λ.repeat(count: target.count), order: order)
}
public func residual(target: Stream, source: Stream, lsl order: Int, λ: some Sequence<Float64>) -> some Stream {
	LSL.Error(d₀: target, y₀: source, λ: λ.prefix(count: target.count), order: order)
}
public func residual(target: Stream, source: Stream, lsl order: Int, λ: Float64) -> some Stream {
	LSL.Error(d₀: target, y₀: source, λ: `repeat`(λ, count: target.count), order: order)
}
