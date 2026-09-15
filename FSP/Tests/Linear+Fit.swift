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
    @Test
    func chebyshevPolynomialOperations() {
        #expect(Linear.Direct.ChebyshevPolynomial(rawValue: [3]).derivative.rawValue == [0])
        #expect(Linear.Direct.ChebyshevPolynomial(rawValue: [1, 2]).derivative.rawValue == [2])
        #expect(Linear.Direct.ChebyshevPolynomial(rawValue: [1, 2, 3, 4]).derivative.rawValue == [14, 12, 24])
        let polynomial = Linear.Direct.ChebyshevPolynomial(rawValue: [1, 0.2, 0.1])
        let derivative = polynomial.derivative
        #expect(derivative.rawValue == [0.2, 0.4])
        #expect((polynomial(0.25) - 0.9625).magnitude < 1e-15)
        #expect((derivative(0.25) - 0.3).magnitude < 1e-15)
        let stationaryPoints = polynomial.`stationary-points`
        #expect(stationaryPoints.count == 1)
        #expect((stationaryPoints[0] + 0.5).magnitude < 1e-12)
        let minimum = polynomial.minimum
        #expect((minimum.location + 0.5).magnitude < 1e-12)
        #expect((minimum.value - 0.85).magnitude < 1e-12)
    }
    @Test
    func constrainedLeastSquaresSubject() {
        let solution = Linear.fit(
            m: 2,
            n: 2,
            a: [1, 0,
                0, 1],
            lda: 2,
            c: [2, 0],
            initial: [0.5, 0.5],
            subject: [([1, 1], 1)],
            penalty: { _ in [] }
        )

        #expect((solution[0] - 1.5).magnitude < 1e-12)
        #expect((solution[1] + 0.5).magnitude < 1e-12)
        #expect((solution[0] + solution[1] - 1).magnitude < 1e-12)
    }
    @Test
    func constrainedLeastSquaresPenalty() {
        var evaluated = Array<Array<Float64>>()
        let solution = Linear.fit(
            m: 3,
            n: 2,
            a: [1, 0, 1,
                0, 1, 1],
            lda: 3,
            c: [2, 0, 1],
            initial: [0.5, 0.5],
            subject: [([1, 1], 1)],
            penalty: {
                evaluated.append($0)
                return $0[1] < 0.25 - 1e-12 ? [([0, 1], 0.25)] : []
            }
        )

        #expect(evaluated.count == 2)
        #expect(evaluated[0][1] < 0.25)
        #expect((evaluated[1][1] - 0.25).magnitude < 1e-12)
        #expect((solution[0] - 0.75).magnitude < 1e-12)
        #expect((solution[1] - 0.25).magnitude < 1e-12)
        #expect((solution[0] + solution[1] - 1).magnitude < 1e-12)
    }
    @Test
    func positivePowerConstantExactFit() {
        let fit = Linear.fit(X: [2, 2, 2],
                             Y: [8, 8, 8],
                             frequency: [0, 0.25, 0.5],
                             weight: [1, 1, 1],
                             minimum: 0.1,
                             count: (0, 0))
        #expect((fit.p.rawValue[0] - 1.6).magnitude < 1e-12)
        #expect((fit.q.rawValue[0] - 0.4).magnitude < 1e-12)
    }
    @Test
    func positivePowerConstantActiveConstraint() {
        let fit = Linear.fit(X: [1, 1, 1],
                             Y: [100, 100, 100],
                             frequency: [0, 0.25, 0.5],
                             weight: [1, 1, 1],
                             minimum: 0.1,
                             count: (0, 0))
        #expect((fit.p.rawValue[0] - 1.9).magnitude < 1e-12)
        #expect((fit.q.rawValue[0] - 0.1).magnitude < 1e-12)
    }
    @Test
    func positivePowerPolynomialExactFit() {
        let frequency = (0...128).map { 0.5 * Float64($0) / 128 }
        let t = frequency.map { cos(2 * .pi * $0) }
        let p = t.map { 1 + 0.2 * $0 + 0.1 * (2 * $0 * $0 - 1) }
        let q = t.map { 1 - 0.15 * $0 + 0.05 * (2 * $0 * $0 - 1) }
        let fit = Linear.fit(X: q,
                             Y: p,
                             frequency: frequency,
                             weight: Array(repeating: 1, count: frequency.count),
                             minimum: 0.1,
                             count: (2, 2))
        for (actual, expected) in zip(fit.p.rawValue, [1, 0.2, 0.1]) {
            #expect((actual - expected).magnitude < 1e-8)
        }
        for (actual, expected) in zip(fit.q.rawValue, [1, -0.15, 0.05]) {
            #expect((actual - expected).magnitude < 1e-8)
        }
        for t in stride(from: -1.0, through: 1.0, by: 1.0 / 1024) {
            #expect(0.1 <= fit.p(t))
            #expect(0.1 <= fit.q(t))
        }
    }
