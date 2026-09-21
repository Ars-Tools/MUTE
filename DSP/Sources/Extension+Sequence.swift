//
//  Extension+Sequence.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Publishers
import func Layout.concat
extension Sequence {
    @inlinable@_transparent
	func roll(head count: Int) -> some Sequence<Element> {
		concat(dropFirst(count), prefix(count))
	}
    @inlinable@_transparent
	func roll(tail count: Int) -> some Sequence<Element> {
		concat(suffix(count), dropLast(count))
	}
    @inlinable@_transparent
	func prefix(count: Int) -> some Publisher<(Int, Element), Never> & Sendable {
		prefix(count).enumerated().publisher.map(\.self)
	}
}
extension Sequence where Element: Numeric {
    @inlinable@_transparent
	public var cumulative: some Sequence<Element> {
		sequence(state: (makeIterator(), Element.zero)) { state in
			state.0.next().map { element in
				defer { state.1 += element }
				return state.1
			}
		}
	}
}
extension Sequence where Element: BinaryInteger {
    @inlinable@_transparent
    public var cumulatedRanges: some Sequence<Range<Element>> {
        sequence(state: (makeIterator(), Element.zero)) { state in
            state.0.next().map { element in
                defer { state.1 += element }
                return state.1..<state.1 + element
            }
        }
    }
}
