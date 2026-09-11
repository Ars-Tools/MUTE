//
//  DFT+DFS.swift
//  MUTE
//
//  Created by Kota on 8/24/26.
//
import typealias Synchronization.Mutex
import typealias Numerics.Complex128
import typealias NSP.ddft_t
import func NSP.ddft_create
import func NSP.dft_destroy
import func NSP.dft_count
import func NSP.dft_forward
import func NSP.dft_inverse
extension DFT {
    public final class DFS: @unchecked Sendable {
        @usableFromInline
        let setup: UnsafePointer<ddft_t>
        @inlinable
        public init(count: Int) {
            setup = ddft_create(count)
        }
        @inlinable
        public init(dense: Int) {
            setup = ddft_create([dense, 1])
        }
        @inlinable
        deinit {
            dft_destroy(setup)
        }
    }
}
extension DFT.DFS: DFT.`Protocol` {
    @inlinable@_transparent
    public var count: Int {
        dft_count(setup)
    }
    @inlinable
    public func forward(x: UnsafePointer<Complex128>, inc incx: Int,
                        y: UnsafeMutablePointer<Complex128>, inc incy: Int) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: count) {
            dft_forward(setup, .DFT_SCALE_ONE,
                        .init(x), incx,
                        .init(y), incy,
                        .init($0.baseAddress))
        }
    }
    @inlinable
    public func inverse(x: UnsafePointer<Complex128>, inc incx: Int,
                        y: UnsafeMutablePointer<Complex128>, inc incy: Int) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: count) {
            dft_inverse(setup, .DFT_SCALE_ONE_OVER_N,
                        .init(x), incx,
                        .init(y), incy,
                        .init($0.baseAddress))
        }
    }
    @inlinable
    public func forward(x: UnsafePointer<Complex128>, ld ldx: Int,
                        y: UnsafeMutablePointer<Complex128>, ld ldy: Int,
                        nrhs: Int) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: count * 2) {
            dft_forward(setup, .DFT_SCALE_ONE, nrhs,
                        .init(x), ldx,
                        .init(y), ldy,
                        .init($0.baseAddress))
        }
    }
    @inlinable
    public func inverse(x: UnsafePointer<Complex128>, ld ldx: Int,
                        y: UnsafeMutablePointer<Complex128>, ld ldy: Int,
                        nrhs: Int) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: count * 2) {
            dft_inverse(setup, .DFT_SCALE_ONE_OVER_N, nrhs,
                        .init(x), ldx,
                        .init(y), ldy,
                        .init($0.baseAddress))
        }
    }
}
// MARK: Shared Instance
extension Mutex where Value == Dictionary<Int, DFT.DFS> {
    @inlinable
    public subscript(_ count: Int) -> Value.Value {
        withLock {
            switch $0[count] {
            case.some(let dft):
                dft
            case.none:
                switch Value.Value(count: count) {
                case let dft:
                    $0.updateValue(dft, forKey: count) ?? dft
                }
            }
        }
    }
    @inlinable
    public func flush() {
        withLock {
            $0.removeAll()
        }
    }
}
extension DFT.DFS {
    public static let shared: Mutex<Dictionary<Int, DFT.BFS>> = .init(.init())
}
