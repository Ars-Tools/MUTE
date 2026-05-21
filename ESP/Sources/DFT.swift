//
//  DFT.swift
//  MUTE
//
//  Created by Kota on 11/4/25.
//
import Accelerate
import NSP
import Numerics
import Dense
public final class DFT {
    @usableFromInline
    let setup: UnsafePointer<ddft_t>
    public init(count: Int) {
        setup = .init(ddft_create(count))
    }
    deinit {
        ddft_destroy(.init(mutating: setup))
    }
}
extension DFT {
    public func forward(x: some AccelerateBuffer<Complex128>) -> Array<Complex128> {
        .init(unsafeUninitializedCapacity: x.count) {
            ddft_forward(setup,
                         .init(x.withUnsafeBufferPointer(\.baseAddress.unsafelyUnwrapped)),
                         .init($0.baseAddress.unsafelyUnwrapped))
            $1 = $0.count
        }
    }
    public func inverse(x: some AccelerateBuffer<Complex128>) -> Array<Complex128> {
        .init(unsafeUninitializedCapacity: x.count) {
            ddft_forward(setup,
                         .init(x.withUnsafeBufferPointer(\.baseAddress.unsafelyUnwrapped)),
                         .init($0.baseAddress.unsafelyUnwrapped))
            $1 = $0.count
        }
    }
}
extension DFT {
    @inlinable
    public func forward(x: some AccelerateBuffer<Complex128>, result y: inout some AccelerateMutableBuffer<Complex128>) {
        ddft_forward(setup,
                     .init(x.withUnsafeBufferPointer(\.baseAddress.unsafelyUnwrapped)),
                     .init(y.withUnsafeBufferPointer(\.baseAddress.unsafelyUnwrapped)))
    }
    public func forward(x: some AccelerateBuffer<Float64>, result y: inout some AccelerateMutableBuffer<Complex128>) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: x.count) {
            dcopy_(withUnsafePointer(to: x.count, \.self),
                   x.withUnsafeBufferPointer(\.baseAddress), withUnsafePointer(to: 1, \.self),
                   .init(.init($0.baseAddress.unsafelyUnwrapped)), withUnsafePointer(to: 2, \.self))
            vDSP_vclrD(.init(.init($0.baseAddress.unsafelyUnwrapped)), 2, .init(x.count))
            forward(x: $0, result: &y)
        }
    }
    public func forward(x: some AccelerateBuffer<Complex128>, result y: inout some AccelerateMutableBuffer<Float64>) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: x.count) {
            forward(x: x, result: &$0[0..<$0.count])
            dcopy_(withUnsafePointer(to: $0.count, \.self),
                   .init(.init($0.baseAddress.unsafelyUnwrapped)), withUnsafePointer(to: 2, \.self),
                   y.withUnsafeMutableBufferPointer(\.baseAddress.unsafelyUnwrapped), withUnsafePointer(to: 1, \.self))
        }
    }
}
extension DFT {
    @inlinable
    public func inverse(x: some AccelerateBuffer<Complex128>, result y: inout some AccelerateMutableBuffer<Complex128>) {
        ddft_inverse(setup,
                     .init(x.withUnsafeBufferPointer(\.baseAddress.unsafelyUnwrapped)),
                     .init(y.withUnsafeBufferPointer(\.baseAddress.unsafelyUnwrapped)))
    }
    public func inverse(x: some AccelerateBuffer<Float64>, result y: inout some AccelerateMutableBuffer<Complex128>) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: x.count) {
            dcopy_(withUnsafePointer(to: x.count, \.self),
                   x.withUnsafeBufferPointer(\.baseAddress), withUnsafePointer(to: 1, \.self),
                   .init(.init($0.baseAddress.unsafelyUnwrapped)), withUnsafePointer(to: 2, \.self))
            vDSP_vclrD(.init(.init($0.baseAddress.unsafelyUnwrapped)), 2, .init(x.count))
            inverse(x: $0, result: &y)
        }
    }
    public func inverse(x: some AccelerateBuffer<Complex128>, result y: inout some AccelerateMutableBuffer<Float64>) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: x.count) {
            inverse(x: x, result: &$0[0..<$0.count])
            dcopy_(withUnsafePointer(to: $0.count, \.self),
                   .init(.init($0.baseAddress.unsafelyUnwrapped)), withUnsafePointer(to: 2, \.self),
                   y.withUnsafeMutableBufferPointer(\.baseAddress.unsafelyUnwrapped), withUnsafePointer(to: 1, \.self))
        }
    }
}
