//
//  Waveshape+Table.swift
//  MUTE
//
//  Created by Kota on 6/26/R7.
//
@preconcurrency import protocol Combine.Publisher
import typealias Synchronization.Mutex
import func NSP.periodic_lookup_with_static
import func NSP.periodic_lookup_with_active
@usableFromInline
enum Wavetable {
	@usableFromInline
	struct Kr<Table: Sequence<Float64>, Signal: Publisher<(Int, Table), Never> & Sendable> {
		@usableFromInline let phasor: Stream
		@usableFromInline let signal: Signal
	}
	@usableFromInline
	struct Ar {
		@usableFromInline let phasor: Stream
		@usableFromInline let stream: Stream
	}
}
extension Wavetable.Kr: Stream {
	@inlinable
	var count: Int {
		phasor.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try phasor(interval: interval, capacity: capacity, resource: &resource)
		let stream = phasor.count
		let tables = Mutex<Array<Array<Float64>>>(.init(repeating: .init(), count: stream))
		let cancel = signal.sink { index, value in
			let table = Array(value)
			tables.withLock {
				switch index {
				case $0.indices:
					$0[index] = table
				default:
					assertionFailure("out of range")
				}
			}
		}
		return {
			kernel($0, $1, $2, $3)
			let tables = withExtendedLifetime(cancel) { tables.withLock(\.self) }
			for (offset, buffer) in tables.enumerated() {
				periodic_lookup_with_static(buffer,
											$2.advanced(by: $3 * offset),
											$2.advanced(by: $3 * offset),
											buffer.count,
											$1)
			}
		}
	}
}
extension Wavetable.Ar: Stream {
	@inlinable
	var count: Int {
		phasor.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try stream(interval: interval, capacity: capacity, resource: &resource)
		let yk = try phasor(interval: interval, capacity: capacity, resource: &resource)
		let xc = stream.count
		let yc = phasor.count
		return { moment, length, result, stride in
			yk(moment, length, result, stride)
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length) {
				guard let source = $0.baseAddress else { return }
				xk(moment, length, source, length)
				for cursor in Swift.stride(from: 0, to: yc * stride, by: stride).lazy.map(result.advanced(by:)) {
					periodic_lookup_with_active(source, length,
												cursor,
												cursor,
												xc,
												length)
				}
			}
		}
	}
}
public func wavetable(_ source: Stream, table signal: some Publisher<(Int, some Sequence<Float64>), Never> & Sendable) -> some Stream {
	Wavetable.Kr(phasor: source, signal: signal)
}
public func wavetable(_ source: Stream, table: some Publisher<some Sequence<Float64>, Never>) -> some Stream {
	wavetable(source, table: table.repeat(count: source.count))
}
public func wavetable(_ source: Stream, table: some Sequence<Float64>) -> some Stream {
	wavetable(source, table: `repeat`(table, count: source.count))
}
@_disfavoredOverload
public func wavetable(_ source: Stream, table: Float64...) -> some Stream {
	wavetable(source, table: table)
}
public func wavetable(_ source: Stream, table: Stream) -> some Stream {
	Wavetable.Ar(phasor: source, stream: table)
}