//    @Test(
//        arguments: [Impulse(count: 256)]
//    )
//    func mag(signal: Array<Float64>) {
//        var s = SIMD4<Float64>()
//        var y = signal
//        let power = vDSP.sumOfSquares(y)
//        vDSP.divide(y, power.squareRoot(), result: &y)
//        let filter = Linear.Biquad.PEQ(ω₀: 1.0/8.0, Q: 6.0.squareRoot(), dB: 12)
//        biquad_filter_convolve_static(filter.b, filter.a, y, &y, &s, y.count)
//        let dft = DFT.DFS(count: y.count)
//        let Y = y.withUnsafeTemporaryComplexBuffer(dft.forward)
//        let minY = Hilbert.Transformer(dft: dft).MinimumPhase(response: Y.map(\.magnitude))
//        let fit = Linear.Fit(frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(y.count)), count: y.count),
//                             response: minY,
//                             confidence: Array(repeating: 1, count: y.count),
//                             count: (2, 2))
//        print(filter.b, fit.b)
//        print(filter.a, fit.a)
//    }
//    @Test(
//        arguments: [Impulse(count: 1024)]
//    )
//    func power(signal: Array<Float64>) {
//        var s = SIMD4<Float64>()
//        var y = signal
//        let power = vDSP.sumOfSquares(y)
//        vDSP.divide(y, power.squareRoot(), result: &y)
//        let filter = Linear.Biquad.PEQ(ω₀: 1.0/8.0, Q: 6.0.squareRoot(), dB: 12)
//        biquad_filter_convolve_static(filter.b, filter.a, y, &y, &s, y.count)
//        let dft = DFT.DFS(count: y.count)
//        let Y = y.withUnsafeTemporaryComplexBuffer(dft.forward).map(\.magnitudeSquared).prefix(y.count / 2 + 1) // half spectrum [0, π]
//        let pq = Linear.Fit(frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(y.count)), count: Y.count),
//                            response: Y,
//                            confidence: Array(repeating: 1, count: Y.count),
//                            count: (2, 2))
//        print(pq)
//        let fit = Linear.Direct(zpk: pq.zpk)
//        print(pq.zpk)
//        print(filter.b, fit.b)
//        print(filter.a, fit.a)
//    }
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
        let deterministic = switch Linear.fit(x: (X.map(\.real), X.map(\.imag)),
                                              y: (Y.map(\.real), Y.map(\.imag)),
                                              frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(dft.count)), count: dft.count),
                                              weight: Array<Float64>(repeating: 1, count: dft.count),
                                              count: (2, 2)) {
        case let fit:
            (b: vDSP.divide(fit.b, fit.a[0]), a: vDSP.divide(fit.a, fit.a[0]))
        }
        let stochastic = switch  Linear.fit(x: (X.map(\.real), X.map(\.imag), Array<Float64>(repeating: 0, count: X.count)),
                                            y: (Y.map(\.real), Y.map(\.imag), Array<Float64>(repeating: 0, count: Y.count)),
                                            cov: (Array<Float64>(repeating: 0, count: dft.count), Array<Float64>(repeating: 0, count: dft.count)),
                                            frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(dft.count)), count: dft.count),
                                            weight: Array<Float64>(repeating: 1, count: dft.count),
                                            count: (2, 2)) {
        case let fit:
            (b: vDSP.divide(fit.b, fit.a[0]), a: vDSP.divide(fit.a, fit.a[0]))
        }
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
    @Test(
        arguments: [Uniform(count: 2048, padding: 2048)]
    )
    func power(signal: Array<Float64>) {
        let filter = Linear.Biquad.PEQ(ω₀: 3.0/8.0, Q: 6.0.squareRoot(), dB: 12)
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
        let pow = switch Linear.fit(X: X.map(\.magnitudeSquared),
                                    Y: Y.map(\.magnitudeSquared),
                                    frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(dft.count)), count: dft.count),
                                    weight: Array<Float64>(repeating: 1, count: dft.count),
                                    minimum: .ulpOfOne.squareRoot(),
                                    count: (2, 2)) as Linear.Direct.ChebyshevPowerRational {
        case let fit:
            switch Linear.Direct(zpk: fit.zpk) {
            case let direct:
                (b: vDSP.divide(direct.b, direct.a[0]), a: vDSP.divide(direct.a, direct.a[0]))
            }
        }
        let svd = switch Linear.fit(x: (X.map(\.real), X.map(\.imag), Array(repeating: 0, count: X.count)),
                                    y: (Y.map(\.real), Y.map(\.imag), Array(repeating: 0, count: X.count)),
                                    cov: (Array(repeating: 0, count: dft.count), Array(repeating: 0, count: dft.count)),
                                    frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(dft.count)), count: dft.count),
                                    weight: Array<Float64>(repeating: 1, count: dft.count),
                                    count: (2, 2)) as Linear.Direct.ChebyshevPowerRational {
        case let fit:
            switch Linear.Direct(zpk: fit.zpk) {
            case let direct:
                (b: vDSP.divide(direct.b, direct.a[0]), a: vDSP.divide(direct.a, direct.a[0]))
            }
        }
        #expect((pow.b[0] - b[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((pow.b[1] - b[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((pow.b[2] - b[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((pow.a[0] - a[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((pow.a[1] - a[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((pow.a[2] - a[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((svd.b[0] - b[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((svd.b[1] - b[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((svd.b[2] - b[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((svd.a[0] - a[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((svd.a[1] - a[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((svd.a[2] - a[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
    }
}
