//
//  Linear+Biquad+Cascade.swift
//  MUTE
//
//  Created by Kota on 9/3/26.
//
import func simd.simd_reduce_min
import func simd.simd_abs
import func simd.log1p
import typealias Numerics.Complex128
import typealias Dense.MatBuf
import typealias Optimise.Graph
extension Linear {
    public typealias Cascade = Array<Biquad>
}
extension Linear.Cascade {
    @inlinable
    public var ⁻¹: Self {
        map(\.⁻¹)
    }
}
extension Linear.Cascade {
    @inlinable@inline(__always)@_transparent
    static func Quadratics(z: Array<Complex128>, r: Array<Float64>) -> Array<SIMD3<Float64>> {
        var p = Array<SIMD3<Float64>>()
        p.reserveCapacity(z.count + r.count + r.count & 1)
        for z in z {
            p.append(.init(1, -2 * z.real, z.magnitudeSquared))
        }
        let r = r + repeatElement(0, count: r.count & 1)
        assert(r.count.isMultiple(of: 2))
        if !r.isEmpty {
            var table = MatBuf(shape: (r.count, r.count), with: 0.0)
            for (row, r₀) in r.enumerated() {
                for (col, r₁) in r.enumerated().dropFirst(row + 1) {
                    switch simd_abs(SIMD2<Float64>(1 - r₀, 1 + r₀) * SIMD2<Float64>(1 - r₁, 1 + r₁)).min() {
                    case let weight:
                        table[row, col] = weight
                        table[col, row] = weight
                    }
                }
            }
            for pair in Graph.maximumBottleneckPairing(table: table) {
                let r₀ = r[pair.x]
                let r₁ = r[pair.y]
                p.append(.init(1, -r₀-r₁, r₀*r₁))
            }
        }
        return p
    }
    @inlinable
    init(zpk: Linear.ZPK) {
        var b = Self.Quadratics(z: zpk.zero.0, r: zpk.zero.1)
        var a = Self.Quadratics(z: zpk.pole.0, r: zpk.pole.1)
        let c = Swift.max(b.count, a.count)
        b.append(contentsOf: repeatElement(.init(1, 0, 0), count: c - b.count))
        a.append(contentsOf: repeatElement(.init(1, 0, 0), count: c - a.count))
        assert(b.count == c)
        assert(a.count == c)
        var table = MatBuf(shape: (c, c), with: 0.0)
        for (row, zero) in b.enumerated() {
            for (col, pole) in a.enumerated() {
                let δ₋₁ = switch Linear.Biquad(raw: (zero, pole)).𝒢 {
                case let 𝒢:
                    ( 𝒢.y - 𝒢.x ) / 𝒢.x // 𝒢.y / 𝒢.x  - 1
                }
                table[row, col] = δ₋₁ - log1p(δ₋₁)
            }
        }
        self.init()
        reserveCapacity(c + 1)
        if case.some(let gain) = zpk.gain {
            append(.init(raw: (.init(gain, 0, 0), .init(1, 0, 0))))
        }
        for idx in Graph.Match(table: table) {
            append(.init(raw: (b[idx.x], a[idx.y])))
        }
    }
}
extension Linear.Cascade {
    @inlinable
    public init(decompose direct: Linear.Direct<Array<Float64>, Array<Float64>>) {
        self.init(zpk: direct.zpk)
    }
}
