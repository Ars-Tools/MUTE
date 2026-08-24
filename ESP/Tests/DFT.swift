//
//  DFT.swift
//  MUTE
//
//  Created by Kota on 8/18/26.
//
import Testing
import typealias Numerics.Complex128
@testable import ESP
@Suite
struct DFTTestCases {
    func compare(a: some DFT.`Protocol`, b: some DFT.`Protocol`) {
        let count = min(a.count, b.count)
        #expect(count == a.count)
        #expect(count == b.count)
        let signal = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:)).map(Complex128.init)
        do {
            let A = a.forward(signal)
            let B = b.forward(signal)
            #expect(A.count == B.count)
            #expect(zip(A, B).map(-).map(\.magnitudeSquared).allSatisfy { $0.isLess(than: .ulpOfOne) })
        }
        do {
            let A = a.inverse(signal)
            let B = b.inverse(signal)
            #expect(A.count == B.count)
            #expect(zip(A, B).map(-).map(\.magnitudeSquared).allSatisfy { $0.isLess(than: .ulpOfOne) })
        }
    }
    @Test(
        arguments: [3 * 5 * 7 * 11, 3 * 5 * 7 * 64, 1 << 12]
    )
    func dense_vs_dfs(count: Int) throws {
        compare(a: DFT.DFS(dense: count), b: DFT.DFS(count: count))
    }
    @Test(
        arguments: [3 * 5 * 7 * 11, 3 * 5 * 7 * 64, 1 << 12]
    )
    func dense_vs_bfs(count: Int) throws {
        compare(a: DFT.DFS(dense: count), b: DFT.BFS(count: count))
    }
}
