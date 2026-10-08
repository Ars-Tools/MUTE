import Testing
import func Darwin.cos
import func Darwin.hypot
import func Darwin.sqrt
import func Darwin.log
@testable import FSP

@Suite(.serialized)
struct WithCodexCompressionTests {
    @Test func preservesOriginalResidualForArbitraryCoefficients() throws {
        let f = (0..<137).map { Double($0)/274 }
        let x = f.enumerated().map { i, f in 0.7 + Double(i%7)/10 + cos(2 * .pi * f)*0.1 }
        let y = f.enumerated().map { i, f in 1.3 + Double(i%11)/10 + cos(6 * .pi * f)*0.2 }
        let w = f.indices.map { $0%9 == 0 ? 0.0 : 0.2 + Double($0%13)/10 }
        let c = [0.2, -0.1, 0.03, 0.8, -0.2, 0.15]
        let original = f.indices.reduce(0.0) { norm, i in
            let θ = 2 * Double.pi * f[i]
            let p = c[0]+c[1]*cos(θ)+c[2]*cos(2*θ)
            let q = c[3]+c[4]*cos(θ)+c[5]*cos(2*θ)
            return hypot(norm, w[i]*(p*x[i]-q*y[i])/hypot(x[i],y[i]))
        }
        for policy in [Model.WithCodex.Compression.qr, .tsqr(blockRows: 1), .tsqr(blockRows: 17)] {
            let model = try Model.WithCodex.compress(xx: x, yy: y, frequency: f, weight: w,
                                                       count: (2,2), compression: policy)
            #expect(model.rows == 6 && model.matrix.count == 36)
            #expect(abs(model.residualNorm(coefficients: c)-original) < 2e-13*original)
        }
    }

    @Test func shortRankDeficientDataKeepsAllDirections() throws {
        let c = [1.0, 0.1, 0.2, 0.3, 0.5, 0.04, -0.1]
        for policy in [Model.WithCodex.Compression.qr, .tsqr(blockRows: 1)] {
            let model = try Model.WithCodex.compress(xx: [1.0,1], yy: [2.0,2],
                                                       frequency: [0.0,0], weight: [3.0,3],
                                                       count: (3,2), compression: policy)
            let expected = sqrt(2.0)*3*abs(1.6-2*0.44)/sqrt(5.0)
            #expect(model.rows == 2)
            #expect(abs(model.residualNorm(coefficients: c)-expected) < 1e-13)
        }
    }

    @Test func policiesAndSeparatedSolverHaveSameOptimum() throws {
        let f = (0...96).map { Double($0)/192 }
        let x = Array(repeating: 1.0, count: f.count)
        let y = f.enumerated().map { i, f in 1.2+0.3*cos(2 * .pi * f)+Double(i%3)*0.04 }
        let w = f.indices.map { 0.3+Double($0%5)*0.2 }
        let qr = try Model.WithCodex.compress(xx: x, yy: y, frequency: f, weight: w,
                                               count: (3,2), compression: .qr)
        let a = Model.WithCodex.solve(qr, minimum: 0.01)
        let b = Model.WithCodex.fitResult(xx: x, yy: y, frequency: f, weight: w,
                                           compression: .tsqr(blockRows: 13), minimum: 0.01, count: (3,2))
        #expect(a.status == .optimal && b.status == .optimal)
        #expect(abs(a.objective-b.objective) < 1e-10)
        let c = a.power.p.rawValue + a.power.q.rawValue
        #expect(abs(qr.residualNorm(coefficients: c)-a.residualNorm) < 1e-12)
        // Verify the reported objective against the ORIGINAL weighted spectrum.
        let original = f.indices.reduce(0.0) { norm, i in
            let t = cos(2 * .pi * f[i])
            return hypot(norm, w[i]*(a.power.p(t)*x[i]-a.power.q(t)*y[i])/hypot(x[i],y[i]))
        }
        #expect(abs(original-a.residualNorm) < 1e-12)
    }

    @Test func lowFrequencyRatioSurvivesCompressionAndWhitenedNewton() {
        let f = (0...4096).map { Double($0)/8192 }
        func power(_ r: Double, _ t: Double) -> Double {
            let a = -2*r*cos(500/48000 * Double.pi), b = r*r
            return 1+a*a+b*b+2*a*(1+b)*t+2*b*(2*t*t-1)
        }
        let y = f.map { power(0.995, cos(2 * .pi * $0))/power(0.98, cos(2 * .pi * $0)) }
        let result = Model.WithCodex.fitResult(xx: Array(repeating: 1.0, count: f.count), yy: y,
                                                frequency: f, weight: Array(repeating: 1.0, count: f.count),
                                                compression: .tsqr(blockRows: 512), barrierFloor: 1e-22,
                                                minimum: 1e-10, count: (8,8))
        #expect(result.status == .optimal)
        var error = 0.0
        for i in 0...256 {
            let t = cos(2 * .pi * f[i])
            error = max(error, abs(10/log(10)*log(result.power.p(t)/result.power.q(t)/y[i])))
        }
        #expect(error < 0.2)
    }

    @Test func maximumDegreeFactorPreservesLowerDegreeObjective() throws {
        let f = (0..<83).map { Double($0)/166 }
        let x = Array(repeating: 1.0, count: f.count)
        let y = f.map { 1.2+0.2*cos(2 * .pi * $0) }
        let w = Array(repeating: 1.0, count: f.count)
        let big = try Model.WithCodex.compress(xx: x, yy: y, frequency: f, weight: w, count: (8,7))
        let small = try Model.WithCodex.compress(xx: x, yy: y, frequency: f, weight: w, count: (2,1))
        let low = [0.9,0.1,-0.2,1.1,0.05]
        let padded = Array(low.prefix(3))+Array(repeating: 0.0,count: 6)
                    + Array(low.suffix(2))+Array(repeating: 0.0,count: 6)
        #expect(abs(big.residualNorm(coefficients: padded)-small.residualNorm(coefficients: low)) < 1e-12)
        let reduced = try big.reduced(to: (2,1))
        #expect(reduced.rows == 5)
        #expect(abs(reduced.residualNorm(coefficients: low)-small.residualNorm(coefficients: low)) < 1e-12)
    }
}
