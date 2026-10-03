//
//  Linear.swift
//  MUTE
//
//  Created by Kota on 9/3/26.
//
import Complex
import typealias Numerics.Complex128
import func simd.recip
public enum Linear {
    public protocol `Filter`: Sendable {}
}
extension Linear {
    @usableFromInline
    enum Root {
        case real(Float64)
        case conjugatePair(upper: Complex128)
    }
    public typealias ZPK = (
        z: (Array<Complex128>, Array<Float64>),
        p: (Array<Complex128>, Array<Float64>),
        k: Optional<Float64>
    )
}
extension Linear {
    @inlinable@_transparent
    static func minimumphase(reflecting roots: (Array<Complex128>, Array<Float64>)) -> (Array<Complex128>, Array<Float64>) {
        (
            roots.0.map {
                switch $0.magnitudeSquared {
                case let r where 1... ~= r:
                    .init(real: $0.real / r, imag: $0.imag / r)
                default:
                    $0
                }
            },
            roots.1.map {
                switch $0.magnitude {
                case let r where 1... ~= r:
                    copysign(recip(r), $0)
                default:
                    $0
                }
            }
        )
    }
    @inlinable
    public static func minimumphase(reflecting zpk: ZPK) -> ZPK {
        (
            minimumphase(reflecting: zpk.z),
            minimumphase(reflecting: zpk.p),
            zpk.k
        )
    }
}
extension Linear.Root {
    @inlinable
    init(_ r: Float64) {
        self = .real(r)
    }
    @inlinable
    init(_ r: Float64, _ i: Float64) {
        assert(0.isLess(than: i))
        self = .conjugatePair(upper: .init(real: r, imag: i))
    }
    @inlinable
    var magnitude: Float64 {
        switch self {
        case.real(let r):
            r.magnitude
        case.conjugatePair(let r):
            r.magnitude
        }
    }
}
