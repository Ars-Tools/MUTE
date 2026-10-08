import Testing
@testable import FSP

struct ModelPowerCompressionTests {
    @Test
    func stochasticConstantFitUsesEveryMomentRow() {
        let x = [1.0, 2.0, 1.5, 3.0, 0.8]
        let y = [1.4, 0.8, 2.2, 1.1, 3.0]
        let vx = [0.2, 0.4, 0.1, 0.3, 0.5]
        let vy = [0.3, 0.2, 0.6, 0.4, 0.2]
        let covariance = [0.06, -0.04, 0.1, 0.05, -0.08]
        let frequency = [0.0, 0.1, 0.2, 0.3, 0.4]
        let weight = [1.0, 0.2, 3.0, 0.0, 2.0]

        // For constant P,Q and P+Q=2, minimize A P² - 2 B P Q + C Q².
        // This reference uses the original moments, independently of QR.
        var a = 0.0
        var b = 0.0
        var c = 0.0
        for i in x.indices {
            let xx = x[i] * x[i] + vx[i]
            let yy = y[i] * y[i] + vy[i]
            let xy = x[i] * y[i] + covariance[i]
            let scale = weight[i] / (xx + yy)
            a += scale * xx
            b += scale * xy
            c += scale * yy
        }
        let expectedP = 2 * (b + c) / (a + 2 * b + c)
        let expectedQ = 2 - expectedP

        for order in [Array(x.indices), Array(x.indices.reversed())] {
            let result = Model.fit(xx: (μ: order.map { x[$0] }, σ²: order.map { vx[$0] }),
                                   yy: (μ: order.map { y[$0] }, σ²: order.map { vy[$0] }),
                                   cov: order.map { covariance[$0] },
                                   frequency: order.map { frequency[$0] },
                                   weight: order.map { weight[$0] },
                                   minimum: 1e-5, count: (0, 0))
            #expect(result.converged)
            #expect(abs(result.coefficients.p.rawValue[0] - expectedP) < 1e-5)
            #expect(abs(result.coefficients.q.rawValue[0] - expectedQ) < 1e-5)
        }
    }

    @Test
    func zeroCovarianceMatchesDeterministicFit() {
        let x = [1.0, 2.0, 1.5, 3.0, 0.8]
        let y = [1.4, 0.8, 2.2, 1.1, 3.0]
        let zero = Array(repeating: 0.0, count: x.count)
        let frequency = [0.0, 0.1, 0.2, 0.3, 0.4]
        let weight = [1.0, 0.2, 3.0, 0.0, 2.0]
        let deterministic = Model.fit(xx: x, yy: y, frequency: frequency, weight: weight,
                                      minimum: 1e-5, count: (0, 0))
        let stochastic = Model.fit(xx: (μ: x, σ²: zero), yy: (μ: y, σ²: zero), cov: zero,
                                   frequency: frequency, weight: weight,
                                   minimum: 1e-5, count: (0, 0))
        #expect(deterministic.converged && stochastic.converged)
        #expect(abs(deterministic.coefficients.p.rawValue[0] - stochastic.coefficients.p.rawValue[0]) < 1e-7)
        #expect(abs(deterministic.coefficients.q.rawValue[0] - stochastic.coefficients.q.rawValue[0]) < 1e-7)
    }
}
