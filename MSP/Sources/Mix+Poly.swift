//
//  Mix+Poly.swift
//  MUTE
//
//  Created by Kota on 6/5/R7.
//
//import typealias Synchronization.Mutex
//@preconcurrency import protocol Combine.Publisher
//@preconcurrency import protocol Combine.Subscriber
//@preconcurrency import typealias Combine.PassthroughSubject
//@preconcurrency import typealias Combine.Publishers
//@preconcurrency import CoreMedia
//import typealias Accelerate.vDSP
//public enum Poly {
//	struct Kr<Source: Stream>: RawRepresentable {
//		@usableFromInline
//		typealias RawValue = Array<Source>
//		@usableFromInline let rawValue: RawValue
//	}
//	@usableFromInline
//	struct Xe<Object: Publisher<(CMTime, Stream), Never>, Signal: Publisher<Object, Never> & Sendable> {
//		@usableFromInline let output: Int
//		@usableFromInline let signal: Signal
//		@usableFromInline let status: PassthroughSubject<Swift.Error, Never>
//	}
//}
//extension Poly.Kr: Stream {
//	@inlinable
//	var count: Int {
//		rawValue.map(\.count).max() ?? 0
//	}
//	@usableFromInline
//	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//		let kernel = try rawValue.map {
//			try $0(interval: interval, capacity: capacity, resource: &resource)
//		}
//		let stream = count
//		return { moment, length, target, stride in
//			for target in Swift.stride(from: 0, to: stream * stride, by: stride).lazy.map(target.advanced(by:)) {
//				target.initialize(repeating: 0, count: length)
//			}
//			let semaphore = DispatchSemaphore(value: 1)
//			let target = Int(bitPattern: target)
//			DispatchQueue.concurrentPerform(iterations: kernel.count) { idx in
//				withUnsafeTemporaryAllocation(of: Float64.self, capacity: stream * length) {
//					guard let source = $0.baseAddress, let target = UnsafeMutablePointer<Float64>(bitPattern: target) else { return }
//					kernel[idx](moment, length, source, length)
//					semaphore.wait()
//					defer {
//						semaphore.signal()
//					}
//					for (source, target) in zip(Swift.stride(from: 0, to: stream * length, by: length).lazy.map(source.advanced(by:)),
//												Swift.stride(from: 0, to: stream * stride, by: stride).lazy.map(target.advanced(by:))) {
//						let source = UnsafeBufferPointer(start: source, count: length)
//						var target = UnsafeMutableBufferPointer(start: target, count: length)
//						vDSP.add(source, target, result: &target)
//					}
//				}
//			}
//		}
//	}
//}
//extension Poly.Xe: Stream {
//	@inlinable
//	var count: Int {
//		output
//	}
//	@usableFromInline
//	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//		var resource = Resource()
//		let object = Mutex<Dictionary<ObjectIdentifier, (Int, @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void, (Bool, CMTime))>>(.init())
//		let cancel = signal.flatMap {
//			let status = PassthroughSubject<Swift.Error, Never>()
//			let unique = status.id
//			let cancel = $0.sink { [unowned status] in
//				_ = object.withLock {
//					$0.removeValue(forKey: unique)
//				}
//				status.send(completion: $0)
//			} receiveValue: { [unowned status] anchor, source in
//				do {
//					_ = try object.withLock {
//						try $0.updateValue((source.count, source(interval: interval, capacity: capacity, resource: &resource), (false, anchor)), forKey: unique)
//					}
//				} catch {
//					status.send(error)
//				}
//			}
//			return status.handleEvents(receiveCancel: cancel.cancel)
//		}.subscribe(status)
//		return { moment, length, target, stride in
//			let source = withExtendedLifetime(cancel) {
//				object.withLock {
//					for (key, value) in $0 where !value.2.0 {
//						switch value.2.1 {
//						case.invalid,.negativeInfinity,.positiveInfinity:
//							$0.removeValue(forKey: key)
//						case.indefinite:
//							$0[key]?.2 = (true, moment)
//						case let anchor:
//							$0[key]?.2 = (true, moment.quantise(by: anchor, rounding: .roundTowardPositiveInfinity))
//						}
//					}
//					return $0.values.filter {
//						$2.0 && $2.1 <= moment
//					}
//				}
//			}
//			var target = Swift.zip(Swift.stride(from: 0, to: output * stride, by: stride).lazy.map(target.advanced(by:)), sequence(first: length, next: \.self)).map(UnsafeMutableBufferPointer.init)
//			for var result in target {
//				vDSP.clear(&result)
//			}
//			withUnsafeTemporaryAllocation(of: Float64.self, capacity: output * length) {
//				guard let memory = $0.baseAddress else { return }
//				for (output, kernel, anchor) in source {
//					kernel(moment - anchor.1, length, memory, length)
//					for offset in 0..<output {
//						vDSP.add(UnsafeBufferPointer(start: memory.advanced(by: offset * length), count: length),
//								 target[offset],
//								 result: &target[offset])
//					}
//				}
//			}
//		}
//	}
//}
//extension Poly.Xe: Publisher {
//	@usableFromInline typealias Output = Swift.Error
//	@usableFromInline typealias Failure = Never
//	@inlinable
//	func receive(subscriber: some Subscriber<Output, Failure>) {
//		status.receive(subscriber: subscriber)
//	}
//}
//extension PassthroughSubject: @retroactive Identifiable {}
//public func mix(source signal: some Publisher<some Publisher<(CMTime, Stream), Never>, Never> & Sendable, output: Int) -> some Stream & Publisher<Swift.Error, Never> {
//	Poly.Xe(output: output, signal: signal, status: .init())
//}
//public func mix<Signal: Publisher<(Int, Output), Never>, Output>(trigger signal: Signal, count: Int, voice: (Publishers.CompactMap<Signal, Output>) -> some Stream) -> some Stream {
//	Poly.Kr(rawValue: repeatElement(signal, count: count).enumerated().map { index, element in
//		element.compactMap {
//			$0 == index ? .some($1) : .none
//		}
//	}.map(voice))
//}
