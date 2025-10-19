//
//  Extensions.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
@_exported @preconcurrency import protocol Combine.Publisher
extension Publisher {
	@_disfavoredOverload
	@inlinable
	func`repeat`(count: Int) -> some Publisher<(Int, Output), Failure> & Sendable {
		flatMap { repeatElement($0, count: count).enumerated().publisher }.map(\.self)
	}
}
extension Sequence {
	@_disfavoredOverload
	@inlinable
	func prefix(count: Int) -> some Publisher<(Int, Element), Never> & Sendable {
		enumerated().publisher.map(\.self)
	}
}
@_disfavoredOverload
@inlinable
func`repeat`<T>(_ element: T, count: Int) -> some Publisher<(Int, T), Never> & Sendable {
	repeatElement(element, count: count).enumerated().publisher.map(\.self)
}
