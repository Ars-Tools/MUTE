//
//  Geometry2D.swift
//  MUTE
//
//  Created by Kota on 6/10/26.
//
import Testing
@testable import PSP
@Suite
struct Geometry2DTestCases {
    @Test
    func sizeExistenceContainer() {
        #expect(MemoryLayout<Geometry2D.Line>.size <= 24)
        #expect(MemoryLayout<Geometry2D.Arc>.size <= 24)
    }
    @Test
    func mesh() {
        let mesh = Geometry2D.Mesh.Point(x: -1 ... 1, nx: 5,
                                         y: -1 ... 1, ny: 5)
        print(mesh)
    }
    @Test
    func lineArc() {
        let arc = Geometry2D.Line.Arc(centre: .init(), radius: 1, radian: 0 ... 0.5, segment: 5)
        print(arc)
    }
}
