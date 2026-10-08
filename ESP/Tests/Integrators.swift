import Testing
import Numerics
import simd
@testable import ESP

@Suite
struct GaussLegendreTestCase {
    @Test(arguments: Array(1...16) + [32, 64])
    func standardMoments(count: Int) {
        let rule = Integrators.GaussLegendre(count: count)
        #expect(rule.anchor.count == count)
        #expect(rule.weight.count == count)
        #expect(rule.anchor.allSatisfy { $0 > -1 && $0 < 1 })
        #expect(rule.weight.allSatisfy { $0 > 0 })
        #expect(zip(rule.anchor, rule.anchor.dropFirst()).allSatisfy { $0 < $1 })
        for degree in 0..<2 * count {
            let actual: Double = rule.integrate { pow($0, Double(degree)) }
            let expected = degree.isMultiple(of: 2) ? 2 / Double(degree + 1) : 0
            #expect(abs(actual - expected) < 2e-14)
        }
    }

    @Test
    func onePointAndIntervalMapping() {
        let rule = Integrators.GaussLegendre(count: 1)
        #expect(rule.anchor == [0])
        #expect(rule.weight == [2])
        let constant: Double = rule.integrate(over: -2...3) { _ in 1 }
        let linear: Double = rule.integrate(over: -2...3) { $0 }
        #expect(constant == 5)
        #expect(linear == 2.5)
    }

    @Test
    func complexAndZeroLengthInterval() {
        let rule = Integrators.GaussLegendre(count: 3)
        let value: Complex128 = rule.integrate(over: -2...3) { x in
            .init(real: x * x, imag: x)
        }
        #expect(abs(value.real - 35.0 / 3) < 2e-14)
        #expect(abs(value.imag - 2.5) < 2e-14)
        let zero: Complex128 = rule.integrate(over: 2...2) { .init(real: $0, imag: 1) }
        #expect(zero == 0)
    }

    @Test
    func batchAndNestedIntegration() {
        let rule = Integrators.GaussLegendre(count: 3)
        let real: Double = rule.integrate(over: -2...3) { x, y in
            for i in x.indices { y[i] = x[i] * x[i] }
        }
        #expect(abs(real - 35.0 / 3) < 2e-14)
        let complex: Complex128 = rule.integrate(over: -2...3) { x, y in
            #expect(x.count == y.count)
            for i in x.indices { y[i] = .init(real: x[i] * x[i], imag: x[i]) }
        }
        #expect(abs(complex.real - real) < 2e-14)
        #expect(abs(complex.imag - 2.5) < 2e-14)
        let nested: Complex128 = rule.integrate(over: 0...1) { x, y in
            for i in x.indices {
                y[i] = rule.integrate(over: 0...1) { u in Complex128(real: x[i] * u, imag: 1) }
            }
        }
        #expect(abs(nested.real - 0.25) < 2e-14)
        #expect(abs(nested.imag - 1) < 2e-14)
    }
}
