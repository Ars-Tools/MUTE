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
    let sample: Float64
    let buffer: DSP.Buffer
    init() throws {
        (sample, buffer) = try Buffer.Import(from: .init(filePath: "/tmp/9f-3.aiff"), backing: "/tmp/backing.raw")
    }
    @Test
    func sos() throws {
        let r = try Buffer(raw: "/tmp/backing.raw", stream: 1)
        let R = try Buffer(stream: 1, period: r.period, backing: "/tmp/X.raw", release: false)
        do {
            let dft = DFT.BFS(count: 1152000)
            let x = UnsafeBufferPointer(start: r.start, count: r.period).map(Complex128.init(floatLiteral:))
            let X = dft.forward(x)
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
            let dft = DFT.BFS(count: 1152000)
            let x = UnsafeBufferPointer(start: r.start, count: r.period).map(Complex128.init(floatLiteral:))
            let X = dft.forward(x)
            Complex128.mags(X, 1,
                            R.start, 1,
                            r.period)
            vvsqrt(R.start, R.start, withUnsafePointer(to: Int32(R.period), \.self))
        }
        //
        
    }
}
