//
//  Common+Duffing.swift
//  MUTE
//
//  Created by Kota on 8/17/R7.
//
import typealias CoreMedia.CMTime
import typealias Auxiliary.Autorelease
import typealias Synchronization.Mutex
import typealias Synchronization.Atomic
import protocol DSP.Stream
import typealias DSP.BiquadFilter
import typealias DSP.Instance
import func NSP.duffing_filter_create
import func NSP.duffing_filter_destroy
import func NSP.duffing_filter_static
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Just
@usableFromInline
enum Duffing {
	@usableFromInline
	struct Kr<Signal: Publisher<SIMD2<Float64>, Never> & Sendable> {
		@usableFromInline let source: Stream
		@usableFromInline let design: BiquadFilter.Design
		@usableFromInline let signal: Signal
	}
}
extension Duffing.Kr: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let stream = source.count
		let object = Autorelease.Object(object: duffing_filter_create(stream)) {
			duffing_filter_destroy($0)
		}
		let α = Atomic<Float64>(1)
		let β = Atomic<Float64>(0)
		let (b₀, b₁, b₂, a₁, a₂) = design.coefficients(for: interval)
		let cancel = signal.sink {
			α.store($0.x, ordering: .releasing)
			β.store($0.y, ordering: .releasing)
		}
		return { [cancel] in
			kernel($0, $1, $2, $3)
			duffing_filter_static(object.reference,
								  [b₀, b₁, b₂], 0,
								  [α.load(ordering: .acquiring), a₁, a₂, β.load(ordering: .acquiring)], 0,
								  $2, $3,
								  $2, $3,
								  $1)
		}
	}
}
public func filter(_ source: Stream, duffing design: BiquadFilter.Design, αβ signal: some Publisher<SIMD2<Float64>, Never> & Sendable) -> some Stream {
	Duffing.Kr(source: source, design: design, signal: signal)
}
public func filter(_ source: Stream, duffing design: BiquadFilter.Design, αβ signal: SIMD2<Float64>) -> some Stream {
	Duffing.Kr(source: source, design: design, signal: Just(signal))
}
