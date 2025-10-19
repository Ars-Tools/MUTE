//
//  Adaptive+GSO.swift
//  MUTE
//
//  Created by Kota on 8/16/R7.
//
import typealias CoreMedia.CMTime
import protocol DSP.Stream
import typealias DSP.Instance
import func NSP.gso_create
import func NSP.gso_destroy
import func NSP.gso_lambda
import func NSP.gso_residual
import typealias Auxiliary.Autorelease
@preconcurrency import Combine
@usableFromInline
enum GSO {
    @usableFromInline
	struct Residual<Signal: Publisher<Float64, Never> & Sendable> {
        @usableFromInline let source: Stream
        @usableFromInline let signal: Signal
	}
}
extension GSO.Residual: Stream {
    @inlinable
	var count: Int {
		source.count
	}
    @inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let object = Autorelease.Object(object: gso_create(source.count)) {
			gso_destroy($0)
		}
		let cancel = signal.sink {
			gso_lambda(object.reference, $0)
		}
		return { [cancel] in
			kernel($0, $1, $2, $3)
			gso_residual(object.reference,
						 $2, $3,
						 $2, $3,
						 $1)
		}
	}
}
public func orthogonalize(_ source: Stream, λ signal: some Publisher<Float64, Never> & Sendable) -> some Stream {
	GSO.Residual(source: source, signal: signal)
}
public func orthogonalize(_ source: Stream, λ: Float64) -> some Stream {
	orthogonalize(source, λ: Just(λ))
}
