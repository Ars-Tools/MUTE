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
import FSP
import Dense
import Accelerate
@Suite
struct IR {
    @Test
    func prepare() throws {
        try _ = Buffer.Import(from: .init(filePath: "/tmp/9f-3.aiff"), backing: "/tmp/backing.raw")
    }
    @Test
    func sos() throws {
        let r = try Buffer(raw: "/tmp/backing.raw", stream: 1)
        let R = try Buffer(stream: 1, period: r.period, backing: "/tmp/X.raw", release: false)
        do {
            let dft = DFT(count: 1152000)
            let x = UnsafeBufferPointer(start: r.start, count: r.period).map(Complex128.init(floatLiteral:))
            let X = dft.forward(x: x)
            Complex128.mags(X, 1,
                            R.start, 1,
                            r.period)
            vvsqrt(R.start, R.start, withUnsafePointer(to: Int32(R.period), \.self))
        }
        let mag = minimum(mag: UnsafeBufferPointer(start: R.start, count: R.period / 2))
        let sos = FSP.fit(response: mag, with: 32)
        print(sos.map { ($1.x, $1.y, $1.z, $0.x, $0.y, $0.z) })
    
    }
    @Test
    func fit() throws {
        let r = try Buffer(raw: "/tmp/backing.raw", stream: 1)
        let R = try Buffer(stream: 1, period: r.period, backing: "/tmp/X.raw", release: false)
        do {
            let dft = DFT(count: 1152000)
            let x = UnsafeBufferPointer(start: r.start, count: r.period).map(Complex128.init(floatLiteral:))
            let X = dft.forward(x: x)
            Complex128.mags(X, 1,
                            R.start, 1,
                            r.period)
            vvsqrt(R.start, R.start, withUnsafePointer(to: Int32(R.period), \.self))
        }
        //
        let M = UnsafeBufferPointer(start: R.start, count: R.period / 2)
        let F = vDSP.ramp(in: 0...Float64(24000), count: M.count)
        let s = ESP.lnslope(frequency: F, magnitude: M, bandwidth: 100 ... 8000)
        
        let S = try Buffer(stream: 1, period: M.count, backing: "/tmp/S.raw", release: false)
        UnsafeMutableBufferPointer(start: S.start, count: S.period).update(fromContentsOf: s)
        
        let d = try Buffer(stream: 1, period: M.count, backing: "/tmp/D.raw", release: false)
        let D = vDSP.subtract(vForce.log(M), UnsafeBufferPointer(start: S.start, count: S.period))
        UnsafeMutableBufferPointer(start: d.start, count: d.period).update(fromContentsOf: D)
        
        let idx = F.enumerated().compactMap { (100.0 ... 8000.0).contains($1) ? UInt(exactly: $0 + 1) : .none }
        let p = FSP.peq(frequency: vDSP.gather(F, indices: idx).map { $0 / 24000.0 },
                        magnitude: vForce.exp(vDSP.gather(D, indices: idx)),
                        initial: (logspace(in: (100 / 24000.0) ... (8000 / 24000.0), count: 32), 0.5),
                        update: (1e-6, 1e-6, 1e-5, 1e-6),
                        epoch: (1000, 1000)) {
            print($0, $1[0].contents().load(as: Float32.self))
        }
        
        print(p.map { ($0, $1, $2) })
        
        
    }
}
