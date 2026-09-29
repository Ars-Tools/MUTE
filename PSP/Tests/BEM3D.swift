//
//  BEM3D.swift
//  MUTE
//
//  Created by Kota on 7/23/26.
//
import Testing
@testable import PSP

@Suite
struct BEM3DTestCases {
    @Test
    func solver3D() throws {
        let elements = [
            Geometry3D.Tri(x₀: .init(-0.5, -0.5, 0.0),
                           x₁: .init( 0.5, -0.5, 0.0),
                           x₂: .init(-0.5,  0.5, 0.0))
        ] as Array<any Geometry3D.Face>
        let solver = try BEM.Solver3D(number: 2.0 * .pi,
                                      quadrature: 2,
                                      boundaries: elements)
        let result = try solver.evaluate(receivers: [.init(0.0, 0.0, 1.0)],
                                         with: [.init(0.0, 0.0, -1.0)])
        #expect(result.count == 1)
    }
}
