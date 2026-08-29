//
//  Convolvers.swift
//  MUTE
//
//  Created by Kota on 8/6/26.
//
import Testing
import typealias Accelerate.vDSP
@testable import ESP
@Suite(.serialized)
struct ConvolverTestCases {
    func compare(a: some Convolvers.`Protocol`, b: some Convolvers.`Protocol`) {
        
    }
    @Test(
        arguments: [
            ([1, 2, 2, 2, 2, 2], [1, 0, 2]),
            ([1, 2, 2, 2, 2, 2], [1, 0, 2, 0, 3]),
        ]
    )
    func naïve(x: Array<Float64>, y: Array<Float64>) {
        let expect = Array<Float64>(unsafeUninitializedCapacity: x.count + y.count - 1) {
            vDSP.clear(&$0)
            let (signal, kernel) = x.count < y.count ? (y, x) : (x, y)
            for (offset, factor) in kernel.enumerated() {
                vDSP.add(multiplication: (signal, factor), $0[offset..<offset+signal.count], result: &$0[offset..<offset+signal.count])
            }
            $1 = $0.count
        }
        let convolver = Convolvers.Naïve
        let result = convolver.convolve(x: x, y: y)
        #expect(expect.count == result.count)
        #expect(zip(expect, result).map(-).map(\.magnitude).allSatisfy { $0.isLess(than: .ulpOfOne.squareRoot()) })
    }
    @Test(
        arguments: [
            ([1, 2, 2, 2, 2, 2], [1, 0, 2]),
            ([1, 2, 2, 2, 2, 2], [1, 0, 2, 0, 3]),
        ]
    )
    func dft(x: Array<Float64>, y: Array<Float64>) {
        let expect = Array<Float64>(unsafeUninitializedCapacity: x.count + y.count - 1) {
            vDSP.clear(&$0)
            let (signal, kernel) = x.count < y.count ? (y, x) : (x, y)
            for (offset, factor) in kernel.enumerated() {
                vDSP.add(multiplication: (signal, factor), $0[offset..<offset+signal.count], result: &$0[offset..<offset+signal.count])
            }
            $1 = $0.count
        }
        do {
            let convolver = .Fast as Convolvers.DFT
            let result = convolver.convolve(x: x, y: y)
            #expect(expect.count == result.count)
            #expect(zip(expect, result).map(-).map(\.magnitude).allSatisfy { $0.isLess(than: .ulpOfOne.squareRoot()) })
        }
        do {
            let convolver = .Just as Convolvers.DFT
            let result = convolver.convolve(x: x, y: y)
            #expect(expect.count == result.count)
            #expect(zip(expect, result).map(-).map(\.magnitude).allSatisfy { $0.isLess(than: .ulpOfOne.squareRoot()) })
        }
        do {
            let convolver = .init(count: 1024) as Convolvers.DFT
            let result = convolver.convolve(x: x, y: y)
            #expect(expect.count == result.count)
            #expect(zip(expect, result).map(-).map(\.magnitude).allSatisfy { $0.isLess(than: .ulpOfOne.squareRoot()) })
        }
    }
    @Test(
        arguments: repeatElement(2..<12, count: 10).map { (Int.random(in: $0), Int.random(in: $0)) }
    )
    func convolve(xlog2: Int, ylog2: Int) {
        let x = repeatElement(-1.0 ... 1.0, count: 1 << xlog2).map(Float64.random(in:))
        let y = repeatElement(-1.0 ... 1.0, count: 1 << ylog2).map(Float64.random(in:))
        let expect = Array<Float64>(unsafeUninitializedCapacity: x.count + y.count - 1) {
            vDSP.clear(&$0)
            let (signal, kernel) = x.count < y.count ? (y, x) : (x, y)
            for (offset, factor) in kernel.enumerated() {
                vDSP.add(multiplication: (signal, factor), $0[offset..<offset+signal.count], result: &$0[offset..<offset+signal.count])
            }
            $1 = $0.count
        }
        let result = Convolvers.convolve(x: x, y: y)
        #expect(expect.count == result.count)
        #expect(zip(expect, result).map(-).map(\.magnitude).allSatisfy { $0.isLess(than: .ulpOfOne.squareRoot()) })
    }
}
