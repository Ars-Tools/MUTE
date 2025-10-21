//
//  Extension+Sequence.swift
//  MUTE
//
//  Created by Kota on 6/25/R7.
//
@preconcurrency import protocol Combine.Publisher
import func Layout.concat
extension Sequence {
	@inlinable @inline(__always)
	func roll(head count: Int) -> some Sequence<Element> {
		concat(dropFirst(count), prefix(count))
	}
	@inlinable @inline(__always)
	func roll(tail count: Int) -> some Sequence<Element> {
		concat(suffix(count), dropLast(count))
	}
	@inlinable @inline(__always)
	func prefix(count: Int) -> some Publisher<(Int, Element), Never> & Sendable {
		prefix(count).enumerated().publisher.map(\.self)
	}
}
extension Sequence where Element: Numeric {
	@inlinable @inline(__always)
	public var cumulative: some Sequence<Element> {
		sequence(state: (makeIterator(), Element.zero)) { state in
			state.0.next().map { element in
				defer { state.1 += element }
				return state.1
			}
		}
	}
}
