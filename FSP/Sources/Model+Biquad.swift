//
//  Model+Biquad.swift
//  MUTE
//
//  Created by Kota on 10/7/26.
//
import func simd.fma
import typealias Numerics.Complex128
extension Model {
    public protocol Linear: Sendable {}
    public struct Biquad: Linear {
        public let b: SIMD3<Float64>
        public let a: SIMD3<Float64>
    }
}
extension Model.Biquad {
    @inlinable
    package init(raw: (b: SIMD3<Float64>, a: SIMD3<Float64>)) {
        (b, a) = raw
    }
}
extension Model.Biquad {
    @inlinable
    public var ⁻¹: Self {
        .init(raw: (a, b))
    }
}
extension Model.Biquad {
    @inlinable
    public var serialized: Array<Float64> {
        .init(arrayLiteral: b.x, b.y, b.z, a.x, a.y, a.z)
    }
    @inlinable
    public var normalized: Array<Float64> {
        switch (b / a.x, a / a.x) {
        case (let bₙ, let aₙ):
            .init(arrayLiteral: bₙ.x, bₙ.y, bₙ.z, aₙ.y, aₙ.z)
        }
    }
}
extension Model.Biquad {
    @usableFromInline
    enum Root {
        case real(Float64, Float64) // paired real roots
        case complex(real: Float64, imag: Float64) // upper side plane
    }
    @inlinable
    var zero: Root {
        switch fma(-4, b.x * b.z, b.y * b.y) {
        case let D:
            0.isLessThanOrEqualTo(D) ?
            .real(
                -(b.y + D.squareRoot()) / b.x / 2,
                -(b.y - D.squareRoot()) / b.x / 2
            ) :
            .complex(
                real: -b.y / b.x / 2,
                imag: D.magnitude.squareRoot() / b.x / 2
            )
        }
    }
    @inlinable
    var pole: Root {
        switch fma(-4, a.x * a.z, a.y * a.y) {
        case let D:
            0.isLessThanOrEqualTo(D) ?
            .real(
                -(a.y + D.squareRoot()) / a.x / 2,
                -(a.y - D.squareRoot()) / a.x / 2
            ) :
            .complex(
                real: -a.y / a.x / 2,
                imag: D.magnitude.squareRoot() / a.x / 2
            )
        }
    }
}
