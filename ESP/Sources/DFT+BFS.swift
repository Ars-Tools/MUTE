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
    public final class BFS: DFT.`Protocol`, @unchecked Sendable {
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
extension DFT.BFS {
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
extension DFT.BFS {
    @inlinable
    public func forward(xr: UnsafePointer<Float64>, xi: UnsafePointer<Float64>, inc incx: Int = 1,
                        yr: UnsafeMutablePointer<Float64>, yi: UnsafeMutablePointer<Float64>, inc incy: Int = 1) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count) {
            dft_forward(setup, .DFT_SCALE_ONE,
                        xr, xi, incx,
                        yr, yi, incy,
                        .init($0.baseAddress))
        }
    }
    @inlinable
    public func inverse(xr: UnsafePointer<Float64>, xi: UnsafePointer<Float64>, inc incx: Int = 1,
                        yr: UnsafeMutablePointer<Float64>, yi: UnsafeMutablePointer<Float64>, inc incy: Int = 1) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count) {
            dft_inverse(setup, .DFT_SCALE_ONE_OVER_N,
                        xr, xi, incx,
                        yr, yi, incy,
                        .init($0.baseAddress))
        }
    }
    @inlinable
    public func forward(xr: UnsafePointer<Float64>, xi: UnsafePointer<Float64>, ld ldx: Int,
                        yr: UnsafeMutablePointer<Float64>, yi: UnsafeMutablePointer<Float64>, ld ldy: Int,
                        nrhs: Int) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count * nrhs) {
            dft_forward(setup, .DFT_SCALE_ONE, nrhs,
                        xr, xi, ldx,
                        yr, yi, ldy,
                        .init($0.baseAddress))
        }
    }
    @inlinable
    public func inverse(xr: UnsafePointer<Float64>, xi: UnsafePointer<Float64>, ld ldx: Int,
                        yr: UnsafeMutablePointer<Float64>, yi: UnsafeMutablePointer<Float64>, ld ldy: Int,
                        nrhs: Int) {
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count * nrhs) {
            dft_inverse(setup, .DFT_SCALE_ONE_OVER_N, nrhs,
                        xr, xi, ldx,
                        yr, yi, ldy,
                        .init($0.baseAddress))
        }
    }
}
