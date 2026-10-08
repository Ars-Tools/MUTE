//
//  WithClaude.swift
//  MUTE
//
//  Validation for Model.WithClaude.fit (Riesz–Fejér SDP power fitter).
//
import Testing
@testable import FSP
import func Foundation.cos
import func Foundation.log

@Suite
struct WithClaudeFitTestCases {
    static func chebyshev(_ c: Array<Float64>, _ t: Float64) -> Float64 {
        var b1 = 0.0, b2 = 0.0
        for a in c.reversed() {
            (b1, b2) = (2 * t * b1 - b2 + a, b1)
        }
        return b1 - t * b2
    }

    /// Exactly representable positive target: the global optimum is a perfect fit.
    @Test
    func recoversExactRational() {
        let m = 257
        let pStar = [1.0, 0.5, 0.2]   // min over [-1,1] > 0
        let qStar = [1.0, -0.4, 0.1]
        var ω = Array<Float64>(repeating: 0, count: m)
        var xx = ω, yy = ω, w = ω
        for l in 0..<m {
            ω[l] = 0.5 * Float64(l) / Float64(m - 1)
            let t = cos(2 * .pi * ω[l])
            xx[l] = 1
            yy[l] = Self.chebyshev(pStar, t) / Self.chebyshev(qStar, t)
            w[l] = 1
        }
        let fit = Model.WithClaude.fit(xx: xx, yy: yy, frequency: ω, weight: w,
                                        minimum: 1e-3, count: (p: 2, q: 2))
        for l in 0..<m {
            let t = cos(2 * .pi * ω[l])
            let g = fit.p(t) / fit.q(t)
            let gStar = Self.chebyshev(pStar, t) / Self.chebyshev(qStar, t)
            #expect(abs(log(g / gStar)) < 1e-4)
        }
    }

    /// A deep notch with insufficient order forces the positivity constraint
    /// to bind; the certified Gram keeps P, Q above the floor everywhere.
    @Test
    func respectsPositivityUnderStress() {
        let m = 513
        let ε = 1e-2
        var ω = Array<Float64>(repeating: 0, count: m)
        var xx = ω, yy = ω, w = ω
        for l in 0..<m {
            ω[l] = 0.5 * Float64(l) / Float64(m - 1)
            let t = cos(2 * .pi * ω[l])
            xx[l] = 1
            yy[l] = 1e-4 + (t - 0.3) * (t - 0.3) // notch at t = 0.3
            w[l] = 1
        }
        let fit = Model.WithClaude.fit(xx: xx, yy: yy, frequency: ω, weight: w,
                                        minimum: ε, count: (p: 1, q: 1))
        for k in 0...4096 { // dense certificate sweep, beyond the fit grid
            let t = -1 + 2 * Float64(k) / 4096
            #expect(fit.p(t) >= ε * (1 - 1e-6))
            #expect(fit.q(t) >= ε * (1 - 1e-6))
        }
        // scale constraint
        #expect(abs(fit.p.rawValue[0] + fit.q.rawValue[0] - 2) < 1e-9)
    }

    /// Global optimality: never worse than the GGLSE active-set reference on
    /// the shared objective (within solver tolerance).
    @Test
    func neverWorseThanActiveSet() {
        let m = 257
        let ε = 1e-3
        var ω = Array<Float64>(repeating: 0, count: m)
        var xx = ω, yy = ω, w = ω
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rng() -> Float64 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Float64(seed >> 11) / Float64(1 << 53)
        }
        for l in 0..<m {
            ω[l] = 0.5 * Float64(l) / Float64(m - 1)
            let t = cos(2 * .pi * ω[l])
            xx[l] = 1
            yy[l] = (1.2 + t) * (1.3 - t) / (1.1 + 0.9 * t) * (0.8 + 0.4 * rng())
            w[l] = 1
        }
        func objective(_ fit: Model.Direct.Power) -> Float64 {
            var J = 0.0
            for l in 0..<m {
                let t = cos(2 * .pi * ω[l])
                let r = fit.p(t) * xx[l] - fit.q(t) * yy[l]
                J += w[l] * r * r / (xx[l] * xx[l] + yy[l] * yy[l])
            }
            return J
        }
        let claude = Model.WithClaude.fit(xx: xx, yy: yy, frequency: ω, weight: w,
                                           minimum: ε, count: (p: 3, q: 3))
        let gglse = Model.fit(xx: xx, yy: yy, frequency: ω, weight: w,
                               minimum: ε, count: (p: 3, q: 3)).coefficients
        #expect(objective(claude) <= objective(gglse) * (1 + 1e-6) + 1e-9)
    }
}

@Suite(.serialized)
struct PowerFitLowFrequencyTests {
    // Squared magnitude of 1 - 2r cos(θ₀) z⁻¹ + r² z⁻², in T_k(cos θ).
    static func resonatorPower(_ r: Double, _ θ: Double) -> [Double] {
        let a = -2 * r * cos(θ), b = r * r
        return [1 + a*a + b*b, 2*a*(1+b), 2*b]
    }
    @Test
    func lowFrequencyRationalIsRecovered() {
        let f = (0...8192).map { Double($0) / 16384 }
        let p = Self.resonatorPower(0.995, 500 / 48000 * .pi)
        let q = Self.resonatorPower(0.98, 500 / 48000 * .pi)
        let y = f.map { ω in
            let t = cos(2 * .pi * ω)
            return WithClaudeFitTestCases.chebyshev(p, t) / WithClaudeFitTestCases.chebyshev(q, t)
        }
        for order in [2, 8] {
            let fits = [
                Model.WithClaude.fit(xx: Array(repeating: 1, count: f.count), yy: y,
                                      frequency: f, weight: Array(repeating: 1, count: f.count),
                                      barrierFloor: 1e-22, minimum: 1e-10, count: (order, order)),
                Model.WithCodex.fit(xx: Array(repeating: 1, count: f.count), yy: y,
                                     frequency: f, weight: Array(repeating: 1, count: f.count),
                                     barrierFloor: 1e-22, minimum: 1e-10, count: (order, order))
            ]
            for (solver, fit) in fits.enumerated() {
                var maximumError = 0.0
                for i in 0...512 {
                    let t = cos(2 * .pi * f[i])
                    maximumError = max(maximumError, abs(10 / log(10) * log(fit.p(t) / fit.q(t) / y[i])))
                }
                #expect(maximumError < 0.2, "solver=\(solver), order=\(order), LF error=\(maximumError) dB")
            }
        }
    }
    @Test
    func allZeroWeightsReturnIdentity() {
        let fit = Model.WithClaude.fit(xx: [1.0, 1], yy: [2.0, 3], frequency: [0.0, 0.5],
                                        weight: [0.0, 0], minimum: 1e-6, count: (2, 2))
        #expect(fit.p.rawValue == [1, 0, 0])
        #expect(fit.q.rawValue == [1, 0, 0])
    }
}
