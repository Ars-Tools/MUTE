//
//  Linear+Fit.swift
//  MUTE
//
//  Created by Kota on 9/7/26.
//
import Testing
import os.log
import func simd.log10
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
    @inlinable
    static func response(b: Array<Float64>,
                         a: Array<Float64>,
                         frequency: some Collection<Float64>) -> Array<Complex128> {
        frequency.map {
            let z = Complex128(real: cos(-2 * .pi * $0), imag: sin(-2 * .pi * $0))
            let numerator = b.reduce(into: (value: Complex128(real: 0, imag: 0), power: Complex128(real: 1, imag: 0))) {
                $0.value += Complex128(real: $1, imag: 0) * $0.power
                $0.power *= z
            }.value
            let denominator = a.reduce(into: (value: Complex128(real: 0, imag: 0), power: Complex128(real: 1, imag: 0))) {
                $0.value += Complex128(real: $1, imag: 0) * $0.power
                $0.power *= z
            }.value
            return numerator * denominator.conj * Complex128(real: 1 / denominator.magnitudeSquared, imag: 0)
        }
    }
    @Test
    func chebyshevPolynomialOperations() {
        let constant = Linear.Direct.ChebyshevPolynomial(rawValue: [3])
        #expect(constant.derivative.rawValue == [0])
        #expect(constant.`stationary-points`.isEmpty)
        #expect(constant.minimum.value == 3)
        let linear = Linear.Direct.ChebyshevPolynomial(rawValue: [1, 2])
        #expect(linear.derivative.rawValue == [2])
        #expect(linear.`stationary-points`.isEmpty)
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
            iteration: 64,
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
            iteration: 64,
            initial: [0.5, 0.5],
            subject: [([1, 1], 1)],
            penalty: { (solution: UnsafeBufferPointer<Float64>) -> Array<(Array<Float64>, Float64)> in
                evaluated.append(Array(solution))
                return solution[1] < 0.25 - 1e-12 ? [([0, 1], 0.25)] : []
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
        let fit = Linear.fit(xx: [2, 2, 2],
                             yy: [8, 8, 8],
                             frequency: [0, 0.25, 0.5],
                             weight: [1, 1, 1],
                             minimum: 0.1,
                             count: (0, 0))
        #expect((fit.p.rawValue[0] - 1.6).magnitude < 1e-12)
        #expect((fit.q.rawValue[0] - 0.4).magnitude < 1e-12)
    }
    @Test
    func positivePowerConstantActiveConstraint() {
        let fit = Linear.fit(xx: [1, 1, 1],
                             yy: [100, 100, 100],
                             frequency: [0, 0.25, 0.5],
                             weight: [1, 1, 1],
                             minimum: 0.1,
                             count: (0, 0))
        #expect((fit.p.rawValue[0] - 1.9).magnitude < 1e-12)
        #expect((fit.q.rawValue[0] - 0.1).magnitude < 1e-12)
    }
    @Test
    func stochasticPositivePowerZeroVarianceMatchesDeterministic() {
        let x = [2.0, 3.0, 5.0]
        let y = [8.0, 12.0, 20.0]
        let zero = Array(repeating: 0.0, count: x.count)
        let deterministic = Linear.fit(xx: x,
                                       yy: y,
                                       frequency: [0, 0.25, 0.5],
                                       weight: [1, 2, 3],
                                       minimum: 0.1,
                                       count: (0, 0))
        let stochastic = Linear.fit(xx: (μ: x, σ²: zero),
                                    yy: (μ: y, σ²: zero),
                                    cov: zero,
                                    frequency: [0, 0.25, 0.5],
                                    weight: [1, 2, 3],
                                    minimum: 0.1,
                                    count: (0, 0))
        #expect((stochastic.p.rawValue[0] - deterministic.p.rawValue[0]).magnitude < 1e-12)
        #expect((stochastic.q.rawValue[0] - deterministic.q.rawValue[0]).magnitude < 1e-12)
    }
    @Test
    func stochasticPositivePowerPreservesCorrelatedRelation() {
        let x = (μ: [2.0, 2.0, 2.0], σ²: [0.5, 1.0, 2.0])
        let y = (μ: [8.0, 8.0, 8.0], σ²: [8.0, 16.0, 32.0])
        let covariance = [2.0, 4.0, 8.0]
        let fit = Linear.fit(xx: x,
                             yy: y,
                             cov: covariance,
                             frequency: [0, 0.25, 0.5],
                             weight: [1, 1, 1],
                             minimum: 0.1,
                             count: (0, 0))
        let inverse = Linear.fit(xx: y,
                                 yy: x,
                                 cov: covariance,
                                 frequency: [0, 0.25, 0.5],
                                 weight: [1, 1, 1],
                                 minimum: 0.1,
                                 count: (0, 0))
        #expect((fit.p.rawValue[0] - 1.6).magnitude < 1e-12)
        #expect((fit.q.rawValue[0] - 0.4).magnitude < 1e-12)
        #expect((inverse.p.rawValue[0] - fit.q.rawValue[0]).magnitude < 1e-12)
        #expect((inverse.q.rawValue[0] - fit.p.rawValue[0]).magnitude < 1e-12)
    }
    @Test
    func stochasticComplexFitImprovesUncertainObservation() {
        // A minimum-phase biquad whose numerator and denominator must both be fitted.
        let b = [1.0, 0.4, 0.2]
        let a = [1.0, -0.3, 0.1]
        let frequency = (0...32).map { Float64($0) / 64 }
        let expected = Self.response(b: b, a: a, frequency: frequency)
        let corrupted = Set(stride(from: 4, through: 28, by: 8))
        let observed = expected.enumerated().map {
            corrupted.contains($0) ? Complex128(real: .random(in: -1...1), imag: .random(in: -1...1)) : $1
        }
        let zero = Array(repeating: 0.0, count: frequency.count)
        let x = (r: Array(repeating: 1.0, count: frequency.count), i: zero)
        let y = (r: observed.map(\.real), i: observed.map(\.imag))
        let σ²y = expected.enumerated().map { corrupted.contains($0) ? $1.magnitudeSquared : 0 }
        let weight = Array(repeating: 1.0, count: frequency.count)

        let deterministic = Linear.fit(x: x,
                                       y: y,
                                       frequency: frequency,
                                       weight: weight,
                                       count: (2, 2))
        let stochastic = Linear.fit(x: (r: x.r, i: x.i, σ²: zero),
                                    y: (r: y.r, i: y.i, σ²: σ²y),
                                    σxy: (r: zero, i: zero),
                                    frequency: frequency,
                                    weight: weight,
                                    count: (2, 2))
        let evaluation = (0...512).map { Float64($0) / 1024 }
        let truth = Self.response(b: b, a: a, frequency: evaluation)
        let deterministicResponse = Self.response(b: deterministic.b, a: deterministic.a, frequency: evaluation)
        let stochasticResponse = Self.response(b: stochastic.b, a: stochastic.a, frequency: evaluation)
        let deterministicError = zip(deterministicResponse, truth).lazy.map(-).map(\.magnitudeSquared).reduce(0, +)
        let stochasticError = zip(stochasticResponse, truth).lazy.map(-).map(\.magnitudeSquared).reduce(0, +)
        os_log(.debug, "%{public}@", "improve \(10 * log10(deterministicError / stochasticError))")
        #expect(stochasticError < deterministicError)
    }
    @Test
    func stochasticPowerFitImprovesUncertainObservation() {
        // Use the same biquad and corrupt the same four frequency bins as above.
        let b = [1.0, 0.4, 0.2]
        let a = [1.0, -0.3, 0.1]
        let frequency = (0...32).map { Float64($0) / 64 }
        let expected = Self.response(b: b, a: a, frequency: frequency)
        let corrupted = Set(stride(from: 4, through: 28, by: 8))
        let observed = expected.enumerated().map {
            corrupted.contains($0) ? Complex128(real: .random(in: -1...1), imag: .random(in: -1...1)) : $1
        }
        let zero = Array(repeating: 0.0, count: frequency.count)
        let x = (r: Array(repeating: 1.0, count: frequency.count), i: zero)
        let y = (r: observed.map(\.real), i: observed.map(\.imag))
        let σ²y = expected.indices.map { corrupted.contains($0) ? expected[$0].magnitudeSquared : 0 }
        let weight = Array(repeating: 1.0, count: frequency.count)

        let deterministic = Linear.fit(x: x,
                                       y: y,
                                       frequency: frequency,
                                       weight: weight,
                                       minimum: .ulpOfOne.squareRoot(),
                                       count: (2, 2))
        let stochastic = Linear.fit(x: (r: x.r, i: x.i, σ²: zero),
                                    y: (r: y.r, i: y.i, σ²: σ²y),
                                    σxy: (r: zero, i: zero),
                                    frequency: frequency,
                                    weight: weight,
                                    minimum: .ulpOfOne.squareRoot(),
                                    count: (2, 2))
        let evaluation = (0...512).map { Float64($0) / 1024 }
        let truth = Self.response(b: b, a: a, frequency: evaluation).map(\.magnitudeSquared)
        let deterministicResponse = Self.response(b: deterministic.b, a: deterministic.a, frequency: evaluation).map(\.magnitudeSquared)
        let stochasticResponse = Self.response(b: stochastic.b, a: stochastic.a, frequency: evaluation).map(\.magnitudeSquared)
        let deterministicError = zip(deterministicResponse, truth).lazy.map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
        let stochasticError = zip(stochasticResponse, truth).lazy.map { ($0 - $1) * ($0 - $1) }.reduce(0, +)
        os_log(.debug, "%{public}@", "improve \(10 * log10(deterministicError / stochasticError))")
        #expect(stochasticError < deterministicError)
    }
    @Test
    func positivePowerPolynomialExactFit() {
        let frequency = (0...128).map { 0.5 * Float64($0) / 128 }
        let t = frequency.map { cos(2 * .pi * $0) }
        let p = t.map { 1 + 0.2 * $0 + 0.1 * (2 * $0 * $0 - 1) }
        let q = t.map { 1 - 0.15 * $0 + 0.05 * (2 * $0 * $0 - 1) }
        let fit = Linear.fit(xx: q,
                             yy: p,
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
        arguments: [Uniform(count: 1024, padding: 1024)]
    )
    func amplitude(signal: Array<Float64>) {
        let filter = Linear.Biquad.PEQ(ω₀: 3.0/8.0, Q: 6.0.squareRoot(), dB: 6)
        let analytic = (
            b: withUnsafeBytes(of: filter.b / filter.a.x) { $0.withMemoryRebound(to: Float64.self, Array.init).prefix(3) },
            a: withUnsafeBytes(of: filter.a / filter.a.x) { $0.withMemoryRebound(to: Float64.self, Array.init).prefix(3) }
        )
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
                                            σxy: (Array<Float64>(repeating: 0, count: dft.count), Array<Float64>(repeating: 0, count: dft.count)),
                                            frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(dft.count)), count: dft.count),
                                            weight: Array<Float64>(repeating: 1, count: dft.count),
                                            count: (2, 2)) {
        case let fit:
            (b: vDSP.divide(fit.b, fit.a[0]), a: vDSP.divide(fit.a, fit.a[0]))
        }
        #expect((deterministic.b[0] - analytic.b[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.b[1] - analytic.b[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.b[2] - analytic.b[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.a[0] - analytic.a[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.a[1] - analytic.a[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.a[2] - analytic.a[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.b[0] - analytic.b[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.b[1] - analytic.b[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.b[2] - analytic.b[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.a[0] - analytic.a[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.a[1] - analytic.a[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.a[2] - analytic.a[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
    }
    @Test(
        arguments: [Uniform(count: 1024, padding: 1024)]
    )
    func power(signal: Array<Float64>) {
        let filter = Linear.Biquad.PEQ(ω₀: 3.0/8.0, Q: 6.0.squareRoot(), dB: 6)
        let analytic = (
            b: withUnsafeBytes(of: filter.b / filter.a.x) { $0.withMemoryRebound(to: Float64.self, Array.init).prefix(3) },
            a: withUnsafeBytes(of: filter.a / filter.a.x) { $0.withMemoryRebound(to: Float64.self, Array.init).prefix(3) }
        )
        let x = vDSP.divide(signal, vDSP.sumOfSquares(signal))
        let y = Array<Float64>(unsafeUninitializedCapacity: x.count) {
            $1 = $0.count
            var s = SIMD4<Float64>()
            biquad_filter_convolve_static(filter.b, filter.a, x, $0.baseAddress.unsafelyUnwrapped, &s, $0.count)
        }
        let dft = DFT.DFS(count: y.count)
        let X = x.withUnsafeTemporaryComplexBuffer(dft.forward)
        let Y = y.withUnsafeTemporaryComplexBuffer(dft.forward)
        let zero = Array(repeating: 0.0, count: dft.count)
        let deterministic = switch Linear.fit(x: (r: X.map(\.real), i: X.map(\.imag)),
                                              y: (r: Y.map(\.real), i: Y.map(\.imag)),
                                              frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(dft.count)), count: dft.count),
                                              weight: Array<Float64>(repeating: 1, count: dft.count),
                                              minimum: .ulpOfOne.squareRoot(),
                                              count: (2, 2)) {
        case let fit:
            (b: vDSP.divide(fit.b, fit.a[0]), a: vDSP.divide(fit.a, fit.a[0]))
        }
        let stochastic = switch Linear.fit(x: (r: X.map(\.real), i: X.map(\.imag), σ²: zero),
                                           y: (r: Y.map(\.real), i: Y.map(\.imag), σ²: zero),
                                           σxy: (r: zero, i: zero),
                                           frequency: vDSP.ramp(withInitialValue: 0, increment: recip(.init(dft.count)), count: dft.count),
                                           weight: Array<Float64>(repeating: 1, count: dft.count),
                                           minimum: .ulpOfOne.squareRoot(),
                                           count: (2, 2)) {
        case let fit:
            (b: vDSP.divide(fit.b, fit.a[0]), a: vDSP.divide(fit.a, fit.a[0]))
        }
        #expect((deterministic.b[0] - analytic.b[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.b[1] - analytic.b[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.b[2] - analytic.b[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.a[0] - analytic.a[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.a[1] - analytic.a[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((deterministic.a[2] - analytic.a[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.b[0] - analytic.b[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.b[1] - analytic.b[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.b[2] - analytic.b[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.a[0] - analytic.a[0]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.a[1] - analytic.a[1]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
        #expect((stochastic.a[2] - analytic.a[2]).magnitude.isLess(than: .ulpOfOne.squareRoot()))
    }
}
