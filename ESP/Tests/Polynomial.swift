//
//  Polynomial.swift
//  MUTE
//
//  Created by Kota on 8/29/26.
//
import Testing
import typealias Numerics.Complex128
import typealias Accelerate.vDSP
import typealias Foundation.KeyPathComparator
@testable import ESP
@Suite
struct PolynomialTestCases {
    @Test(
        arguments: [0.7, 0.9, 1.1]
    )
    func roots(θ: Float64) {
        let p = Complex128(r: 0.9, θ: θ)
        let q = p.conj
        let c = Polynomial.poly(roots: [p, q])
        #expect(c[0] == 1)
        #expect((c[1] - p.real - q.real).isLess(than: .leastNormalMagnitude))
        #expect((c[2] - (p * q).real).isLess(than: .leastNormalMagnitude))
    }
    @Test(
        arguments: [0.2, 0.3, 0.7]
    )
    func poly(θ: Float64) {
        let p = Complex128(r: 0.9, θ: θ)
        let q = p.conj
        let r = Polynomial.roots(poly: Polynomial.poly(roots: [p, q]))
        let a = r.first {
            $0.imag.sign == .plus
        }
        guard let a else {
            Issue.record()
            return
        }
        #expect((a - p).magnitude < .ulpOfOne)
    }
    @Test(
        arguments: [2, 3, 5, 8, 13, 21, 34]
    )
    func long(count: Int) {
        
    }
}
