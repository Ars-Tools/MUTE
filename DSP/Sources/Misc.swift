//
//  Misc.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
@preconcurrency import typealias Dispatch.DispatchQueue
import func Darwin.memmove
import func Accelerate.vDSP_mmovD
import func Accelerate.vDSP_vclrD
@inlinable@inline(__always)@_transparent
func copy(x: UnsafePointer<Float64>, ldx: Int,
		  y: UnsafeMutablePointer<Float64>, ldy: Int,
		  rows: Int, cols: Int) {
//	for row in 0..<rows {
//		memmove(y.advanced(by: row * ldy), x.advanced(by: row * ldx), cols * MemoryLayout<Float64>.stride)
//	}
	vDSP_mmovD(x, y, .init(cols), .init(rows), .init(ldx), .init(ldy))
}
@inlinable@inline(__always)@_transparent
func zero(x: UnsafeMutablePointer<Float64>, ldx: Int,
          rows: Int, cols: Int) {
    for r in stride(from: x, to: x.advanced(by: rows * ldx), by: ldx) {
        vDSP_vclrD(r, 1, .init(cols))
    }
}
@inlinable@inline(__always)@_transparent
func each(count: Int, closure: (Int) -> Void) {
	withoutActuallyEscaping(closure) {
		DispatchQueue.concurrentPerform(iterations: count, execute: unsafeBitCast($0 as (Int) -> Void, to: (@Sendable(Int) -> Void).self))
	}
//	(0..<count).forEach(closure)
}
@inlinable@inline(__always)@_transparent
func each<C: Collection>(element: C, closure: (C.Element) -> Void) where C.Index: Strideable, C.Index.Stride == Int {
	each(count: element.count) { closure(element[element.startIndex.advanced(by: $0)]) }
}
@inlinable@inline(__always)@_transparent
func fold<T>(start: UnsafePointer<T>, count: Int, stream: Int, period: Int) -> Array<UnsafeBufferPointer<T>> {
	zip(stride(from: 0, to: stream * period, by: period).lazy.map(start.advanced(by:)), repeatElement(count, count: stream)).map(UnsafeBufferPointer<T>.init(start:count:))
}
@inlinable@inline(__always)@_transparent
func fold<T>(start: UnsafeMutablePointer<T>, count: Int, stream: Int, period: Int) -> Array<UnsafeMutableBufferPointer<T>> {
	zip(stride(from: 0, to: stream * period, by: period).lazy.map(start.advanced(by:)), repeatElement(count, count: stream)).map(UnsafeMutableBufferPointer<T>.init(start:count:))
}
@inlinable@inline(__always)@_transparent
func fold<T>(start: UnsafeMutableBufferPointer<T>, count: Int, stream: Int, period: Int) -> Array<UnsafeMutableBufferPointer<T>> {
	stride(from: 0, to: stream * period, by: period).map { start.extracting($0..<$0+count) }
}
@inlinable@inline(__always)@_transparent
func fold(target: Buffer) -> Array<UnsafeMutableBufferPointer<Float64>> {
	fold(start: target.start, count: target.period, stream: target.stream, period: target.period)
}
@usableFromInline
@dynamicMemberLookup
struct SendableContainer<RawValue>: @unchecked Sendable, RawRepresentable {
	@usableFromInline
	let rawValue: RawValue
	@inlinable
	init(rawValue: RawValue) {
		self.rawValue = rawValue
	}
}
extension SendableContainer {
	subscript<R>(dynamicMember dynamicMember: KeyPath<RawValue, R>) -> R {
		rawValue[keyPath: dynamicMember]
	}
	subscript<R>(dynamicMember dynamicMember: ReferenceWritableKeyPath<RawValue, R>) -> R {
		_read {
			yield rawValue[keyPath: dynamicMember]
		}
		_modify {
			yield &rawValue[keyPath: dynamicMember]
		}
	}
}
extension SendableContainer: BitwiseCopyable where RawValue: BitwiseCopyable {}
extension SendableContainer: Codable where RawValue: Codable {}
extension SendableContainer: Identifiable where RawValue: Identifiable {
	@inlinable
	var id: RawValue.ID { rawValue.id }
}
extension SendableContainer: Hashable & Equatable where RawValue: Hashable & Equatable {
	@inlinable
	func hash(into hasher: inout Hasher) {
		rawValue.hash(into: &hasher)
	}
	@inlinable
	static func==(lhs: SendableContainer, rhs: SendableContainer) -> Bool {
		lhs.rawValue == rhs.rawValue
	}
}
extension SendableContainer: Sequence & BidirectionalCollection & Collection & RandomAccessCollection where RawValue: Sequence & Collection & BidirectionalCollection & RandomAccessCollection {
	@usableFromInline
	typealias Element = RawValue.Element
	@usableFromInline
	typealias Index = RawValue.Index
	@inlinable
	var count: Int {
		rawValue.count
	}
	@inlinable
	var startIndex: RawValue.Index {
		rawValue.startIndex
	}
	@inlinable
	var endIndex: RawValue.Index {
		rawValue.endIndex
	}
	@inlinable
	func index(before i: Index) -> Index {
		rawValue.index(before: i)
	}
	@inlinable
	func index(after i: Index) -> Index {
		rawValue.index(before: i)
	}
	@inlinable
	subscript(position: Index) -> Element {
		_read {
			yield rawValue[position]
		}
	}
	@inlinable
	subscript(bounds: Range<RawValue.Index>) -> RawValue.SubSequence {
		_read {
			yield rawValue[bounds]
		}
	}
}
