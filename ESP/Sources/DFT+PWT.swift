//
//  DFT+AMX.swift
//  MUTE
//
//  Created by Kota on 8/18/26.
//
import typealias Numerics.Complex128
import NSP
extension DFT {
    public final class PWT: @unchecked Sendable {
        @usableFromInline
        let setup: UnsafePointer<pdft_t>
        @inlinable
        public init(count: Int) throws (Error) {
            precondition(count.nonzeroBitCount == 1, "Power of Two supports only 2ⁿ")
            setup = switch pdft_create(count) {
            case.some(let table):
                table
            case.none:
                throw Error.internal
            }
        }
        @inlinable
        deinit {
            dft_destroy(setup)
        }
    }
}
extension DFT.PWT {
    public enum Error: Swift.Error {
        case `internal`
    }
}
extension DFT.PWT: DFT.`Protocol` {
    @inlinable@_transparent
    public var count: Int {
        dft_count(setup)
    }
    @inlinable
    public func forward(x: UnsafePointer<Complex128>, inc incx: Int,
                        y: UnsafeMutablePointer<Complex128>, inc incy: Int) {
        dft_forward(setup, .DFT_SCALE_ONE,
                    .init(x), incx,
                    .init(y), incy,
                    .none)
    }
    @inlinable
    public func inverse(x: UnsafePointer<Complex128>, inc incx: Int,
                        y: UnsafeMutablePointer<Complex128>, inc incy: Int) {
        dft_inverse(setup, .DFT_SCALE_ONE_OVER_N,
                    .init(x), incx,
                    .init(y), incy,
                    .none)
    }
    @inlinable
    public func forward(x: UnsafePointer<Complex128>, ld ldx: Int,
                        y: UnsafeMutablePointer<Complex128>, ld ldy: Int,
                        nrhs: Int) {
        dft_forward(setup, .DFT_SCALE_ONE, nrhs,
                    .init(x), ldx,
                    .init(y), ldy,
                    .none)
    }
    @inlinable
    public func inverse(x: UnsafePointer<Complex128>, ld ldx: Int,
                        y: UnsafeMutablePointer<Complex128>, ld ldy: Int,
                        nrhs: Int) {
        dft_inverse(setup, .DFT_SCALE_ONE_OVER_N, nrhs,
                    .init(x), ldx,
                    .init(y), ldy,
                    .none)
    }
}
