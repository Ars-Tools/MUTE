//
//  Extensions+Array.swift
//  MUTE
//
//  Created by Kota on 5/14/R7.
//
extension Array {
	@inlinable @inline(__always)
	func withUnsafePointer<R, E: Swift.Error>(_ body: (UnsafePointer<Element>) throws (E) -> R) rethrows -> R {
		try body(self)
	}
	@inlinable @inline(__always)
	mutating func withUnsafeMutablePointer<R, E: Swift.Error>(_ body: (UnsafeMutablePointer<Element>) throws (E) -> R) rethrows -> R {
		try body(&self)
	}
}
