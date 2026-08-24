//
//  Convolvers+DFT.swift
//  MUTE
//
//  Created by Kota on 8/18/26.
//
import typealias Numerics.Complex128
import AltVec
extension Convolvers {
    public enum DFT: Sendable {
        case Fast
        case Accurate
        case Fixed(dft: ESP.DFT.DFS)
    }
}
extension Convolvers.DFT {
    @inlinable
    public init(fixed count: Int) {
        self = .Fixed(dft: .init(count: count))
    }
}
extension Convolvers.DFT: Convolvers.`Protocol` {
    @inlinable
    public func convolve(x: UnsafePointer<Float64>, count xc: Int,
                         y: UnsafePointer<Float64>, count yc: Int,
                         z: UnsafeMutablePointer<Float64>) {
        let count = xc + yc - 1
        let dft = switch self {
        case.Fast:
            DFT.DFS(count: 1 << (MemoryLayout<Int>.size * 8 - ( count - 1 ).leadingZeroBitCount))
        case.Accurate:
            DFT.DFS(count: count)
        case.Fixed(let dft) where dft.count < count:
            preconditionFailure()
        case.Fixed(let dft):
            dft
        }
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 4 * dft.count) {
            $0.initialize(repeating: .zero)
            let U = $0.baseAddress.unsafelyUnwrapped
            let V = U.advanced(by: dft.count)
            let S = V.advanced(by: dft.count)
            let T = S.advanced(by: dft.count)
            Float64.Copy(x: x, inc: 1, y: UnsafeMutablePointer<Float64>(.init(U)), inc: 2, length: xc)
            Float64.Copy(x: y, inc: 1, y: UnsafeMutablePointer<Float64>(.init(V)), inc: 2, length: yc)
            dft.forward(x: U, ld: dft.count, y: S, ld: dft.count, nrhs: 2)
            Complex128.Mul(x: S, inc: 1, y: T, inc: 1, z: S, inc: 1, length: dft.count)
            dft.inverse(x: S, inc: 1, y: U, inc: 1)
            Complex128.Copy(z: U, inc: 1, r: z, inc: 1, length: count)
        }
    }
}
