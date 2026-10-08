import Testing
import func Darwin.cos
@testable import FSP

@Suite(.serialized)
struct ModelWithCodexTestCases {
    @Test
    func sdpRecoversNontrivialPositiveRatio() {
        let frequency = (0...4096).map { Float64($0) / 8192 }
        let x = frequency.map { 1 - 0.2 * cos(2 * .pi * $0) }
        let y = frequency.map { 1 + 0.4 * cos(2 * .pi * $0) }
        let result = Model.WithCodex.fitResult(xx: x,
                                       yy: y,
                                       frequency: frequency,
                                       weight: Array(repeating: 1, count: frequency.count),
                                       minimum: 1.0e-6,
                                       count: (32, 32))

        #expect(result.status == .optimal)
        let fit = result.power
        // Higher-order fits admit a common polynomial factor. The ratio,
        // positivity and scale are identifiable; individual coefficients are not.
        var maximumError = 0.0
        for (i, f) in frequency.enumerated() {
            let t = cos(2 * .pi * f)
            maximumError = max(maximumError, abs(fit.p(t) / fit.q(t) - y[i] / x[i]))
        }
        #expect(maximumError < 1e-6)
        #expect(abs(fit.p.rawValue[0] + fit.q.rawValue[0] - 2) < 1e-12)

    }

    @Test
    func activePositivityConstraintConvergesAcrossBarrierStages() {
        let frequency = (0...256).map { Float64($0) / 512 }
        let fit = Model.WithCodex.fit(xx: Array(repeating: 1, count: frequency.count),
                                       yy: Array(repeating: 100, count: frequency.count),
                                       frequency: frequency,
                                       weight: Array(repeating: 1, count: frequency.count),
                                       minimum: 0.1,
                                       count: (0, 0))

        #expect(fit.p.rawValue[0] > 1.899999)
        #expect(fit.q.rawValue[0] >= 0.1)
        #expect(fit.q.rawValue[0] < 0.100001)
    }
}

@Suite(.serialized)
struct WithCodexSDPCertificateTests {
    @Test func analyticBoundaryOptimumHasValidGap() {
        let r = Model.WithCodex.fitResult(xx: [1.0], yy: [100.0], frequency: [0.1],
                                           weight: [1.0], minimum: 0.1, count: (0, 0))
        let exact = 0.5 * (1.9 - 10) * (1.9 - 10) / 10001
        #expect(r.status == .optimal)
        #expect(abs(r.objective - exact) < 1e-10)
        #expect(r.dualLowerBound <= exact + 1e-12)
        #expect(r.objective >= r.dualLowerBound)
        #expect(r.dualityGap < 1e-8)
        #expect(r.equalityResidual < 1e-12)
    }
    @Test func iterationBudgetIsTotalAndFailureIsExplicit() {
        let r = Model.WithCodex.fitResult(xx: [1.0, 1], yy: [2.0, 3], frequency: [0.0, 0.5],
                                           weight: [1.0, 1], iteration: 1, minimum: 1e-6, count: (2, 2))
        #expect(r.status == .iterationLimit)
        #expect(r.iterations <= 1)
        let fallback = Model.WithCodex.fit(xx: [1.0], yy: [100.0], frequency: [0.0],
                                            weight: [1.0], iteration: 0, minimum: 1e-6, count: (2, 1))
        #expect(fallback.p.rawValue == [1, 0, 0])
        #expect(fallback.q.rawValue == [1, 0])
    }
    @Test func finiteExtremePowersAndWeightScalingPreserveRatio() {
        let a = Model.WithCodex.fitResult(xx: [1e308], yy: [5e307], frequency: [0.1],
                                           weight: [1e300], minimum: 1e-6, count: (0, 0))
        let b = Model.WithCodex.fitResult(xx: [2.0], yy: [1.0], frequency: [0.1],
                                           weight: [1e-200], minimum: 1e-6, count: (0, 0))
        #expect(a.status == .optimal && b.status == .optimal)
        #expect(abs(a.power.p(0) / a.power.q(0) - 0.5) < 1e-6)
        #expect(abs(a.power.p(0) / a.power.q(0) - b.power.p(0) / b.power.q(0)) < 1e-12)
    }
    @Test func sparseSamplesStillConstrainTheWholeInterval() {
        let r = Model.WithCodex.fitResult(xx: [1.0, 1, 1, 1], yy: [0.01, 1, 100, 1],
                                           frequency: [0.0, 0.17, 0.33, 0.5], weight: [1.0, 1, 1, 1],
                                           minimum: 0.01, count: (4, 3))
        #expect(r.status == .optimal)
        for i in 0...2048 {
            let t = -1 + 2 * Double(i) / 2048
            #expect(r.power.p(t) >= 0.01 - 1e-12)
            #expect(r.power.q(t) >= 0.01 - 1e-12)
        }
    }
    @Test func nonzeroNoisyOptimumHasADualCertificate() {
        let f = (0...256).map { Double($0) / 512 }
        let y = f.enumerated().map { i, ω in
            (1.2 + 0.4 * cos(2 * .pi * ω)) * (i.isMultiple(of: 2) ? 1.1 : 0.9)
        }
        let r = Model.WithCodex.fitResult(xx: Array(repeating: 1, count: f.count), yy: y,
                                           frequency: f, weight: Array(repeating: 1, count: f.count),
                                           minimum: 0.01, count: (3, 2))
        #expect(r.status == .optimal)
        #expect(r.objective > 0)
        #expect(r.dualLowerBound > 0)
        #expect(r.dualityGap <= 1e-8 * max(1, r.objective))
    }
}

struct WithCodexZeroDataTests {
    @Test func allZeroDataIsCertifiedWithoutIteration() {
        let r = Model.WithCodex.fitResult(xx: [0.0], yy: [0.0], frequency: [0.0],
                                           weight: [1.0], minimum: 0.01, count: (3, 0))
        #expect(r.status == .optimal && r.iterations == 0 && r.dualityGap == 0)
        #expect(r.power.p.rawValue == [1, 0, 0, 0])
        #expect(r.power.q.rawValue == [1])
    }
}
