//
//  Linear+Biquad+Cascade.swift
//  MUTE
//
//  Created by Kota on 9/3/26.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func simd.log1p
import func simd.simd_abs
import func simd.log2
import func simd.exp2
import func simd.fma
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
            // maximize bottleneck
            /*
            var table = MatBuf(shape: (r.count, r.count), with: 0.0)
            for (row, r₀) in r.enumerated() {
                for (col, r₁) in r.enumerated().dropFirst(row + 1) {
                    switch simd_abs(SIMD2<Float64>(1 - r₀, 1 + r₀) * SIMD2<Float64>(1 - r₁, 1 + r₁)).min() as Float64 {
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
            */
            // sorted pair
            var sorted = ArraySlice(r.sorted())
            assert(sorted.count.isMultiple(of: 2))
            while let min = sorted.popFirst(), let max = sorted.popLast() {
                p.append(.init(1, -min-max, min*max))
            }
            assert(sorted.isEmpty)
        }
        return p
    }
    @inlinable
    public init(zpk: Linear.ZPK) {
        var b = Self.Quadratics(z: zpk.z.0, r: zpk.z.1)
        var a = Self.Quadratics(z: zpk.p.0, r: zpk.p.1)
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
                    ( 𝒢.y - 𝒢.x ) / 𝒢.x // = 𝒢.y / 𝒢.x  - 1
                }
                table[row, col] = δ₋₁ - log1p(δ₋₁)
            }
        }
        self.init()
        reserveCapacity(c + 1)
        for idx in Graph.Match(table: table) {
            append(.init(raw: (b[idx.x], a[idx.y])))
        }
        switch zpk.k {
        case.some(let g):
            let forward = vForce.log2(map(\.𝒢ₘ))
            let inverse = vForce.log2(map(\.⁻¹.𝒢ₘ))
            let balance = vDSP.multiply(subtraction: (inverse, forward), 0.125)
            let total = fma(0.5, log2(g.magnitude), -vDSP.sum(balance)) / .init(count)
            let derivative = vDSP.add(total, balance)
            replaceSubrange(indices, with: zip(self, derivative).map {
                .init(raw: (
                    $0.b * exp2( $1),
                    $0.a * exp2(-$1)
                ))
            })
            if case.minus = g.sign, let first {
                replaceSubrange(0..<1, with: CollectionOfOne(
                    .init(raw: (-first.b, first.a))
                ))
            }
        case.none:
            break
        }
    }
}
extension Linear.Cascade {
    @inlinable
    public init(decompose direct: Linear.Direct) {
        self.init(zpk: direct.zpk)
    }
}
extension Linear.Cascade {
    @inlinable
    public var zpk: Linear.ZPK {
        reduce(into: ((Array<Complex128>(), Array<Float64>()), (Array<Complex128>(), Array<Float64>()), .none)) {
            switch $1.zero {
            case let root where root.0.imag.isZero:
                assert(root.1.imag.isZero)
                $0.0.1.append(root.0.real)
                $0.0.1.append(root.1.real)
            case let root:
                assert(0 > root.0.imag)
                assert(0 < root.1.imag)
                $0.0.0.append(root.1)
            }
            switch $1.pole {
            case let root where root.0.imag.isZero:
                assert(root.1.imag.isZero)
                $0.1.1.append(root.0.real)
                $0.1.1.append(root.1.real)
            case let root:
                assert(0 > root.0.imag)
                assert(0 < root.1.imag)
                $0.1.0.append(root.1)
            }
        }
    }
}
extension Linear.Cascade {
    @inlinable
    public var serialized: Array<Float64> {
        flatMap(\.serialized)
    }
    @inlinable
    public var normalized: Array<Float64> {
        flatMap(\.normalized)
    }
}
