//
//  DFT+AMX.swift
//  MUTE
//
//  Created by Kota on 8/18/26.
//
import typealias Synchronization.Mutex
import typealias Numerics.Complex128
import typealias KSP.pdft_t
import func KSP.pdft_create
import func KSP.dft_destroy
import func KSP.dft_count
import func KSP.dft_forward
import func KSP.dft_inverse
extension DFT {
    public protocol Container<Value> {
        associatedtype Value: DFT.`Protocol`
        @inlinable
        subscript(_: Int) -> Optional<Value> { get }
        @inlinable
        mutating func updateValue(_: Value, forKey: Int) -> Optional<Value>
        @inlinable
        mutating func removeAll(keepingCapacity: Bool)
    }
}
extension Dictionary: DFT.Container<Value> where Key == Int, Value: DFT.`Protocol` {}
extension Mutex where Value: DFT.Container {
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
            $0.removeAll(keepingCapacity: false)
        }
    }
}
// MARK: Shared Instance
extension DFT.BFS {
    public static let shared: Mutex<Dictionary<Int, DFT.BFS>> = .init(.init())
}
extension DFT.DFS {
    public static let shared: Mutex<Dictionary<Int, DFT.DFS>> = .init(.init())
}
extension DFT {
    public final class PWT: @unchecked Sendable {
        @usableFromInline
        let setup: UnsafePointer<pdft_t>
        @inlinable
        public init(count: Int) throws (Error) {
            precondition(count.nonzeroBitCount == 1, "Power-of-Two DFT supports only 2ⁿ length")
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
extension DFT.PWT {
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
extension DFT.PWT {
    @inlinable
    public func forward(xr: UnsafePointer<Float64>, xi: UnsafePointer<Float64>, inc incx: Int = 1,
                        yr: UnsafeMutablePointer<Float64>, yi: UnsafeMutablePointer<Float64>, inc incy: Int = 1) {
        dft_forward(setup, .DFT_SCALE_ONE,
                    xr, xi, incx,
                    yr, yi, incy,
                    .none)
    }
    @inlinable
    public func inverse(xr: UnsafePointer<Float64>, xi: UnsafePointer<Float64>, inc incx: Int = 1,
                        yr: UnsafeMutablePointer<Float64>, yi: UnsafeMutablePointer<Float64>, inc incy: Int = 1) {
        dft_inverse(setup, .DFT_SCALE_ONE_OVER_N,
                    xr, xi, incx,
                    yr, yi, incy,
                    .none)
    }
    @inlinable
    public func forward(xr: UnsafePointer<Float64>, xi: UnsafePointer<Float64>, ld ldx: Int,
                        yr: UnsafeMutablePointer<Float64>, yi: UnsafeMutablePointer<Float64>, ld ldy: Int,
                        nrhs: Int) {
        dft_forward(setup, .DFT_SCALE_ONE, nrhs,
                    xr, xi, ldx,
                    yr, yi, ldy,
                    .none)
    }
    @inlinable
    public func inverse(xr: UnsafePointer<Float64>, xi: UnsafePointer<Float64>, ld ldx: Int,
                        yr: UnsafeMutablePointer<Float64>, yi: UnsafeMutablePointer<Float64>, ld ldy: Int,
                        nrhs: Int) {
        dft_inverse(setup, .DFT_SCALE_ONE_OVER_N, nrhs,
                    xr, xi, ldx,
                    yr, yi, ldy,
                    .none)
    }
}
