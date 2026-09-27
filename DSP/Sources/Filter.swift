//
//  Filter.swift
//  MUTE
//
//  Created by Kota on 9/24/26.
//
@preconcurrency import protocol Accelerate.AccelerateBuffer
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Publishers
@preconcurrency import typealias Combine.Just
public enum Filter {
    public protocol TransferFunction<Scalar>: Sendable {
        associatedtype Scalar: Numeric
        associatedtype A: AccelerateBuffer<Scalar> & RandomAccessCollection<Scalar> where A.Index == Int
        associatedtype B: AccelerateBuffer<Scalar> & RandomAccessCollection<Scalar> where B.Index == Int
        associatedtype Coefficients: Publisher<(b: B, a: A), Never> & Sendable
        @inlinable func coefficients(for Tₛ: CMTime) -> Coefficients
        @inlinable var counts: SIMD2<Int> { get }
    }
}
extension CollectionOfOne: @retroactive AccelerateBuffer {
    public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R {
        try span.withUnsafeBufferPointer(body)
    }
}
extension Filter {
    public protocol Kernel<Scalar>: TransferFunction where A == CollectionOfOne<Scalar> {
        associatedtype Coefficient: Publisher<B, Never> & Sendable
        @inlinable func coefficient(for Tₛ: CMTime) -> Coefficient
        var count: Int { get }
    }
}
extension Filter.Kernel {
    @inlinable
    public func coefficients(for Tₛ: CMTime) -> Publishers.Map<Coefficient, (b: B, a: A)> {
        coefficient(for: Tₛ).map {
            (b: $0, a: CollectionOfOne<Scalar>(1))
        }
    }
    @inlinable
    public var counts: SIMD2<Int> {
        .init(count, 1)
    }
}
extension Array: Filter.TransferFunction & Filter.Kernel where Element: Numeric {
    public typealias Coefficient = Just<B>
    public typealias Scalar = Element
    public typealias B = Array<Scalar>
    @inlinable
    public func coefficient(for Tₛ: CMTime) -> Coefficient {
        Just(self)
    }
}
extension ArraySlice: Filter.TransferFunction & Filter.Kernel where Element: Numeric {
    public typealias Coefficient = Just<B>
    public typealias Scalar = Element
    public typealias B = ArraySlice<Scalar>
    @inlinable
    public func coefficient(for Tₛ: CMTime) -> Coefficient {
        Just(self)
    }
}
