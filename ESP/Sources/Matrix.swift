//
//  Matrix.swift
//  MUTE
//
//  Created by Kota on 5/12/26.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Combine.Subscriber
import Dense
import func Layout.product
public protocol MatrixStream<Element>: Publisher where Output == (SIMD2<Int>, Element), Failure == Never {
    associatedtype Element: BitwiseCopyable & Sendable
}
extension MatBuf: MatrixStream, @retroactive Publisher where Element: BitwiseCopyable & Sendable {
    public func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, (SIMD2<Int>, Element) == S.Input {
        for (row, col) in product(0..<rows, 0..<cols) where subscriber.receive((SIMD2<Int>(row * ldr, col * ldc), self[row, col])) != .none {
            
        }
        subscriber.receive(completion: .finished)
    }
}
