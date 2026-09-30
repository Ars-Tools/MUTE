//
//  Linear+Direct.swift
//  MUTE
//
//  Created by Kota on 9/3/26.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Numerics.Complex128
import func MKL.vDSP_fill
import func LAPACK.hseqr
import func Darwin.pow
import typealias ESP.Convolvers
extension Linear {
    public struct Direct: Filter {
        public let b: Array<Float64>
        public let a: Array<Float64>
    }
}
extension Linear.Direct {
    @inlinable
    package init(raw: (b: Array<Float64>, a: Array<Float64>)) {
        (b, a) = raw
    }
}
extension Linear.Direct {
    public init(zpk: Linear.ZPK) {
        let g = zpk.k ?? 1
        b = zpk.z.0.reduce(zpk.z.1.reduce(Array<Float64>(arrayLiteral: g)) {
            Convolvers.convolve(x: $0, y: [1, -$1])
        }) {
            Convolvers.convolve(x: $0, y: [1, -2 * $1.real, $1.magnitudeSquared])
        }
        a = zpk.p.0.reduce(zpk.p.1.reduce(Array<Float64>(arrayLiteral: 1)) {
            Convolvers.convolve(x: $0, y: [1, -$1])
        }) {
            Convolvers.convolve(x: $0, y: [1, -2 * $1.real, $1.magnitudeSquared])
        }
    }
}
extension Linear.Direct {
    @inlinable
    public var ⁻¹: Self {
        .init(raw: (a, b))
    }
}
extension Linear.Direct {
    @inlinable
    public var zpk: Linear.ZPK {
        assert(!b.isEmpty)
        assert(!a.isEmpty)
        let n = SIMD2<Int>(b.count, a.count) &- 1 // len(zero), len(pole)
        let t = SIMD2<Int>(
            hseqr(.E, .N, n.x,
                  1, n.x,
                  .none, n.x,
                  .none, .none,
                  .none, n.x,
                  .none as Optional<UnsafeMutablePointer<Float64>>, 0),
            hseqr(.E, .N, n.y,
                  1, n.y,
                  .none, n.y,
                  .none, .none,
                  .none, n.y,
                  .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        ) // extra workspace
        assert(0 < t.min())
        let m = n.max() as Int
        let l = t.max() as Int
        var zc = Array<Complex128>()
        var zr = Array<Float64>()
        var pc = Array<Complex128>()
        var pr = Array<Float64>()
        zc.reserveCapacity(n.x)
        zr.reserveCapacity(n.x)
        pc.reserveCapacity(n.y)
        pr.reserveCapacity(n.y)
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * m + 2 * m + l) {
            let h = $0.extracting(0 * m * m ..< 1 * m * m)
            let r = $0.extracting(1 * m * m + 0 * m ..< 1 * m * m + 1 * m)
            let i = $0.extracting(1 * m * m + 1 * m ..< 1 * m * m + 2 * m)
            let w = $0.extracting(1 * m * m + 2 * m ..< 1 * m * m + 2 * m + l)
            if 1 < b.count {
                vDSP.clear(&h[0..<h.count])
                vDSP.divide(b[1..<n.x+1], -b[0], result: &h[n.x*m-m..<n.x*m-m+n.x])
                vDSP.reverse(&h[n.x*m-m..<n.x*m-m+n.x])
                vDSP_fill(1, h.baseAddress.unsafelyUnwrapped.advanced(by: 1), m + 1, n.x - 1)
                let s = hseqr(.E, .N, n.x,
                              1, n.x,
                              h.baseAddress, m,
                              r.baseAddress, i.baseAddress,
                              .none, n.x,
                              w.baseAddress, l)
                assert(s == 0)
                var iter = zip(r, i).prefix(n.x).makeIterator()
                while let (r, i) = iter.next() {
                    if i.isZero {
                        zr.append(r)
                    } else if let c = iter.next() { // sweep conj
                        assert(c == (r, -i))
                        zc.append(.init(real: r, imag: i.magnitude))
                    }
                }
            }
            if 1 < a.count {
                vDSP.clear(&h[0..<h.count])
                vDSP.divide(a[1..<n.y+1], -a[0], result: &h[n.y*m-m..<n.y*m-m+n.y])
                vDSP.reverse(&h[n.y*m-m..<n.y*m-m+n.y])
                vDSP_fill(1, h.baseAddress.unsafelyUnwrapped.advanced(by: 1), m + 1, n.y - 1)
                let s = hseqr(.E, .N, n.y,
                              1, n.y,
                              h.baseAddress, m,
                              r.baseAddress, i.baseAddress,
                              .none, n.y,
                              w.baseAddress, l)
                assert(s == 0)
                var iter = zip(r, i).prefix(n.y).makeIterator()
                while let (r, i) = iter.next() {
                    if i.isZero {
                        pr.append(r)
                    } else if case.some((r, -i)) = iter.next() { // sweep conj
                        pc.append(.init(real: r, imag: i.magnitude))
                    } else {
                        assertionFailure()
                    }
                }
            }
        }
        return ((zc, zr), (pc, pr), b[0] / a[0])
    }
}
