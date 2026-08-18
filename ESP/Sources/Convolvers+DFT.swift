//
//  Convolvers+DFT.swift
//  MUTE
//
//  Created by Kota on 8/18/26.
//
import Dense
import NSP
extension Convolvers {
    public enum DFT: Sendable {
        case PWT(dft: ESP.DFT.PWT)
        case BFS(dft: ESP.DFT.BFS)
    }
    public final class DFT2: @unchecked Sendable {
        @usableFromInline
        let setup: UnsafePointer<bdft_t>
        init(width count: Int) {
            setup = .init(bdft_create(count))
        }
        deinit {
            dft_destroy(setup)
        }
    }
}
extension Convolvers.DFT {
    public init(count: Int) {
        self = (
            try?count.nonzeroBitCount == 1 ? .PWT(dft: .init(count: count)) : .none
        ) ?? .BFS(dft: .init(count: count))
    }
}
extension Convolvers.DFT: Convolvers.`Protocol` {
    @inlinable
    public func convolve(x: UnsafePointer<Float64>, count xc: Int,
                         y: UnsafePointer<Float64>, count yc: Int,
                         z: UnsafeMutablePointer<Float64>) {
        switch self {
        case.PWT(let dft):
            let count = dft.count
            withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count) {
                $0.initialize(repeating: .zero)
                let X = $0.baseAddress.unsafelyUnwrapped
                let Y = X.advanced(by: count)
                Float64.Copy(x: x, inc: 1, y: UnsafeMutablePointer<Float64>(.init(X)), inc: 2, length: xc)
                Float64.Copy(x: y, inc: 1, y: UnsafeMutablePointer<Float64>(.init(Y)), inc: 2, length: yc)
                dft.forward(x: X, ld: count, y: X, ld: count, nrhs: 2)
                Complex128.Mul(x: X, inc: 1, y: Y, inc: 1, z: X, inc: 1, length: count)
                dft.inverse(x: X, inc: 1, y: X, inc: 1)
                Complex128.Copy(z: X, inc: 1, r: z, inc: 1, length: xc + yc - 1)
            }
        case.BFS(let dft):
            let count = dft.count
            withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count) {
                $0.initialize(repeating: .zero)
                let X = $0.baseAddress.unsafelyUnwrapped
                let Y = X.advanced(by: count)
                Float64.Copy(x: x, inc: 1, y: UnsafeMutablePointer<Float64>(.init(X)), inc: 2, length: xc)
                Float64.Copy(x: y, inc: 1, y: UnsafeMutablePointer<Float64>(.init(Y)), inc: 2, length: yc)
                dft.forward(x: X, ld: count, y: X, ld: count, nrhs: 2)
                Complex128.Mul(x: X, inc: 1, y: Y, inc: 1, z: X, inc: 1, length: count)
                dft.inverse(x: X, inc: 1, y: X, inc: 1)
                Complex128.Copy(z: X, inc: 1, r: z, inc: 1, length: xc + yc - 1)
            }
        }
    }
}
