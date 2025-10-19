//
//  Mix+Poly.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Publishers
import typealias Accelerate.vDSP
import func Layout.broadcast
import Synchronization
@usableFromInline
enum Poly {
	@usableFromInline
	struct He<Source: Sequence<Stream> & Sendable> {
		@usableFromInline let source: Source
	}
	@usableFromInline
	struct Xe<Source: Publisher<Stream, Never>> {
		@usableFromInline let source: Source
	}
}
extension Poly.He: Stream {
	@inlinable
	var count: Int {
		source.lazy.map(\.count).max() ?? 1
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source.map {
			try ($0(interval: interval, capacity: capacity, instance: &instance), $0.count)
		}
		let stream = kernel.lazy.map(\.1).max() ?? 1
		return { moment, length, target, stride in
			let target = fold(start: target, count: length, stream: stream, period: stride)
			for var target in target {
				vDSP.clear(&target)
			}
			let syntax = Mutex(SendableContainer(rawValue: target))
			each(element: kernel) { kernel, number in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: number * length) {
					guard let source = $0.baseAddress else { return }
					kernel(moment, length, source, length)
					syntax.withLock {
						for (source, var target) in zip(fold(start: source, count: length, stream: number, period: length), $0.rawValue) {
							vDSP.add(source, target, result: &target)
						}
					}
				}
			}
		}
	}
}
public func mix<Signal: Publisher<(Int, Output), Never>, Output>(poly output: Int, each signal: Signal, allocate: (Publishers.CompactMap<Signal, Output>) -> some Stream) -> some Stream {
	Poly.He(source: repeatElement(signal, count: output).enumerated().map { idx, pub in
		allocate(pub.compactMap {
			idx == $0 ? .some($1) : .none
		})
	})
}
//extension Set {
//	@inlinable @inline(__always)
//	func uncontained(_ element: Element) -> Bool {
//		!contains(element)
//	}
//}
public func mix<Q: Publisher<P, Never>, P: Publisher<O, Never>, O>(poly output: Int, each signal: Q, allocate: (Publishers.CompactMap<Publishers.FlatMap<Publishers.HandleEvents<Publishers.Map<P, (Int, O)>>, Q>, O>) -> some Stream) -> some Stream {
	let whole = Set(0..<output)
	let alloc = Mutex<Set<Int>>(.init())
	let signal = signal.flatMap(maxPublishers: .max(output)) {
		let index = alloc.withLock {
			let index = whole.subtracting($0).first ?? $0.count
			$0.insert(index)
			return index
//			switch (0...).first(where: $0.uncontained) {
//			case.some(let first):
//				$0.insert(first)
//				return first
//			case.none:
//				assertionFailure()
//				return.zero
//			}
		}
		return $0.map { (index, $0) }.handleEvents(receiveCompletion: .some({ completion in
			alloc.withLock {
				$0.remove(index)
			} as Void
		}), receiveCancel: .some({
			alloc.withLock {
				$0.remove(index)
			} as Void
		}))
	} as Publishers.FlatMap<Publishers.HandleEvents<Publishers.Map<P, (Int, O)>>, Q>
	return mix(poly: output, each: signal, allocate: allocate)
}
public func mix<Signal: Publisher<Output, Never>, Output>(poly output: some Collection<Signal>, allocate: (Signal) -> Stream) -> some Stream {
	Poly.He(source: output.map(allocate))
}
public func mix<Signal: Sequence<Output>, Output>(poly output: Int, signal: Signal, allocate: (any Publisher<Output, Never>) -> some Stream) -> some Stream {
	mix(poly: output, each: signal.prefix(count: output), allocate: allocate)
}
