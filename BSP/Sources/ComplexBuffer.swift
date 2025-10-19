//
//  ComplexBuffer.swift
//  MUTE
//
//  Created by Kota on 10/9/25.
//
import typealias Accelerate.vDSP
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMatrixBuffer
import typealias Accelerate.AccelerateMatrixOrder
import Auxiliary
import typealias Numerics.Complex128
public struct ComplexBuffer: Sendable {
    public let stream: Int
    public let period: Int
    @usableFromInline let memory: Autorelease.Memory
    @usableFromInline let offset: Int
}
extension ComplexBuffer {
    @inlinable
    public init(stream rows: Int, period cols: Int) {
        stream = rows
        period = cols
        memory = .init(repeating: .zero as Complex128, count: stream * period)
        offset = 0
    }
}
