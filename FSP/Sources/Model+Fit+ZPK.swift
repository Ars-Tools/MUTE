//
//  Model+Fit+ZPK.swift
//  MUTE
//
//  Created by Kota on 10/7/26.
//
import typealias Numerics.Complex128
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
extension Model {
    @inlinable@_transparent
    static func logsum(roots: Array<Complex128>,
                       frequency: some AccelerateBuffer<Float64>,
                       r: inout some AccelerateMutableBuffer<Float64>,
                       i: inout some AccelerateMutableBuffer<Float64>,
                       w: UnsafeMutableBufferPointer<Float64>/*workspace*/) {
        let N = frequency.count
        assert(8 * N <= w.count)
        let ηₛr = UnsafeMutableBufferPointer(rebasing: w[0*N..<1*N])
        let ηₛi = UnsafeMutableBufferPointer(rebasing: w[1*N..<2*N])
        let ηₜr = UnsafeMutableBufferPointer(rebasing: w[2*N..<3*N])
        let ηₜi = UnsafeMutableBufferPointer(rebasing: w[3*N..<4*N])
        let η₁r = UnsafeMutableBufferPointer(rebasing: w[4*N..<5*N])
        let η₁i = UnsafeMutableBufferPointer(rebasing: w[5*N..<6*N])
        let η₂r = UnsafeMutableBufferPointer(rebasing: w[6*N..<7*N])
        let η₂i = UnsafeMutableBufferPointer(rebasing: w[7*N..<8*N])
        vDSP.multiply(-2, frequency, result: &η₁i[0..<N])
        vForce.cosPi(η₁i, result: &η₁r[0..<N])
        vForce.sinPi(η₁i, result: &η₁i[0..<N])
        vDSP.multiply(-4, frequency, result: &η₂i[0..<N])
        vForce.cosPi(η₂i, result: &η₂r[0..<N])
        vForce.sinPi(η₂i, result: &η₂i[0..<N])
        for root in roots {
            let r₁ = -2 * root.real
            let r₂ = root.magnitudeSquared
            vDSP.add(multiplication: (η₁r, r₁),
                     multiplication: (η₂r, r₂),
                     result: &ηₜr[0..<N])
            vDSP.add(1, ηₜr[0..<N], result: &ηₜr[0..<N])
            vDSP.add(multiplication: (η₁i, r₁),
                     multiplication: (η₂i, r₂),
                     result: &ηₜi[0..<N])
            vDSP.add(multiplication: (ηₜr, ηₜr), multiplication: (ηₜi, ηₜi), result: &ηₛr[0..<N])
            vForce.log(ηₛr, result: &ηₛr[0..<N])
            vDSP.multiply(0.5, ηₛr, result: &ηₛr[0..<N])
            vDSP.add(r, ηₛr, result: &r)
            vForce.atan2(x: ηₜr, y: ηₜi, result: &ηₛi[0..<N])
            vDSP.add(i, ηₛi, result: &i)
        }
    }
    @inlinable@_transparent
    static func logsum(roots: Array<Float64>,
                       frequency: some AccelerateBuffer<Float64>,
                       r: inout some AccelerateMutableBuffer<Float64>,
                       i: inout some AccelerateMutableBuffer<Float64>,
                       w: UnsafeMutableBufferPointer<Float64>/*workspace*/) {
        let N = frequency.count
        assert(6 * N <= w.count)
        let ηₛr = UnsafeMutableBufferPointer(rebasing: w[0*N..<1*N])
        let ηₛi = UnsafeMutableBufferPointer(rebasing: w[1*N..<2*N])
        let ηₜr = UnsafeMutableBufferPointer(rebasing: w[2*N..<3*N])
        let ηₜi = UnsafeMutableBufferPointer(rebasing: w[3*N..<4*N])
        let η₁r = UnsafeMutableBufferPointer(rebasing: w[4*N..<5*N])
        let η₁i = UnsafeMutableBufferPointer(rebasing: w[5*N..<6*N])
        vDSP.multiply(-2, frequency, result: &η₁i[0..<N])
        vForce.cosPi(η₁i, result: &η₁r[0..<N])
        vForce.sinPi(η₁i, result: &η₁i[0..<N])
        for root in roots {
            let r₁ = -root
            vDSP.add(multiplication: (η₁r, r₁), 1, result: &ηₛr[0..<N])
            vDSP.multiply(r₁, η₁i, result: &ηₛi[0..<N])
            vDSP.add(multiplication: (ηₛr, ηₛr), multiplication: (ηₛi, ηₛi), result: &ηₜr[0..<N])
            vForce.log(ηₜr, result: &ηₜr[0..<N])
            vDSP.multiply(0.5, ηₜr, result: &ηₜr[0..<N])
            vDSP.add(r, ηₜr, result: &r)
            vForce.atan2(x: ηₛr, y: ηₛi, result: &ηₜi[0..<N])
            vDSP.add(i, ηₜi, result: &i)
        }
    }
    @inlinable
    public static func fit(x: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
                           y: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
                           frequency: some AccelerateBuffer<Float64>,
                           initial: ZPK,
                           regularization: borrowing (ZPK) -> some AccelerateBuffer<Float64>) {
        let N = frequency.count
        var result = initial
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: 12 * N) {
            let Xr = UnsafeMutableBufferPointer(rebasing: $0[0*N..<1*N]) // accum
            let Xi = UnsafeMutableBufferPointer(rebasing: $0[1*N..<2*N])
            let Yr = UnsafeMutableBufferPointer(rebasing: $0[2*N..<3*N])
            let Yi = UnsafeMutableBufferPointer(rebasing: $0[3*N..<4*N])
            let Zr = UnsafeMutableBufferPointer(rebasing: $0[4*N..<5*N]) // table
            let Zi = UnsafeMutableBufferPointer(rebasing: $0[5*N..<6*N])
            let Wr = UnsafeMutableBufferPointer(rebasing: $0[6*N..<7*N]) // workspace
            let Wi = UnsafeMutableBufferPointer(rebasing: $0[7*N..<8*N])
            vDSP.clear(&Xr[0..<N])
            vDSP.clear(&Xi[0..<N])
            vDSP.clear(&Yr[0..<N])
            vDSP.clear(&Yi[0..<N])
            logsum(roots: result.z.0, frequency: frequency, r: &Xr[0..<N], i: &Xi[0..<N], w: .init(rebasing: $0.dropFirst(4 * N)))
            logsum(roots: result.z.1, frequency: frequency, r: &Xr[0..<N], i: &Xi[0..<N], w: .init(rebasing: $0.dropFirst(4 * N)))
            logsum(roots: result.p.0, frequency: frequency, r: &Yr[0..<N], i: &Yi[0..<N], w: .init(rebasing: $0.dropFirst(4 * N)))
            logsum(roots: result.p.1, frequency: frequency, r: &Yr[0..<N], i: &Yi[0..<N], w: .init(rebasing: $0.dropFirst(4 * N)))
            vForce.exp(Xr, result: &Wr[0..<N])
            vForce.sincos(Xi, sinResult: &Xi[0..<N], cosResult: &Xr[0..<N])
            vDSP.multiply(Wr, Xr, result: &Xr[0..<N])
            vDSP.multiply(Wr, Xi, result: &Xi[0..<N])
            vForce.exp(Yr, result: &Wr[0..<N])
            vForce.sincos(Yi, sinResult: &Yi[0..<N], cosResult: &Yr[0..<N])
            vDSP.multiply(Wr, Yr, result: &Yr[0..<N])
            vDSP.multiply(Wr, Yi, result: &Yi[0..<N])
        }
        assertionFailure("WIP")
    }
}
