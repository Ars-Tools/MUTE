//
//  Adaptive+GAL.swift
//  MUTE
//
//  Created by Kota on 8/15/R7.
//
import typealias CoreMedia.CMTime
import protocol DSP.Stream
import typealias DSP.Instance
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias Auxiliary.Autorelease
import func NSP.gal_create
import func NSP.gal_destroy
import func NSP.gal_mu
import func NSP.gal_p
import func NSP.gal_r
import func NSP.gal_e
import func Layout.broadcast
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Just
@usableFromInline
enum GAL {
	@usableFromInline
	struct PARCOR<Signal: Publisher<Float64, Never> & Sendable> {
		@usableFromInline let y₀: Stream
		@usableFromInline let μ: Signal
		@usableFromInline let count: Int
	}
	@usableFromInline
	struct Residual<Signal: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline let y₀: Stream
		@usableFromInline let μ: Signal
		@usableFromInline let order: Int
	}
	@usableFromInline
	struct Error<Signal: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline let d₀: Stream
		@usableFromInline let y₀: Stream
		@usableFromInline let μ: Signal
		@usableFromInline let order: Int
	}
}
extension GAL.PARCOR: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		guard y₀.count == 1 else { throw Error.invalidChannel }
		let yₖ = try y₀(interval: interval, capacity: capacity, instance: &instance)
		let object = Autorelease.Object(object: gal_create(count)) {
			gal_destroy($0)
		}
		let cancel = μ.sink {
			gal_mu(object.reference, $0)
		}
		return { [cancel] in
			yₖ($0, $1, $2, $3)
			gal_p(object.reference,
				  $2,
				  $2, $3,
				  $1)
		}
	}
}
extension GAL.Residual: Stream {
	@inlinable
	var count: Int {
		y₀.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let object = repeatElement(order, count: y₀.count).map {
			Autorelease.Object(object: gal_create($0)) {
				gal_destroy($0)
			}
		}
		let yₖ = try y₀(interval: interval, capacity: capacity, instance: &instance)
		let cancel = μ.sink {
			switch $0 {
			case object.indices:
				gal_mu(object[$0].reference, $1)
			default:
				assertionFailure("out of range")
			}
		}
		return { [cancel] in
			yₖ($0, $1, $2, $3)
			for (offset, object) in object.enumerated() {
				gal_r(object.reference,
					  $2.advanced(by: offset * $3),
					  $2.advanced(by: offset * $3),
					  $1)
			}
		}
	}
}
extension GAL.Error: Stream {
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
				Autorelease.Object(object: gal_create($0)) {
					gal_destroy($0)
				}
			}
			let cancel = μ.sink {
				switch $0 {
				case object.indices:
					gal_mu(object[$0].reference, $1)
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
						gal_e(object.reference,
							  memory.advanced(by: offset * ys),
							  target.advanced(by: offset * stride),
							  target.advanced(by: offset * stride),
							  length)
					}
				}
			}
		case yc:
			let object = repeatElement(order, count: yc).map {
				Autorelease.Object(object: gal_create($0)) {
					gal_destroy($0)
				}
			}
			let cancel = μ.sink {
				switch $0 {
				case object.indices:
					gal_mu(object[$0].reference, $1)
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
						gal_e(object.reference,
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
public func parcor(target: Stream, sgd order: Int, μ: some Publisher<Float64, Never> & Sendable) -> some Stream {
	GAL.PARCOR(y₀: target, μ: μ, count: order)
}
public func parcor(target: Stream, sgd order: Int, μ: Float64) -> some Stream {
	GAL.PARCOR(y₀: target, μ: Just(μ), count: order)
}
public func residual(target: Stream, sgd order: Int, μ: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	GAL.Residual(y₀: target, μ: μ, order: order)
}
public func residual(target: Stream, sgd order: Int, μ: some Publisher<Float64, Never> & Sendable) -> some Stream {
	GAL.Residual(y₀: target, μ: μ.repeat(count: target.count), order: order)
}
public func residual(target: Stream, sgd order: Int, μ: some Sequence<Float64>) -> some Stream {
	GAL.Residual(y₀: target, μ: μ.prefix(count: target.count), order: order)
}
public func residual(target: Stream, sgd order: Int, μ: Float64) -> some Stream {
	GAL.Residual(y₀: target, μ: `repeat`(μ, count: target.count), order: order)
}
public func residual(target: Stream, source: Stream, gal order: Int, μ: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	GAL.Error(d₀: target, y₀: source, μ: μ, order: order)
}
public func residual(target: Stream, source: Stream, gal order: Int, μ: some Publisher<Float64, Never> & Sendable) -> some Stream {
	GAL.Error(d₀: target, y₀: source, μ: μ.repeat(count: target.count), order: order)
}
public func residual(target: Stream, source: Stream, gal order: Int, μ: some Sequence<Float64>) -> some Stream {
	GAL.Error(d₀: target, y₀: source, μ: μ.prefix(count: target.count), order: order)
}
public func residual(target: Stream, source: Stream, gal order: Int, μ: Float64) -> some Stream {
	GAL.Error(d₀: target, y₀: source, μ: `repeat`(μ, count: target.count), order: order)
}
