//
//  App.swift
//  MUTE
//
//  Created by Kota on 6/16/26.
//
import SwiftUI
import ASP
import PSP
import Acoustica
import Numerics
import NSP

func elapse(count: Int) {
    let x = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:)).map(Complex128.init)
    let y = UnsafeMutablePointer<Complex128>.allocate(capacity: 3 * count)
    defer { y.deallocate() }
    let w = y.advanced(by: count)
    do {
        let s = CFAbsoluteTimeGetCurrent()
        defer {
            os_log(.debug, "jit: %lfs", CFAbsoluteTimeGetCurrent() - s)
        }
        dft_forward(count,
                    .init(x), 1,
                    .init(y), 1,
                    .some(.init(w)))
    }
    do {
        let dft = ddft_create(count)
        defer { dft_destroy(dft) }
        let s = CFAbsoluteTimeGetCurrent()
        defer {
            os_log(.debug, "dfs: %lfs", CFAbsoluteTimeGetCurrent() - s)
        }
        dft_forward(dft, .DFT_SCALE_ONE,
                    .init(x), 1,
                    .init(y), 1,
                    .some(.init(w)))
    }
    do {
        let dft = bdft_create(count)
        defer { dft_destroy(dft) }
        let s = CFAbsoluteTimeGetCurrent()
        defer {
            os_log(.debug, "bfs: %lfs", CFAbsoluteTimeGetCurrent() - s)
        }
        dft_forward(dft, .DFT_SCALE_ONE,
                    .init(x), 1,
                    .init(y), 1,
                    .some(.init(w)))
    }
}
elapse(count: 2 * 3 * 5 * 7 * 255)


//DispatchQueue.global().async {
//    do {
//        let Δ = 1.0 / 10.0
//        let boundaries = [
//            Geometry2D.Arc(x: 0, y: 0, r: 8, θ: .init(uncheckedBounds: (0.0/8.0, 8.0/8.0))).refine(Δ: Δ)
////            Geometry2D.Line.Arc(centre: .zero, radius: 7.8, radian: 0.0 ... 2.0, interval: Δx),
////            Array<Geometry2D.Line>(polygonizing: Geometry2D.Arc(x: 0, y: 0, r: 7.8, θ: 0.0 ... 2.0), count: 500).reversed().map(\.revered),
////            Geometry2D.Arc(x:  0, y: 0, r: 5.8, θ: 0.0 ... 0.75).refine(Δ: Δx),
////            Geometry2D.Arc(x: -3, y: 0, r: 2.4, θ: .init(uncheckedBounds: (1, 0))).refine(Δ: Δx),
////            Geometry2D.Arc(x:  4, y: 0, r: 1.8, θ: .init(uncheckedBounds: (1, 0))).refine(Δ: Δx)
////            Geometry2D.Line.Arc(centre: .init(-4, 0), radius: 2.4, radian: 0.0 ... 2.0, interval: Δx).reversed().map(\.revered) as Array<any Geometry2D.Edge>
//        ].flatMap(\.self)
//        let sources = [
//            SIMD2<Float32>(0, 0),
//            SIMD2<Float32>(0, 1),
//            SIMD2<Float32>(0, 2),
//            SIMD2<Float32>(0, 3),
//            SIMD2<Float32>(0, 4),
////            SIMD2<Float32>(1, -5),
////            SIMD2<Float32>(-1, 5),
//        ]
//        let receivers = Geometry2D.Mesh.Point(x: -8...8, nx: 256,
//                                              y: -8...8, ny: 256)
//        let result = try BEM.Evaluate(number: 1.0 * .pi,
//                                      receivers: receivers,
//                                      sources: sources,
//                                      boundaries: boundaries)
//        switch FileManager.default {
//        case let manager:
//            manager.createFile(atPath: "/tmp/mesh.raw", contents: .some(receivers.withUnsafeBytes { Data($0) }))
//            manager.createFile(atPath: "/tmp/data.raw", contents: .some(result.withUnsafeBytes { Data($0) }))
//        }
//        print(boundaries.count)
//    } catch {
//        
//    }
//}
//RunLoop.main.run()
