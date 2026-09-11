//
//  DFT+BFS.swift
//  MUTE
//
//  Created by Kota on 8/18/26.
//
import typealias Synchronization.Mutex
import typealias Numerics.Complex128
import typealias NSP.bdft_t
import func NSP.bdft_create
import func NSP.dft_destroy
import func NSP.dft_count
import func NSP.dft_forward
import func NSP.dft_inverse
extension DFT {
    public final class BFS: @unchecked Sendable {
        @usableFromInline
        let setup: UnsafePointer<bdft_t>
        @inlinable
        public init(count: Int) {
            setup = bdft_create(count)
        }
        @inlinable
        deinit {
            dft_destroy(setup)
        }
    }
}
extension DFT.BFS: DFT.`Protocol` {
    @inlinable@_transparent
    public var count: Int {
        dft_count(setup)
    }
    @inlinable
    public func forward(x: UnsafePointer<Complex128>, inc incx: Int,
                        y: UnsafeMutablePointer<Complex128>, inc incy: Int) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count) {
            dft_forward(setup, .DFT_SCALE_ONE,
                        .init(x), incx,
                        .init(y), incy,
                        .init($0.baseAddress))
        }
    }
    @inlinable
    public func inverse(x: UnsafePointer<Complex128>, inc incx: Int,
                        y: UnsafeMutablePointer<Complex128>, inc incy: Int) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count) {
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
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count * nrhs) {
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
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count * nrhs) {
            dft_inverse(setup, .DFT_SCALE_ONE_OVER_N, nrhs,
                        .init(x), ldx,
                        .init(y), ldy,
                        .init($0.baseAddress))
        }
    }
}
// MARK: Shared Instance
extension Mutex where Value == Dictionary<Int, DFT.BFS> {
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
extension DFT.BFS {
    public static let shared: Mutex<Dictionary<Int, DFT.BFS>> = .init(.init())
}
