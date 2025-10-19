//
//  Mix+Sum.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
import typealias Synchronization.Mutex
import typealias Accelerate.vDSP
public enum Sum {
	public enum Axis: Sendable {
		case inter
		case term
		case all
	}
	@usableFromInline
	struct Ne<Source: Collection<Stream> & Sendable> {
		@usableFromInline let source: Source
		@usableFromInline let axis: Sum.Axis
	}
}
extension Sum.Ne: Stream {
	@inlinable
	var count: Int {
		switch axis {
		case.inter:
			source.count
		case.term:
			source.lazy.map(\.count).max() ?? 1
		case.all:
			1
		}
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source.map {
			try ($0(interval: interval, capacity: capacity, instance: &instance), $0.count)
		}
		switch axis {
		case.inter:
			return { moment, length, target, stride in
				each(count: kernel.count) {
					var target = UnsafeMutableBufferPointer(start: target.advanced(by: $0 * stride), count: length)
					let kernel = kernel[kernel.startIndex.advanced(by: $0)]
					vDSP.clear(&target)
					withUnsafeTemporaryAllocation(of: Float64.self, capacity: kernel.1 * length) {
						guard let memory = $0.baseAddress else { return }
						kernel.0(moment, length, memory, length)
						for source in fold(start: memory, count: length, stream: kernel.1, period: length) {
							vDSP.add(source, target, result: &target)
						}
					}
				}
			}
		case.term:
			let stream = kernel.lazy.map(\.1).max() ?? 1
			return { moment, length, target, stride in
				let target = fold(start: target, count: length, stream: stream, period: stride)
				for var target in target {
					vDSP.clear(&target)
				}
				let syntax = Mutex(SendableContainer(rawValue: target))
				each(element: kernel) { kernel, stream in
					withUnsafeTemporaryAllocation(of: Float64.self, capacity: stream * length) {
						guard let source = $0.baseAddress else { return }
						kernel(moment, length, source, length)
						syntax.withLock {
							for (source, var target) in zip(fold(start: source, count: length, stream: stream, period: length), $0.rawValue) {
								vDSP.add(source, target, result: &target)
							}
						}
					}
				}
			}
		case.all:
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: kernel.count * length) { memory in
					each(count: kernel.count) {
						let kernel = kernel[$0]
						var target = memory[$0*length..<$0*length+length]
						vDSP.clear(&target)
						withUnsafeTemporaryAllocation(of: Float64.self, capacity: kernel.1 * length) {
							guard let memory = $0.baseAddress else { return }
							kernel.0(moment, length, memory, length)
							for source in fold(start: memory, count: length, stream: kernel.1, period: length) {
								vDSP.add(source, target, result: &target)
							}
						}
					}
					var target = UnsafeMutableBufferPointer(start: target, count: length)
					vDSP.clear(&target)
					for source in fold(start: memory, count: length, stream: kernel.count, period: length) {
						vDSP.add(source, target, result: &target)
					}
				}
			}
		}
	}
}
public func Σ(_ source: some Collection<Stream> & Sendable, axis: Sum.Axis = .all) -> some Stream {
	Sum.Ne(source: source, axis: axis)
}
@_disfavoredOverload
public func Σ(_ source: Stream..., axis: Sum.Axis = .all) -> some Stream {
	Σ(source, axis: axis)
}
