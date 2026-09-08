//
//  Linear+Fit.swift
//  MUTE
//
//  Created by Kota on 9/7/26.
//
import Testing
@testable import FSP
import typealias Accelerate.vDSP
import typealias Numerics.Complex128
import Testing
import ESP
import DSP
import NSP
import MKL
import AltVec
@Suite(.serialized)
struct LinearFitTestCases {
    @inlinable
    static func Uniform(count: Int, in range: ClosedRange<Float64> = -1...1, padding space: Int = 0) -> Array<Float64> {
        repeatElement(range, count: count).map(Float64.random(in:)) + Array(repeating: .zero, count: space)
    }
    @inlinable
    static func Impulse(count: Int) -> Array<Float64> {
        .init(unsafeUninitializedCapacity: count) {
            $1 = $0.count
            $0[0] = 1
            $0[1...].initialize(repeating: .zero)
        }
    }
    @Test(
        arguments: [Impulse(count: 256)]
    )
    func mag(signal: Array<Float64>) {
        var s = SIMD4<Float64>()
        var y = signal
        let power = vDSP.sumOfSquares(y)
        vDSP.divide(y, power.squareRoot(), result: &y)
        let filter = Linear.Biquad.PEQ(ω₀: 1.0/8.0, Q: 6.0.squareRoot(), dB: 12)
        biquad_filter_convolve_static(filter.b, filter.a, y, &y, &s, y.count)
        let dft = DFT.DFS(count: y.count)
        let Y = y.withUnsafeTemporaryComplexBuffer(dft.forward)
        let minY = Hilbert.Transformer(dft: dft).MinimumPhase(response: Y.map(\.magnitude))
        let fit = Linear.Fit(frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(y.count)), count: y.count),
                             response: minY,
                             confidence: Array(repeating: 1, count: y.count),
                             count: (2, 2))
        print(filter.b, fit.b)
        print(filter.a, fit.a)
    }
    @Test(
        arguments: [Impulse(count: 1024)]
    )
    func power(signal: Array<Float64>) {
        var s = SIMD4<Float64>()
        var y = signal
        let power = vDSP.sumOfSquares(y)
        vDSP.divide(y, power.squareRoot(), result: &y)
        let filter = Linear.Biquad.PEQ(ω₀: 1.0/8.0, Q: 6.0.squareRoot(), dB: 12)
        biquad_filter_convolve_static(filter.b, filter.a, y, &y, &s, y.count)
        let dft = DFT.DFS(count: y.count)
        let Y = y.withUnsafeTemporaryComplexBuffer(dft.forward).map(\.magnitudeSquared).prefix(y.count / 2 + 1) // half spectrum [0, π]
        let pq = Linear.Fit(frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(y.count)), count: Y.count),
                            response: Y,
                            confidence: Array(repeating: 1, count: Y.count),
                            count: (2, 2))
        print(pq)
        let fit = Linear.Direct(zpk: pq.zpk)
        print(pq.zpk)
        print(filter.b, fit.b)
        print(filter.a, fit.a)
    }
    @Test(
        arguments: [Uniform(count: 2048, padding: 2048)]
    )
    func ls(signal: Array<Float64>) {
        let filter = Linear.Biquad.PEQ(ω₀: 1.0/6.0, Q: 6.0.squareRoot(), dB: 12)
        let (b, a) = (filter.b / filter.a.x, filter.a / filter.a.x)
        let x = vDSP.divide(signal, vDSP.sumOfSquares(signal))
        let y = Array<Float64>(unsafeUninitializedCapacity: x.count) {
            $1 = $0.count
            var s = SIMD4<Float64>()
            biquad_filter_convolve_static(filter.b, filter.a, x, $0.baseAddress.unsafelyUnwrapped, &s, $0.count)
        }
        let dft = DFT.DFS(count: y.count)
        let X = x.withUnsafeTemporaryComplexBuffer(dft.forward)
        let Y = y.withUnsafeTemporaryComplexBuffer(dft.forward)
        let deterministic = Linear.fit(x: (X.map(\.real), X.map(\.imag)),
                                       y: (Y.map(\.real), Y.map(\.imag)),
                                       frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(dft.count)), count: dft.count),
                                       weight: Array<Float64>(repeating: 1, count: dft.count),
                                       count: (2, 2))
        let stochastic = Linear.fit(x: (X.map(\.real), X.map(\.imag), Array<Float64>(repeating: 0, count: X.count)),
                                    y: (Y.map(\.real), Y.map(\.imag), Array<Float64>(repeating: 0, count: Y.count)),
                                    cov: (Array<Float64>(repeating: 0, count: dft.count), Array<Float64>(repeating: 0, count: dft.count)),
                                    frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(dft.count)), count: dft.count),
                                    weight: Array<Float64>(repeating: 1, count: dft.count),
                                    count: (2, 2))
        #expect((deterministic.b[0] - b[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.b[1] - b[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.b[2] - b[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.a[0] - a[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.a[1] - a[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.a[2] - a[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.b[0] - b[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.b[1] - b[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.b[2] - b[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.a[0] - a[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.a[1] - a[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.a[2] - a[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
    }
    
}
