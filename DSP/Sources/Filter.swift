//
//  Filter.swift
//  MUTE
//
//  Created by Kota on 9/24/26.
//
@preconcurrency import protocol Accelerate.AccelerateBuffer
public enum Filter {
    public protocol TransferFunction<Element>: Sendable {
        associatedtype Element: Numeric
        associatedtype B: AccelerateBuffer<Element> & RandomAccessCollection<Element> where B.Index == Int
        associatedtype A: AccelerateBuffer<Element> & RandomAccessCollection<Element> where A.Index == Int
        @inlinable func coefficients(for Tₛ: CMTime) -> (b: B, a: A)
        @inlinable var counts: SIMD2<Int> { get }
    }
}
extension CollectionOfOne: @retroactive AccelerateBuffer {
    public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R {
        try span.withUnsafeBufferPointer(body)
    }
}
extension Filter {
    public protocol Kernel<Element>: TransferFunction where A == CollectionOfOne<Element> {
        @inlinable func coefficients(for Tₛ: CMTime) -> B
        var count: Int { get }
    }
}
extension Filter.Kernel {
    @inlinable
    public func coefficients(for Tₛ: CMTime) -> (b: B, a: A) {
        (b: coefficients(for: Tₛ), .init(1))
    }
    @inlinable
    public var counts: SIMD2<Int> {
        .init(count, 1)
    }
}
extension Array: Filter.TransferFunction & Filter.Kernel where Element: Numeric {
    public typealias B = Self
    public typealias A = CollectionOfOne<Element>
    @inlinable
    public func coefficients(for Tₛ: CMTime) -> Self {
        self
    }
}
extension ArraySlice: Filter.TransferFunction & Filter.Kernel where Element: Numeric {
    public typealias B = Self
    public typealias A = CollectionOfOne<Element>
    @inlinable
    public func coefficients(for Tₛ: CMTime) -> Self {
        self
    }
}
