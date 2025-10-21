//
//  Generators+Line.swift
//  MUTE
//
//  Created by Kota on 7/9/R7.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Dispatch.DispatchSourceUserDataAdd
@preconcurrency import class Dispatch.DispatchQueue
@preconcurrency import class Dispatch.DispatchSource
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias Accelerate.vDSP
import func Darwin.fma
public enum Line {
	public enum Anchor {
		case ramp(position: Float64, duration: Duration, quantise: Duration)
		case note(DispatchSourceUserDataAdd)
	}
	public class Seq {
		@usableFromInline
		let rawValue: Mutex<(Float64, Float64, Int, Array<Anchor>)> = .init((0, 0, 0, .init()))
	}
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Output), Never> & Sendable, Output: Sequence<Anchor>> {
		@usableFromInline let command: Signal
		@usableFromInline let count: Int
	}
	@usableFromInline
	struct Xe<Signal: Publisher<(Int, Anchor), Never> & Sendable> {
		@usableFromInline let command: Signal
		@usableFromInline let count: Int
	}
}
extension Line.Kr {
	@usableFromInline
	final class Instance: @unchecked Sendable {
		@usableFromInline
		let status: Mutex<(Float64, Float64, Int, Optional<Output.Iterator>)> = .init((0, 0, 0, .none))
	}
}
extension Line.Kr.Instance {
	@inlinable
	func suspend() {
		status.withLock {
			$0.2 = 0
			$0.3 = .none
		}
	}
	@inlinable
	func activate(iterator: Output.Iterator) {
		status.withLock {
			$0.2 = 0
			$0.3 = .some(iterator)
		}
	}
	@inlinable
	func render(to target: inout UnsafeMutableBufferPointer<Float64>, at time: CMTime, of interval: CMTime) {
		status.withLock {
			if 0 < $0.2 {
				let length = min($0.2, target.count)
				vDSP.formRamp(withInitialValue: $0.0, increment: $0.1, result: &target[..<length])
				$0.0 = fma(.init(length), $0.1, $0.0)
				$0.2 = $0.2 - length
				target = target.extracting(length...)
			} else {
				switch $0.3?.next() {
				case.some(.ramp(let position, let duration, let quantise)):
					let q = switch quantise.divide(by: interval) {
					case let (q, r):
						q + Int(r.convertScale(1, method: .roundTowardZero).value)
					}
					let d = switch duration.divide(by: interval) {
					case let (q, r):
						q + Int(r.convertScale(1, method: .roundAwayFromZero).value)
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
				case.some(.note(let source)):
					source.add(data: 1)
				case.none:
					vDSP.fill(&target, with: $0.0)
					target = target.extracting(target.count...)
				}
			}
		}
	}
}
extension Line.Kr: Stream {
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		switch count {
		case ..<0:
			throw Error.invalidChannel
		case 1:
			let kernel = Instance()
			let cancel = command.sink { index, command in
				switch index {
				case 0:
					kernel.activate(iterator: command.makeIterator())
				default:
					assertionFailure("out of range")
				}
			}
			return { moment, length, target, stride in
				withExtendedLifetime(cancel) {
					var target = UnsafeMutableBufferPointer(start: target, count: length)
					kernel.render(to: &target, at: moment, of: interval)
				}
			}
		case let count:
			let kernel = Array<Instance>(repeating: .init(), count: count)
			let cancel = command.sink { index, command in
				switch index {
				case kernel.indices:
					kernel[index].activate(iterator: command.makeIterator())
				default:
					assertionFailure("out of range")
				}
			}
			return { moment, length, target, stride in
				withExtendedLifetime(cancel) {
//					DispatchQueue.concurrentPerform(iterations: kernel.count, execute: unsafeBitCast({
//						kernel[$0].render(at: moment, to: target.advanced(by: $0 * stride), count: length)
//					} as (Int) -> Void, to: (@Sendable (Int) -> Void).self))
					let target = Int(bitPattern: target)
					DispatchQueue.concurrentPerform(iterations: kernel.count) {
						var target = UnsafeMutableBufferPointer<Float64>(start: .init(bitPattern: target)?.advanced(by: $0 * stride), count: length)
						kernel[$0].render(to: &target, at: moment, of: interval)
					}
				}
			}
		}
	}
}
extension Line.Anchor {
	public init(target: Float64, second: Duration = 0 as Samples, quantise: Duration = 0 as Samples) {
		self = .ramp(position: target, duration: second, quantise: quantise)
	}
	public init(queue: Optional<DispatchQueue> = .none, handler: @escaping (Int) -> Void) {
		let source = DispatchSource.makeUserDataAddSource(queue: queue)
		source.setEventHandler { [weak source] in
			handler(source.map(\.data).flatMap(Int.init(exactly:)) ?? .zero)
		}
		source.resume()
		self = .note(source)
	}
}
extension Line.Xe: Stream {
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		return {
			_ = $3
		}
	}
}


public func line(anchors command: some Publisher<(Int, some Sequence<Line.Anchor>), Never> & Sendable, count: Int) -> some Stream {
	Line.Kr(command: command, count: count)
}
public func line(anchors command: some Publisher<some Sequence<Line.Anchor>, Never>, count: Int = 1) -> some Stream {
	Line.Kr(command: command.repeat(count: count), count: count)
}
public func line<Command: Sequence<Line.Anchor>>(anchors command: some Collection<Command>) -> some Stream {
	Line.Kr(command: command.prefix(count: command.count), count: command.count)
}
@_disfavoredOverload
public func line<Command: Sequence<Line.Anchor>>(anchors command: Command...) -> some Stream {
	line(anchors: command)
}
public func line(anchors command: some Sequence<Line.Anchor>, count: Int = 1) -> some Stream {
	Line.Kr(command: `repeat`(command, count: count), count: count)
}
@_disfavoredOverload
public func line(anchors command: Line.Anchor...) -> some Stream {
	line(anchors: command)
}
