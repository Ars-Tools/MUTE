//
//  BEM2D.swift
//  MUTE
//
//  Created by Kota on 6/4/26.
//
import MetalPerformanceShadersGraph
import Testing
import Foundation
import Numerics
import Acoustica
@testable import PSP
@Suite
struct BEM2DTestCases {
    @Test
    func γ() {
        print(BEM.γ)
    }
    @Test
    func solver2D() throws {
        let Δx = 1.0 / 6.0 as Float32
        let elements = [
            Geometry2D.Line.Arc(centre: .zero, radius: 7, radian: 0.0 ... 2.0, interval: Δx),
            Geometry2D.Line.Arc(centre: .init(-4, 0), radius: 2, radian: 0.0 ... 2.0, interval: Δx).reversed().map(\.revered),
        ].flatMap(\.self) as Array<any Geometry2D.Edge>
        let sources = [
            .init(3, -2),
            .init(3,  2)
        ] as Array<SIMD2<Float32>>
        let receivers = Array(Geometry2D.Mesh.Point(x: -8...8, nx: 256,
                                                    y: -8...8, ny: 256))
        let solver = try BEM.Solver2D(number: 2.0 * .pi, boundaries: elements)
        let result = try solver.evaluate(receivers: receivers, with: sources)
        switch FileManager.default {
        case let manager:
            manager.createFile(atPath: "/tmp/mesh.raw", contents: .some(receivers.withUnsafeBytes { Data($0) }))
            manager.createFile(atPath: "/tmp/data.raw", contents: .some(result.withUnsafeBytes { Data($0) }))
        }
    }
//
//    @Test
//    func indirect2D_C() throws {
//        let Δx = 1.0 / 6.0
//        let elements = [
//            Geometry2D.Line.Arc(centre: .zero, radius: 7, radian: 0.0 ... 2.0, interval: Δx).reversed().map(\.revered),
//            Geometry2D.Line.Arc(centre: .init(-4, 0), radius: 2, radian: 0.0 ... 2.0, interval: Δx),
////            Geometry2D.Line.Mesh(from: .init(-2, 4), to: .init(6, 3), segment: 128)
//        ].flatMap(\.self).map { $0 as any Geometry2D.Edge }
//        let sources = [
//            .init(3, -2),
//            .init(3,  2)
//        ] as Array<SIMD2<Float64>>
//        let receivers = Array(Geometry2D.Mesh.Point(x: -8...8, nx: 256,
//                                                   y: -8...8, ny: 256))
//        let result = try bem2(2.0 * .pi,
//                              receivers: receivers,
//                              sources: sources,
//                              sampling: 3,
//                              sampler: elements)
//        switch FileManager.default {
//        case let manager:
//            manager.createFile(atPath: "/tmp/mesh.raw", contents: .some(receivers.withUnsafeBytes { Data($0) }))
//            manager.createFile(atPath: "/tmp/data.raw", contents: .some(result.withUnsafeBytes { Data($0) }))
//        }
//    }
//    @Test
//    func indirect2D() throws {
//        let Δx = 1.0 / 6.0
//        let solver = try BEM.Indirect2D(elements: [
//            Geometry2D.Line.Arc(centre: .zero, radius: 7, radian: 0.0 ... 2.0, interval: Δx).reversed().map(\.revered),
//            Geometry2D.Line.Arc(centre: .init(-4, 0), radius: 2, radian: 0.0 ... 2.0, interval: Δx),
////            Geometry2D.Line.Mesh(from: .init(-2, 4), to: .init(6, 3), segment: 128)
//        ].flatMap(\.self), number: 2.0 * .pi)
//        let position = Geometry2D.Mesh.Point(x: -8...8, nx: 256,
//                                             y: -8...8, ny: 256)
//        let result = try solver.evaluate(positions: position,
//                                         with: [
//                                            .init(3, -2),
//                                            .init(3,  2)
//                                         ])
//        switch FileManager.default {
//        case let manager:
//            manager.createFile(atPath: "/tmp/mesh.raw", contents: .some(position.withUnsafeBytes { Data($0) }))
//            manager.createFile(atPath: "/tmp/data.raw", contents: .some(result.withUnsafeBytes { Data($0) }))
//        }
//    }
}
