//
//  Extension+Publisher.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Publishers
extension Publisher {
    @inlinable@inline(__always)@_transparent
	package func`repeat`(count: Int) -> some Publisher<(Int, Output), Failure> & Sendable {
		flatMap {
			repeatElement($0, count: count).enumerated().publisher
		}.map(\.self)
	}
    @inlinable@inline(__always)
	package subscript<Key: Equatable, Value>(_ key: Key) -> some Publisher<Value, Failure> & Sendable where Output == (Key, Value) {
		compactMap {
			$0 == key ? .some($1) : .none
		}
	}
}
@inlinable@inline(__always)@_transparent
package func`repeat`<Output>(_ element: Output, count: Int) -> some Publisher<(Int, Output), Never> & Sendable {
	repeatElement(element, count: count).enumerated().publisher.map(\.self)
}
