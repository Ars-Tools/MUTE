//
//  Geometry3D.swift
//  MUTE
//
//  Created by Kota on 7/8/26.
//
import Testing
@testable import PSP

@Suite
struct Geometry3DTestCases {
    @Test
    func sizeExistenceContainer() {
        let j = Geometry3D.Tri.init(x₀: .zero, x₁: .zero, x₂: .zero)
        print(MemoryLayout<Geometry3D.Tri<Array>>.size)
        print(MemoryLayout.size(ofValue: j))
        #expect(MemoryLayout<Geometry3D.Tri<Array>>.size <= 24)
    }

    @Test
    func triangleSampleAndArea() {
        let triangle = Geometry3D.Tri(x₀: .zero,
                                      x₁: .init(1, 0, 0),
                                      x₂: .init(0, 1, 0))
        let sample = triangle.sample(at: .init(0.25, 0.5))
        #expect(sample.position == SIMD3<Float64>(0.25, 0.5, 0.0))
        #expect(sample.normal == SIMD3<Float64>(0.0, 0.0, 1.0))
        #expect(triangle.area == 0.5)
    }
}
