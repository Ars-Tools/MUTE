import Testing
import typealias Numerics.Complex128
@testable import ESP

@Suite
struct PolynomialTestCases {
    @Test(arguments: [0.2, 0.3, 0.7])
    func roots(θ: Float64) {
        let p = Complex128(r: 0.9, θ: θ)
        // Known quadratic with roots p and its complex conjugate.
        let coefficients = [1.0, -2 * p.real, 0.81]
        let roots = Polynomial.roots(poly: coefficients)
        #expect(roots.count == 2)
        #expect(roots.contains { ($0 - p).magnitude < 1e-14 })
        #expect(roots.contains { ($0 - p.conj).magnitude < 1e-14 })
    }
}
