//
//  Linear+Direct+Power.swift
//  MUTE
//
//  Created by Kota on 9/7/26.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Numerics.Complex128
import func Complex.add
import func Complex.sub
import func Complex.mul
import func Complex.div
import func Complex.libcsqrt
import func simd.__cospi
import func simd.pow
import func simd.fma
import func simd.log
import func simd.exp
import func simd.length_squared
import func MKL.vDSP_add
import func MKL.vDSP_fill
import func BLAS.copy
import func LAPACK.hseqr
extension Linear.Direct {
    @usableFromInline
    struct ChebyshevPowerRational {
        @usableFromInline let p: Array<Float64>
        @usableFromInline let q: Array<Float64>
    }
}
extension Linear.Direct.ChebyshevPowerRational {
    @inlinable
    package init(raw: (p: Array<Float64>, q: Array<Float64>)) {
        (p, q) = raw
    }
}
extension Linear.Direct.ChebyshevPowerRational {
//    @inlinable
//    func callAsFunction(ω: Float64) -> Float64 {
//        let x = repeatElement(__cospi(2.0 * ω), count: max(p.count, q.count)).enumerated().map {
//            pow($1, .init($0))
//        }
//        let B = zip(p, x).reduce(0) { fma($1.0, $1.1, $0) }
//        let A = zip(q, x).reduce(0) { fma($1.0, $1.1, $0) }
//        return B / A
//    }
}
extension Linear.Direct.ChebyshevPowerRational {
    @inlinable
    static func Roots(chebyshef polynomial: Array<Float64>) -> (r: ArraySlice<Float64>, i: ArraySlice<Float64>) {
        let n = polynomial.count - 1
        let l = hseqr(.E, .N, n,
                      1, n,
                      .none, n,
                      .none, .none,
                      .none, n,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        let ri = Array<Float64>(unsafeUninitializedCapacity: 2 * n + n * n + l) {
            let r = $0.extracting(0*n..<1*n)
            let i = $0.extracting(1*n..<2*n)
            let h = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(2 * n).prefix(n * n))
            let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(2 * n + n * n).prefix(l))
            assert(n <= w.count)
            w[0] = 0.5.squareRoot()
            w.dropFirst().initialize(repeating: 0.5)
            vDSP.clear(&h[0..<h.count])
            copy(n - 1, w.baseAddress.unsafelyUnwrapped, 1, h.baseAddress.unsafelyUnwrapped.advanced(by: 1), n + 1)
            copy(n - 1, w.baseAddress.unsafelyUnwrapped, 1, h.baseAddress.unsafelyUnwrapped.advanced(by: n), n + 1)
            vDSP.divide(w[0..<n], -polynomial[n], result: &w[0..<n])
            vDSP.add(multiplication: (polynomial[0..<n], w[0..<n]), h[n*n-n..<n*n], result: &h[n*n-n..<n*n])
            let s = hseqr(.E, .N, n,
                          1, n,
                          h.baseAddress, n,
                          r.baseAddress, i.baseAddress,
                          .none, n,
                          w.baseAddress, l)
            assert(s == 0)
            $1 = 2 * n
        }
        return (
            ri.prefix(n),
            ri.dropFirst(n).prefix(n)
        )
    }
    @inlinable
    static func Outer(r: Float64, i: Float64) -> Complex128 {
        let x = Complex128.RawValue(.init(r: r, i: i.magnitude))
        let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
        let lhs = add(x, s)
        let rhs = sub(x, s)
        let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
        assert(length_squared(z.vector).isLess(than: 1))
        return.init(rawValue: z)
    }
}
extension Linear.Direct.ChebyshevPowerRational {
    /*
    @inlinable
    var zpk: Linear.ZPK {
        var zc = Array<Complex128>()
        var zr = Array<Float64>()
        var pc = Array<Complex128>()
        var pr = Array<Float64>()
        var logG = 0.5 * log(vDSP.sum(p)) - 0.5 * log(vDSP.sum(q))
        if 1 < p.count {
            zc.reserveCapacity(p.count - 1)
            zr.reserveCapacity(p.count - 1)
            var iter = switch Self.Roots(chebyshef: p) {
            case let (wr, wi):
                zip(wr, wi).makeIterator()
            }
            while let (r, i) = iter.next() {
                if i.isZero {
                    assert(1.0.isLessThanOrEqualTo(r.magnitude))
                    let x = Complex128.RawValue(.init(r: r, i: .zero))
                    let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
                    let lhs = add(x, s)
                    let rhs = sub(x, s)
                    let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
                    assert(length_squared(z.vector).isLess(than: 1))
                    zr.append(z.r)
                } else if let c = iter.next() { // sweep conj
                    assert(c == (r, -i))
                    let x = Complex128.RawValue(.init(r: r, i: i.magnitude))
                    let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
                    let lhs = add(x, s)
                    let rhs = sub(x, s)
                    let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
                    assert(length_squared(z.vector).isLess(than: 1))
                    zc.append(.init(real: z.r, imag: z.i.magnitude))
                }
            }
        }
        if 1 < q.count {
            pc.reserveCapacity(q.count - 1)
            pr.reserveCapacity(q.count - 1)
            var iter = switch Self.Roots(chebyshef: q) {
            case let (wr, wi):
                zip(wr, wi).makeIterator()
            }
            while let (r, i) = iter.next() {
                if i.isZero {
                    assert(1.0.isLessThanOrEqualTo(r.magnitude))
                    let x = Complex128.RawValue(.init(r: r, i: .zero))
                    let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
                    let lhs = add(x, s)
                    let rhs = sub(x, s)
                    let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
                    assert(length_squared(z.vector).isLess(than: 1))
                    pr.append(z.r)
                } else if let c = iter.next() { // sweep conj
                    assert(c == (r, -i))
                    let x = Complex128.RawValue(.init(r: r, i: i.magnitude))
                    let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
                    let lhs = add(x, s)
                    let rhs = sub(x, s)
                    let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
                    assert(length_squared(z.vector).isLess(than: 1))
                    pc.append(.init(real: z.r, imag: z.i.magnitude))
                }
            }
        }
        // gain
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: max(zc.count, zr.count, pc.count, pr.count)) {
            switch $0.update(fromContentsOf: zc.map { ($0 - 1).magnitudeSquared }) {
            case let eof:
                assert($0.indices.contains(eof))
                vForce.log($0[0..<eof], result: &$0[0..<eof])
                logG -= vDSP.sum($0[0..<eof])
            }
            switch $0.update(fromContentsOf: zr.map { ($0 - 1).magnitude }) {
            case let eof:
                assert($0.indices.contains(eof))
                vForce.log($0[0..<eof], result: &$0[0..<eof])
                logG -= vDSP.sum($0[0..<eof])
            }
            switch $0.update(fromContentsOf: pc.map { ($0 - 1).magnitudeSquared }) {
            case let eof:
                assert($0.indices.contains(eof))
                vForce.log($0[0..<eof], result: &$0[0..<eof])
                logG += vDSP.sum($0[0..<eof])
            }
            switch $0.update(fromContentsOf: pr.map { ($0 - 1).magnitude }) {
            case let eof:
                assert($0.indices.contains(eof))
                vForce.log($0[0..<eof], result: &$0[0..<eof])
                logG += vDSP.sum($0[0..<eof])
            }
        }
        return ((zc, zr), (pc, pr), .some(exp(logG)))
    }
    */
    @inlinable
    var zpk: Linear.ZPK {
        assert(!p.isEmpty)
        assert(!q.isEmpty)
        let n = SIMD2<Int>(p.count, q.count) &- 1 // len(zero), len(pole)
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
        let m = n.max()
        let l = t.max()
        var zc = Array<Complex128>()
        var zr = Array<Float64>()
        var pc = Array<Complex128>()
        var pr = Array<Float64>()
        var logG = 0.5 * log(vDSP.sum(p)) - 0.5 * log(vDSP.sum(q))
        zc.reserveCapacity(n.x)
        zr.reserveCapacity(n.x)
        pc.reserveCapacity(n.y)
        pr.reserveCapacity(n.y)
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * m + 2 * m + l) {
            let h = $0.extracting(0 * m * m ..< 1 * m * m)
            let r = $0.extracting(1 * m * m + 0 * m ..< 1 * m * m + 1 * m)
            let i = $0.extracting(1 * m * m + 1 * m ..< 1 * m * m + 2 * m)
            let w = $0.extracting(1 * m * m + 2 * m ..< 1 * m * m + 2 * m + l)
            if 1 < p.count {
                w[0] = 0.5.squareRoot()
                w[1...].initialize(repeating: 0.5)
                vDSP.clear(&h[0..<h.count])
                copy(n.x - 1, w.baseAddress.unsafelyUnwrapped, 1, h.baseAddress.unsafelyUnwrapped.advanced(by: 1), m + 1)
                copy(n.x - 1, w.baseAddress.unsafelyUnwrapped, 1, h.baseAddress.unsafelyUnwrapped.advanced(by: m), m + 1)
                vDSP.divide(w[0..<n.x], -p[n.x], result: &w[0..<n.x])
                vDSP.add(multiplication: (p[0..<n.x], w[0..<n.x]), h[n.x*m-m..<n.x*m-m+n.x], result: &h[n.x*m-m..<n.x*m-m+n.x])
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
                        assert(1.0.isLessThanOrEqualTo(r.magnitude))
                        let x = Complex128.RawValue(.init(r: r, i: .zero))
                        let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
                        let lhs = add(x, s)
                        let rhs = sub(x, s)
                        let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
                        assert(length_squared(z.vector).isLess(than: 1))
                        zr.append(z.r)
                    } else if let c = iter.next() { // sweep conj
                        assert(c == (r, -i))
                        let x = Complex128.RawValue(.init(r: r, i: i.magnitude))
                        let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
                        let lhs = add(x, s)
                        let rhs = sub(x, s)
                        let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
                        assert(length_squared(z.vector).isLess(than: 1))
                        zc.append(.init(real: z.r, imag: z.i.magnitude))
                    }
                }
            }
            if 1 < q.count {
                w[0] = 0.5.squareRoot()
                w[1...].initialize(repeating: 0.5)
                vDSP.clear(&h[0..<h.count])
                copy(n.y - 1, w.baseAddress.unsafelyUnwrapped, 1, h.baseAddress.unsafelyUnwrapped.advanced(by: 1), m + 1)
                copy(n.y - 1, w.baseAddress.unsafelyUnwrapped, 1, h.baseAddress.unsafelyUnwrapped.advanced(by: m), m + 1)
                vDSP.divide(w[0..<n.y], -q[n.y], result: &w[0..<n.y])
                vDSP.add(multiplication: (q[0..<n.y], w[0..<n.y]), h[n.y*m-m..<n.y*m-m+n.y], result: &h[n.y*m-m..<n.y*m-m+n.y])
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
                        assert(1.0.isLessThanOrEqualTo(r.magnitude))
                        let x = Complex128.RawValue(.init(r: r, i: .zero))
                        let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
                        let lhs = add(x, s)
                        let rhs = sub(x, s)
                        let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
                        assert(length_squared(z.vector).isLess(than: 1))
                        pr.append(z.r)
                    } else if let c = iter.next() { // sweep conj
                        assert(c == (r, -i))
                        let x = Complex128.RawValue(.init(r: r, i: i.magnitude))
                        let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
                        let lhs = add(x, s)
                        let rhs = sub(x, s)
                        let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
                        assert(length_squared(z.vector).isLess(than: 1))
                        pc.append(.init(real: z.r, imag: z.i.magnitude))
                    }
                }
            }
            // gain
            switch $0.update(fromContentsOf: zc.map { ($0 - 1).magnitudeSquared }) {
            case let eof:
                assert($0.indices.contains(eof))
                vForce.log($0[0..<eof], result: &$0[0..<eof])
                logG -= vDSP.sum($0[0..<eof])
            }
            switch $0.update(fromContentsOf: zr.map { ($0 - 1).magnitude }) {
            case let eof:
                assert($0.indices.contains(eof))
                vForce.log($0[0..<eof], result: &$0[0..<eof])
                logG -= vDSP.sum($0[0..<eof])
            }
            switch $0.update(fromContentsOf: pc.map { ($0 - 1).magnitudeSquared }) {
            case let eof:
                assert($0.indices.contains(eof))
                vForce.log($0[0..<eof], result: &$0[0..<eof])
                logG += vDSP.sum($0[0..<eof])
            }
            switch $0.update(fromContentsOf: pr.map { ($0 - 1).magnitude }) {
            case let eof:
                assert($0.indices.contains(eof))
                vForce.log($0[0..<eof], result: &$0[0..<eof])
                logG += vDSP.sum($0[0..<eof])
            }
        }
        return ((zc, zr), (pc, pr), .some(exp(logG)))
    }
}
