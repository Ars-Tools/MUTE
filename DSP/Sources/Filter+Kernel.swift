//
//  Filter+Kernel.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
import protocol Accelerate.AccelerateBuffer
public protocol Kernel<Element>: Sendable {
	associatedtype Element: BitwiseCopyable & Numeric
	associatedtype Kernel: AccelerateBuffer & Collection where Kernel.Element == Element
	func coefficients(for Tₛ: CMTime) -> Kernel
	var count: Int { get }
}
extension Array: Kernel where Element == Float64 {
	public func coefficients(for Tₛ: CMTime) -> Self {
		self
	}
}
extension ArraySlice: Kernel where Element == Float64 {
	public func coefficients(for Tₛ: CMTime) -> Self {
		self
	}
}
