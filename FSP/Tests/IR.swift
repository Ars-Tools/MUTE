//
//  IR.swift
//  MUTE
//
//  Created by Kota on 11/4/25.
//
import Testing
import Numerics
import DSP
import ESP
import BSP
import Dense
import Accelerate
@Suite
struct IR {
    @Test
    func fit() throws {
        let dft = DFT(count: 1152000)
        let r = try Buffer(raw: "/tmp/backing.raw", stream: 1)
        let R = try Buffer(stream: 1, period: r.period, backing: "/tmp/X.raw", release: false)
        let x = UnsafeBufferPointer(start: r.start, count: r.period).map(Complex128.init(floatLiteral:))
        let X = dft.forward(x: x)
        Complex128.mags(X, 1,
                        R.start, 1,
                        r.period)
        vvsqrt(R.start, R.start, withUnsafePointer(to: Int32(R.period), \.self))
        //
        let M = UnsafeBufferPointer(start: R.start, count: R.period / 2)
        let L = vForce.log(M)
        let F = vDSP.ramp(in: 0...Float64(24000), count: M.count)
        let s = lnslope(frequency: F, magnitude: M, bandwidth: 100 ... 8000)
        
        let S = try Buffer(stream: 1, period: M.count, backing: "/tmp/S.raw", release: false)
        UnsafeMutableBufferPointer(start: S.start, count: S.period).update(fromContentsOf: s)
        
        let d = try Buffer(stream: 1, period: M.count, backing: "/tmp/D.raw", release: false)
        let D = vDSP.subtract(L, UnsafeBufferPointer(start: S.start, count: S.period))
        UnsafeMutableBufferPointer(start: d.start, count: d.period).update(fromContentsOf: D)
        
        
        
    }
}
