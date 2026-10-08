import Testing
import func Darwin.sin
import func Darwin.cos
@testable import FSP

@Suite
struct BiquadGroupDelayTests {
    private func delay(_ b: SIMD3<Double>, _ a: SIMD3<Double> = .init(1, 0, 0)) -> Model.Biquad.GroupDelay {
        Model.Biquad(raw: (b, a)).groupDelay
    }

    // Independent complex log-derivative evaluation, without cosine polynomials.
    private func reference(_ w: SIMD3<Double>, _ ω: Double) -> Double {
        let real = w.x + w.y * cos(ω) + w.z * cos(2 * ω)
        let imag = -w.y * sin(ω) - w.z * sin(2 * ω)
        let rampReal = w.y * cos(ω) + 2 * w.z * cos(2 * ω)
        let rampImag = -w.y * sin(ω) - 2 * w.z * sin(2 * ω)
        return (rampReal * real + rampImag * imag) / (real * real + imag * imag)
    }

    @Test
    func pureDelaysAndConstantResponse() {
        for (b, expected) in [(SIMD3<Double>(1, 0, 0), 0.0), (.init(0, 1, 0), 1.0), (.init(0, 0, 1), 2.0)] {
            let g = delay(b)
            #expect(g(0.713) == expected)
            #expect(g.μ == expected)
            #expect(g.min == expected)
            #expect(g.max == expected)
            #expect(g.`stationary-points`.isEmpty)
        }
        let g = delay(.init(1, -0.3, 0.2), .init(1, -0.3, 0.2))
        #expect(g.range == 0...0)
        #expect(g.μ == 0)
    }

    @Test
    func firstOrderAllpass() {
        let r = 0.75
        let g = delay(.init(-r, 1, 0), .init(1, -r, 0))
        for ω in [0, 0.2, 0.8, 1.7, Double.pi] {
            let expected = (1 - r * r) / (1 + r * r - 2 * r * cos(ω))
            #expect(abs(g(ω) - expected) < 1e-12)
        }
        #expect(g.μ == 1)
        #expect(abs(g.min - (1 - r) / (1 + r)) < 1e-12)
        #expect(abs(g.max - (1 + r) / (1 - r)) < 1e-12)
    }

    @Test
    func nearUnitCircleAllpass() {
        let r = 1 - 1e-6
        let g = delay(.init(-r, 1, 0), .init(1, -r, 0))
        let peak = (1 + r) / (1 - r)
        #expect(abs(g(0) / peak - 1) < 1e-12)
        #expect(abs(g.max / peak - 1) < 1e-12)
        #expect(abs(g.min - (1 - r) / (1 + r)) < 1e-12)
    }

    @Test
    func removableUnitCircleZeros() {
        for b in [SIMD3<Double>(1, -2, 1), .init(1, 2, 1), .init(1, 0, -1), .init(1, -0.5, 1)] {
            let g = delay(b)
            #expect(g.μ == 1)
            #expect(g.range == 1...1)
            #expect(g[1] == 1)
            #expect(g[-1] == 1)
        }
        #expect(delay(.init(1, -1, 0)).range == 0.5...0.5)
        #expect(delay(.init(0, 1, -1)).range == 1.5...1.5)
        let pole = delay(.init(1, 0, 0), .init(1, -1, 0))
        #expect(pole.μ == -0.5)
        #expect(pole.range == -0.5 ... -0.5)
    }

    @Test
    func pointMeanAndExtrema() throws {
        let cases: [(SIMD3<Double>, SIMD3<Double>)] = [
            (.init(1, -0.4, 0.6), .init(1, -0.8, 0.3)),
            (.init(0.2, -0.4, 1), .init(1, 0.6, 0.4)),
            (.init(1, 0.3, 0.7), .init(0.25, 0.2, 1)),
            (.init(1, -1.4, 0.7), .init(1, 1.2, 0.65)),
            (.init(1, -2.5, 1), .init(1, 0.2, 0.1))
        ]
        for (b, a) in cases {
            let g = delay(b, a)
            let range = try #require(g.range)
            var total = 0.0, sampledMin = Double.infinity, sampledMax = -Double.infinity
            for i in 0..<8192 {
                let ω = Double.pi * (Double(i) + 0.5) / 8192
                let value = reference(b, ω) - reference(a, ω)
                #expect(abs(g(ω) - value) < 1e-10)
                total += value
                sampledMin = Swift.min(sampledMin, value)
                sampledMax = Swift.max(sampledMax, value)
            }
            #expect(abs(g.μ - total / 8192) < 1e-10)
            #expect(range.lowerBound <= sampledMin + 1e-10)
            #expect(range.upperBound >= sampledMax - 1e-10)
            #expect(sampledMin - range.lowerBound < 1e-5)
            #expect(range.upperBound - sampledMax < 1e-5)
            for x in g.`stationary-points` {
                let h = 1e-6
                if abs(x) < 1 - h {
                    #expect(abs((g[x + h] - g[x - h]) / (2 * h)) < 1e-6)
                }
            }
            let scaled = delay(b * 1e200, a * -1e-200)
            #expect(abs(scaled(0.731) - g(0.731)) < 1e-12)
            #expect(scaled.μ == g.μ)
        }
        #expect(!delay(.init(1, -0.4, 0.6), .init(1, -0.8, 0.3)).`stationary-points`.isEmpty)
    }

    @Test
    func invalidResponse() {
        let g = delay(.zero)
        #expect(g(0).isNaN)
        #expect(g.μ.isNaN)
        #expect(g.min.isNaN)
        #expect(g.max.isNaN)
        #expect(g.range == nil)
        #expect(delay(.init(1, 0, 0))[1.1].isNaN)
    }
}
