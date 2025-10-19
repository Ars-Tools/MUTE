//
//  Adaptive+RLS.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
import typealias CoreMedia.CMTime
@preconcurrency import protocol Combine.Publisher
import protocol DSP.Stream
import typealias DSP.Instance
import func NSP.rls_filter_create
import func NSP.rls_filter_destroy
import func NSP.rls_filter_error
import func NSP.rls_filter_lambda
import func Layout.broadcast
import typealias Auxiliary.Autorelease
@usableFromInline
enum RLS {
	@usableFromInline
	struct Residual<Signal: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline let target: Stream
		@usableFromInline let source: Stream
		@usableFromInline let signal: Signal
		@usableFromInline let order: Int
	}
}
extension RLS.Residual: Stream {
	@inlinable
	var count: Int {
		broadcast(x: source.count, y: target.count)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try source(interval: interval, capacity: capacity, instance: &instance)
		let yk = try target(interval: interval, capacity: capacity, instance: &instance)
		let xc = source.count
		let yc = target.count
		switch broadcast(x: xc, y: yc) {
		case xc:
			let filter = repeatElement(order, count: xc).map {
				Autorelease.Object(object: rls_filter_create($0)) {
					rls_filter_destroy($0)
				}
			}
			let cancel = signal.sink {
				switch $0 {
				case filter.indices:
					rls_filter_lambda(filter[$0].reference, $1)
				default:
					assertionFailure("out of range")
				}
			}
			return { [cancel] moment, length, target, xs in
				xk(moment, length, target, xs)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: yc * length) {
					guard let memory = $0.baseAddress else { return }
					yk(moment, length, memory, length)
					let ys = broadcast(target: xc, source: yc, stride: length)
					for (offset, filter) in filter.enumerated().reversed() {
						rls_filter_error(filter.reference,
										 memory.advanced(by: offset * ys),
										 target.advanced(by: offset * xs),
										 target.advanced(by: offset * xs),
										 length)
					}
				}
			}
		case yc:
			let filter = repeatElement(order, count: yc).map {
				Autorelease.Object(object: rls_filter_create($0)) {
					rls_filter_destroy($0)
				}
			}
			let cancel = signal.sink {
				switch $0 {
				case filter.indices:
					rls_filter_lambda(filter[$0].reference, $1)
				default:
					assertionFailure("out of range")
				}
			}
			return { [cancel] moment, length, target, ys in
				yk(moment, length, target, ys)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length) {
					guard let memory = $0.baseAddress else { return }
					xk(moment, length, memory, length)
					let xs = broadcast(target: yc, source: xc, stride: length)
					for (offset, filter) in filter.enumerated().reversed() {
						rls_filter_error(filter.reference,
										 target.advanced(by: offset * ys),
										 memory.advanced(by: offset * xs),
										 target.advanced(by: offset * ys),
										 length)
					}
				}
			}
		default:
			throw Error.unmatchChannel
		}
	}
}
public func residual(target: Stream, source: Stream, rls order: Int, λ: some Publisher<(Int, Float64), Never> & Sendable) -> some Stream {
	RLS.Residual(target: target, source: source, signal: λ, order: order)
}
public func residual(target: Stream, source: Stream, rls order: Int, λ: Float64) -> some Stream {
	residual(target: target, source: source, rls: order, λ: `repeat`(λ, count: broadcast(x: source.count, y: target.count)))
}
