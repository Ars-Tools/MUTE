//
//  Gauss-Legendre.swift
//  MUTE
//
//  Created by Kota on 6/4/26.
//
import Testing
import Accelerate
import Numerics
import simd
@testable import PSP
@Suite
struct IntegratorsTestCases {
    @Test
    func le() {
        print(Legendre(n: 12, x: 0.3))
    }
    @Test
    func euler() {
        #expect((0.577215664901532860606512090082 - BEM.γ).magnitude < .ulpOfOne.squareRoot())
    }
    @Test
    func pₙ() {
        print(Legendre(n: 1, x: 0.3))
        print(Legendre(n: 1, x: 0.6))
    }
    @Test(arguments: [5, 4])
    func gsi(count: Int) {
        let integrator = Integrators.GaussLegendre(count: count)
        print(Array(zip(integrator.anchor, integrator.weight).map(SIMD2<Float64>.init(x:y:))))
        print(GaussLegendre(order: count))
    }
    @Test
    func point_weight() {
        print(GaussLegendre(order: 1))
        print(GaussLegendre(order: 2))
        print(GaussLegendre(order: 3))
        print(GaussLegendre(order: 4))
        print(GaussLegendre(order: 5))
        print(GaussLegendre(order: 6))
        print(GaussLegendre(order: 7))
    }
    @Test
    func arc() async throws {
        func tangent(θ: Float64) -> SIMD2<Float64> {
            switch __sincospi_stret(θ) {
            case let e:
                .init(-e.__sinval, e.__cosval)
            }
        }
        let Γ = 0.5 * GaussLegendre(order: 3).reduce(0) {
            fma(length(tangent(θ: fma($1.x, 0.5, 0.5))), $1.y, $0)
        }
        let γ = Quadrature(integrator: .qng).integrate(over: 0...1) {
            length(tangent(θ: $0))
        }
        print(Γ)
        print(γ)
    }
    @Test
    func x2() {
        let integrator = Integrators.GaussLegendre(count: 4)
        let y = integrator.integrate(over: 1...6) {
            Complex128(real: exp($0), imag: 1.0 / $0)
        }
        print(y)
    }
}
