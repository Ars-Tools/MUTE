//
//  Extension+Array.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
extension Array {
	@inlinable @inline(__always)
	func withUnsafePointer<R, E>(_ body: (UnsafePointer<Element>) throws (E) -> R) rethrows -> R {
		try body(self)
	}
	@inlinable @inline(__always)
	mutating func withUnsafeMutablePointer<R, E>(_ body: (UnsafeMutablePointer<Element>) throws (E) -> R) rethrows -> R {
		try body(&self)
	}
}
