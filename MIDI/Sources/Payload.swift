//
//  Payload.swift
//  MUTE
//
//  Created by Kota on 7/20/R7.
//
@preconcurrency import typealias CoreMIDI.MIDIProtocolID
@preconcurrency import typealias CoreMIDI.MIDITimeStamp
@preconcurrency import typealias CoreMIDI.MIDIEventList
@preconcurrency import typealias CoreMIDI.MIDIUniversalMessage
@preconcurrency import typealias CoreMIDI.MIDIEventPacket
@preconcurrency import func CoreMIDI.MIDIEventListInit
@preconcurrency import func CoreMIDI.MIDIEventListAdd
@preconcurrency import func CoreMIDI.MIDIEventListForEachEvent
public protocol Payload: Sendable {
	func withUnsafeEventListPointer<E, R>(_ body: (UnsafePointer<MIDIEventList>) throws (E) -> R) rethrows -> R
}
extension Payload { // LLVM Co-routine based parser
	public var sequence: some AsyncSequence<(MIDITimeStamp, MIDIUniversalMessage), Never> {
		AsyncStream {
			withUnsafePointer(to: $0) { ref in
				withUnsafeEventListPointer {
					MIDIEventListForEachEvent($0, {
						$0?.assumingMemoryBound(to: AsyncStream.Continuation.self)
							.pointee
							.yield(($1, $2))
					}, .init(mutating: ref))
				}
			}
			$0.finish()
		}
	}
}
extension Payload {
	public func a(_ body: (MIDITimeStamp, MIDIUniversalMessage) -> Void) {
		withUnsafeEventListPointer {
			MIDIEventListForEachEvent($0, {
				guard let r = $0 else { return }
				(Unmanaged<AnyObject>.fromOpaque(r).takeUnretainedValue() as?(MIDITimeStamp, MIDIUniversalMessage) -> Void)?($1, $2)
			}, Unmanaged<AnyObject>.passUnretained(body as AnyObject).toOpaque())
		}
	}
}
extension Array where Element == (MIDITimeStamp, MIDIUniversalMessage) {
	public init(_ payload: some Payload) {
		self.init()
		withUnsafeMutablePointer(to: &self) { sref in
			payload.withUnsafeEventListPointer {
				MIDIEventListForEachEvent($0, {
					$0?.assumingMemoryBound(to: Self.self).pointee.append(($1, $2))
				}, .init(sref))
			}
		}
	}
}
// MSG+Collection
extension Collection {
	@discardableResult
	@inlinable
	func`in`<T: MSG>(to target: UnsafeMutableRawBufferPointer, as `protocol`: MIDIProtocolID) -> Int where Element == (MIDITimeStamp, T) {
		let length = target.count
		let target = target.baseAddress.unsafelyUnwrapped.assumingMemoryBound(to: MIDIEventList.self)
		let cursor = reduce(MIDIEventListInit(target, `protocol`)) { a, x in
			x.1.withUnsafeBufferPointer {
				MIDIEventListAdd(target, length, a, x.0, $0.count, $0.baseAddress.unsafelyUnwrapped)
			}
		}
		return Int(bitPattern: cursor) == .zero ? 0 : MIDIEventList.sizeInBytes(pktList: target)
	}
	@discardableResult
	@inlinable
	func`in`(to target: UnsafeMutableRawBufferPointer, as `protocol`: MIDIProtocolID, at timestamp: MIDITimeStamp) -> Int where Element: MSG {
		let length = target.count
		let target = target.baseAddress.unsafelyUnwrapped.assumingMemoryBound(to: MIDIEventList.self)
		let cursor = reduce(MIDIEventListInit(target, `protocol`)) { a, x in
			x.withUnsafeBufferPointer {
				MIDIEventListAdd(target, length, a, timestamp, $0.count, $0.baseAddress.unsafelyUnwrapped)
			}
		}
		return Int(bitPattern: cursor) == .zero ? 0 : MIDIEventList.sizeInBytes(pktList: target)
	}
	@inlinable
	func withUnsafeMIDIEventList<T: MSG, E, R>(as version: MIDIProtocolID, _ body: (UnsafePointer<MIDIEventList>) throws (E) -> R) rethrows -> R where Element == (MIDITimeStamp, T) {
		try withUnsafeTemporaryAllocation(byteCount: MIDIEventList.sizeInBytes(numPackets: count), alignment: MemoryLayout<UInt32>.alignment) {
			let length = `in`(to: $0, as: version)
			assert(length != 0)
			return try body(.init(.init($0.baseAddress.unsafelyUnwrapped)))
		}
	}
}
// Fixed Memory Size MIDIEventList (deprecated)
extension MIDIEventList: @retroactive @unchecked Sendable, Payload {
	@available(*, deprecated, message: "Fixed Memory Payload is inefficient, Use Dynamic Memory Payload")
	public func withUnsafeEventListPointer<E, R>(_ body: (UnsafePointer<MIDIEventList>) throws(E) -> R) rethrows -> R {
		try withUnsafePointer(to: self, body)
	}
	@inlinable @inline(__always)
	static func sizeInBytes(numPackets count: Int) -> Int {
		MemoryLayout<MIDIProtocolID>.stride + MemoryLayout<UInt32>.stride + count * MemoryLayout<MIDIEventPacket>.stride
	}
}
// Dynamic Memory Size MIDIEventList Memory
extension UnsafePointer: @retroactive @unchecked Sendable, Payload where Pointee == MIDIEventList {
	@inlinable @inline(__always)
	public func withUnsafeEventListPointer<E, R>(_ body: (UnsafePointer<MIDIEventList>) throws(E) -> R) rethrows -> R {
		try body(self)
	}
	@inlinable @inline(__always)
	public var count: Int {
		MIDIEventList.sizeInBytes(pktList: self)
	}
}
// MIDIEventList Buffer
public struct Buffer: RawRepresentable, Sendable, Codable, Hashable {
	public let rawValue: Array<UInt8>
	@inlinable
	public init(rawValue buffer: Array<UInt8>) {
		rawValue = buffer
	}
}
extension Buffer: Payload {
	public init(_ payload: some Payload) {
		rawValue = payload.withUnsafeEventListPointer { memory in
			.init(unsafeUninitializedCapacity: memory.count) {
				$1 = $0.initialize(fromContentsOf: UnsafeRawBufferPointer(start: memory, count: $0.count))
			}
		}
	}
	public func withUnsafeEventListPointer<E, R>(_ body: (UnsafePointer<MIDIEventList>) throws (E) -> R) rethrows -> R {
		try rawValue.withUnsafeBytes {
			try body(.init(.init($0.baseAddress.unsafelyUnwrapped)))
		}
	}
}
extension Buffer {
	public init<T: MSG>(msg: some Collection<(MIDITimeStamp, T)>, as version: MIDIProtocolID) {
		rawValue = .init(unsafeUninitializedCapacity: MIDIEventList.sizeInBytes(numPackets: msg.count)) {
			$1 = msg.in(to: .init($0), as: version)
		}
	}
	public init<T: MSG>(msg: some Collection<T>, as version: MIDIProtocolID, at timestamp: MIDITimeStamp) {
		rawValue = .init(unsafeUninitializedCapacity: MIDIEventList.sizeInBytes(numPackets: msg.count)) {
			$1 = msg.in(to: .init($0), as: version, at: timestamp)
		}
	}
}
