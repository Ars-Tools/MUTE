//
//  Integrators+GaussLegendre.swift
//  MUTE
//
//  Created by Kota on 6/16/26.
//
import typealias Accelerate.vDSP
import typealias Numerics.Complex128
import func simd.fma
import func simd.rsqrt
import func simd.__tg_cospi
import func BLAS.dot
import func BLAS.gemv
@inlinable
package func Legendre(n: Int, x: Float64) -> SIMD2<Float64> {
    switch n {
    case ..<0:
        preconditionFailure()
    case 0:
        return.init(1, 0)
    case 1:
        return.init(x, 1)
    case 2:
        return.init(0.5 * fma(3 * x, x, -1), 3 * x)
    case 3:
        return.init(0.5 * x * fma(5 * x, x, -3), 1.5 * fma(5 * x, x, -1))
    default:
        let (pₙ, pₚ) = (2...n).lazy.map(Float64.init).reduce((x, 1.0)) {
            (fma($0.1, 1 - $1, fma($1, 2, -1) * x * $0.0) / $1, $0.0)
        }
        return.init(pₙ, Float64(n) * fma(x, pₙ, -pₚ) / fma(x, x, -1))
    }
}
@inlinable
package func GaussLegendre(order n: Int, tolerance: Float64 = .ulpOfOne) -> Array<SIMD2<Float64>> {
    switch n {
    case ...0:
        preconditionFailure()
    case 1:
        return.init(arrayLiteral: .init(0, 2))
    case 2:
        return.init(arrayLiteral: .init(-rsqrt(3.0), 1), .init( rsqrt(3.0), 1))
    case 3:
        return.init(arrayLiteral: .init(-0.6.squareRoot(), 5/9.0), .init(0, 8/9.0), .init( 0.6.squareRoot(), 5/9.0))
    default:
        let (q, r) = n.quotientAndRemainder(dividingBy: 2)
        let x = (0..<q).lazy.compactMap {
            sequence(first: __tg_cospi(fma(Float64($0), 4.0, 3.0) / fma(Float64(n), 4.0, 2.0))) {
                let p = Legendre(n: n, x: $0)
                let dx = p.x / p.y
                return dx.magnitude < tolerance ? .none : .some($0 - dx)
            }.suffix(1).last
        }.map {
            let d = Legendre(n: n, x: $0).y
            return SIMD2<Float64>($0, -2 / fma($0, $0, -1) / ( d * d ))
        } as Array<SIMD2<Float64>>
        return [
            x.map { .init(-$0.x, $0.y) },
            r == .zero ? [] : {[.init(0, 2/$0/$0)]}(Legendre(n: n, x: 0).y),
            x.reversed()
        ].flatMap(\.self)
    }
}
extension Integrators {
    public struct GaussLegendre {
        public let weight: Array<Float64>
        public let anchor: Array<Float64>
    }
}
extension Integrators.GaussLegendre: Integrators.`1D` {
    @inlinable
    public init(count: Int, tolerance: Float64 = .ulpOfOne) {
        switch count {
        case ...0:
            preconditionFailure()
        case 1:
            weight = .init(arrayLiteral:  2.0)
            anchor = .init(arrayLiteral:  0.0)
        case 2:
            weight = .init(arrayLiteral:  1.0, 1.0)
            anchor = .init(arrayLiteral: -rsqrt(3.0), rsqrt(3.0))
        case 3:
            weight = .init(arrayLiteral:  5/9.0, 8/9.0, 5/9.0)
            anchor = .init(arrayLiteral: -0.6.squareRoot(), 0, 0.6.squareRoot())
        default:
            let (q, r) = count.quotientAndRemainder(dividingBy: 2)
            let x = (0..<q).compactMap {
                sequence(first: __tg_cospi(fma(Float64($0), 4.0, 3.0) / fma(Float64(count), 4.0, 2.0))) {
                    let Δ = switch Legendre(n: count, x: $0) {
                    case let L:
                        L.x / L.y
                    }
                    return Δ.magnitude < tolerance ? .none : .some($0 - Δ)
                }.suffix(1).last
            }
            let y = x.map {
                switch Legendre(n: count, x: $0).y {
                case let Δ:
                    -2 / fma($0, $0, -1) / Δ / Δ
                }
            }
            let z = Legendre(n: count, x: 0).y
            anchor = x.map(-) + .init(repeating: 0, count: r) + x.reversed()
            weight = y + .init(repeating: 2/z/z, count: r) + y.reversed()
        }
    }
}
extension Integrators.GaussLegendre {
    @inlinable@inline(__always)@_transparent
    public func integrate(over range: ClosedRange<Float64> = -1...1, integrand ƒ: (Float64) -> Float64) -> Float64 {
        integrate(over: range) {
            let count = $1.initialize(fromContentsOf: $0.map(ƒ))
            assert(count == $0.count)
        }
    }
    @inlinable@inline(__always)@_transparent
    public func integrate(over range: ClosedRange<Float64> = -1...1, integrand ƒ: (UnsafeBufferPointer<Float64>, UnsafeMutableBufferPointer<Float64>) -> Void) -> Float64 {
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: anchor.count) {
            let Γ = 0.5 * ( range.upperBound - range.lowerBound )
            vDSP.add(multiplication: (anchor, Γ), Γ + range.lowerBound, result: &$0[0..<$0.count])
            ƒ(.init($0), $0)
            return dot(anchor.count,
                       $0.baseAddress.unsafelyUnwrapped, 1,
                       weight, 1) * Γ
        }
    }
}
extension Integrators.GaussLegendre {
    @inlinable@inline(__always)@_transparent
    public func integrate(over range: ClosedRange<Float64> = -1...1, integrand ƒ: (Float64) -> Complex128) -> Complex128 {
        integrate(over: range) {
            switch $1.startIndex.distance(to: $1.initialize(fromContentsOf: $0.map(ƒ))) {
            case let eof:
                assert($1.startIndex.distance(to: eof) == $0.count)
            }
        }
    }
    @inlinable@inline(__always)@_transparent
    public func integrate(over range: ClosedRange<Float64> = -1...1, integrand ƒ: (UnsafeBufferPointer<Float64>, UnsafeMutableBufferPointer<Complex128>) -> Void) -> Complex128 {
        // Allocate with Complex128 alignment, retaining the single shared buffer.
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: (anchor.count * 3 + 3) / 2) { memory in
            memory.withMemoryRebound(to: Float64.self) {
                assert(MemoryLayout<Complex128>.alignment == 2 * MemoryLayout<Float64>.alignment)
                let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(anchor.count * 2 + 0).prefix(2))
                let x = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(anchor.count * 2 + 2).prefix(anchor.count))
                let Γ = 0.5 * ( range.upperBound - range.lowerBound )
                vDSP.add(multiplication: (anchor, Γ), Γ + range.lowerBound, result: &x[0..<x.count])
                UnsafeMutableBufferPointer(rebasing: $0.prefix(anchor.count * 2)).withMemoryRebound(to: Complex128.self) {
                    ƒ(.init(x), $0)
                }
                gemv(2, anchor.count,
                     Γ,
                     $0.baseAddress.unsafelyUnwrapped, 2, .N,
                     weight, 1,
                     0,
                     z.baseAddress.unsafelyUnwrapped, 1)
                return z.withMemoryRebound(to: Complex128.self, \.first.unsafelyUnwrapped)
            }
        }
    }
}
