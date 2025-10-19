//
//  Generator+Line.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Dispatch.DispatchSourceUserDataReplace
@preconcurrency import typealias Dispatch.DispatchQueue
@preconcurrency import typealias Dispatch.DispatchSource
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias Accelerate.vDSP
import func Darwin.fma
public enum Line {
	public enum Anchor {
		case ramp(position: Float64, duration: Duration, quantise: Duration)
		case hold(duration: Duration, quantise: Duration)
		case note(DispatchSourceUserDataReplace)
	}
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Output), Never> & Sendable, Output: Sequence<Anchor>> {
		@usableFromInline let order: Signal
		@usableFromInline let count: Int
	}
}
extension Line.Kr {
	@usableFromInline
	final class Generator: Sendable {
		@usableFromInline
		let rawValue: Mutex<(Float64, Float64, Int, Optional<Output.Iterator>)> = .init((0, 0, 0, .none))
	}
}
extension Line.Kr.Generator {
	func callAsFunction(moment: CMTime, length: Int, target: UnsafeMutableBufferPointer<Float64>, interval: CMTime) {
		rawValue.withLock {
			var cursor = 0
			while target.indices ~= cursor {
				if 0 < $0.2 {
					let range = cursor..<min(cursor + $0.2, length)
					vDSP.formRamp(withInitialValue: $0.0, increment: $0.1, result: &target[range])
					$0.0 = fma(.init(range.count), $0.1, $0.0)
					$0.2 = $0.2 - range.count
					cursor = range.upperBound
				} else if case.some(let next) = $0.3?.next() {
					switch next {
					case.ramp(let position, let duration, let quantise):
						let q = switch quantise.divide(by: interval) {
						case let (q, r):
							q + Int(r.convertScale(1, method: .roundTowardNegativeInfinity).value)
						}
						let d = switch duration.divide(by: interval) {
						case let (q, r):
							q + Int(r.convertScale(1, method: .roundTowardPositiveInfinity).value)
						}
						let p = switch q {
						case 0:
							d
						case let divide:
							switch d.quotientAndRemainder(dividingBy: divide) {
							case (let q, let r):
								(q + r.signum()) * divide
							}
						}
						switch p {
						case 0:
							$0.0 = position
							$0.1 = 0
							$0.2 = p
						default:
							$0.1 = (position - $0.0) / .init(p)
							$0.2 = p
						}
					case.hold(let duration, let quantise):
						let q = switch quantise.divide(by: interval) {
						case let (q, r):
							q + Int(r.convertScale(1, method: .roundTowardNegativeInfinity).value)
						}
						let d = switch duration.divide(by: interval) {
						case let (q, r):
							q + Int(r.convertScale(1, method: .roundTowardPositiveInfinity).value)
						}
						$0.1 = 0
						$0.2 = switch q {
						case 0:
							d
						case let divide:
							switch d.quotientAndRemainder(dividingBy: divide) {
							case (let q, let r):
								(q + r.signum()) * divide
							}
						}
					case.note(let notify):
						notify.replace(data: .init(moment.samples(for: interval) + cursor))
					}
				} else {
					vDSP.fill(&target[cursor..<length], with: $0.0)
					cursor = length
				}
			}
		}
	}
	func activate(iterator: Output.Iterator) {
		rawValue.withLock {
			$0.2 = 0
			$0.3 = iterator
		}
	}
}
extension Line.Kr: Stream {
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch count {
		case ...0:
			throw Error.invalidChannel
		case 1:
			let kernel = Generator()
			let cancel = order.sink {
				switch $0 {
				case 0:
					kernel.activate(iterator: $1.makeIterator())
				default:
					assertionFailure("out of range")
				}
			}
			return { moment, length, target, stride in
				withExtendedLifetime(cancel) {
					kernel(moment: moment, length: length, target: .init(start: target, count: length), interval: interval)
				}
			}
		default:
			let kernel = Array<Generator>(repeating: .init(), count: count)
			let cancel = order.sink {
				switch $0 {
				case kernel.indices:
					kernel[$0].activate(iterator: $1.makeIterator())
				default:
					assertionFailure("out of range")
				}
			}
			return { moment, length, target, stride in
				withExtendedLifetime(cancel) {
					each(count: kernel.count) {
						kernel[$0](moment: moment,
								   length: length,
								   target: .init(start: target.advanced(by: $0 * stride), count: length),
								   interval: interval)
					}
				}
			}
		}
	}
}
extension Line.Anchor {
	public init(position: Float64, duration: Duration = 0 as Samples, quantise: Duration = 0 as Samples) {
		self = .ramp(position: position, duration: duration, quantise: quantise)
	}
	public init(duration: Duration, quantise: Duration = 0 as Samples) {
		self = .hold(duration: duration, quantise: quantise)
	}
	public init(queue: Optional<DispatchQueue> = .none, notify: @escaping (Int) -> Void) {
		let source = DispatchSource.makeUserDataReplaceSource(queue: queue)
		source.setEventHandler { [weak source] in
			notify(source.map(\.data).flatMap(Int.init(exactly:)) ?? .zero)
		}
		source.resume()
		self = .note(source)
	}
}
public func line(order: some Publisher<(Int, some Sequence<Line.Anchor>), Never> & Sendable, count: Int) -> some Stream {
	Line.Kr(order: order, count: count)
}
public func line(order: some Publisher<some Sequence<Line.Anchor>, Never>, count: Int = 1) -> some Stream {
	Line.Kr(order: order.repeat(count: count), count: count)
}
public func line<Command: Sequence<Line.Anchor>>(order: some Collection<Command>) -> some Stream {
	Line.Kr(order: order.prefix(count: order.count), count: order.count)
}
@_disfavoredOverload
public func line<Command: Sequence<Line.Anchor>>(order: Command...) -> some Stream {
	line(order: order)
}
public func line(order: some Sequence<Line.Anchor>, count: Int = 1) -> some Stream {
	Line.Kr(order: `repeat`(order, count: count), count: count)
}
@_disfavoredOverload
public func line(order: Line.Anchor...) -> some Stream {
	line(order: order)
}
