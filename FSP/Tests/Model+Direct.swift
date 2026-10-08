//
//  Model+Direct.swift
//  MUTE
//
//  Created by Kota on 9/4/26.
//
import Numerics
import Testing
import func simd.__cospi
@testable import typealias FSP.Model
@Suite
struct ModelDirectTestCases {
    @Test(arguments: [
        ((0.9, 0.1, 0.3), (0.9, 0.25, 0.1))
    ])
    func roots(b: (r: Float64, ω: Float64, h: Float64),
               a: (r: Float64, ω: Float64, h: Float64)) {
        let b2 = [1, -2 * b.r * __cospi(2.0 * b.ω), b.r * b.r]
        let b3 = [b2[0], b2[1] - b.h * b2[0], b2[2] - b.h * b2[1], -b.h * b2[2]]
        let a2 = [1, -2 * a.r * __cospi(2.0 * a.ω), a.r * a.r]
        let a3 = [a2[0], a2[1] - a.h * a2[0], b2[2] - a.h * a2[1], -a.h * a2[2]]
        let object = Model.Direct(b: b3, a: a3)
        let factor = object.zpk
        #expect(factor.z.0.contains { ($0 - .init(r: b.r, ω: b.ω)).magnitudeSquared.isLess(than: .ulpOfOne) })
        #expect(factor.z.1.contains { ($0 - b.h).magnitude.isLess(than: .ulpOfOne.squareRoot()) })
        #expect(factor.p.0.contains { ($0 - .init(r: a.r, ω: a.ω)).magnitudeSquared.isLess(than: .ulpOfOne) })
        #expect(factor.p.1.contains { ($0 - a.h).magnitude.isLess(than: .ulpOfOne.squareRoot()) })
    }
    @Test(arguments: [
        ((0.9, 0.3, 0.3), (0.9, 0.4, 0.1))
    ])
    func poly(b: (r: Float64, ω: Float64, h: Float64),
              a: (r: Float64, ω: Float64, h: Float64)) {
        let zpk = Model.ZPK(raw: (
            ([.init(r: b.r, ω: b.ω)], [b.h]),
            ([.init(r: a.r, ω: a.ω)], [a.h]),
            .none
        ))
        let object = Model.Direct(zpk: zpk)
        let factor = object.zpk
        #expect(factor.z.0.contains { ($0 - .init(r: b.r, ω: b.ω)).magnitudeSquared.isLess(than: .ulpOfOne) })
        #expect(factor.z.1.contains { ($0 - b.h).magnitude.isLess(than: .ulpOfOne.squareRoot()) })
        #expect(factor.p.0.contains { ($0 - .init(r: a.r, ω: a.ω)).magnitudeSquared.isLess(than: .ulpOfOne) })
        #expect(factor.p.1.contains { ($0 - a.h).magnitude.isLess(than: .ulpOfOne.squareRoot()) })
    }
}
