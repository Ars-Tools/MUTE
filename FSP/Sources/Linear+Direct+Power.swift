//
//  Linear+Direct+Power.swift
//  MUTE
//
//  Created by Kota on 9/7/26.
//
import typealias Foundation.KeyPathComparator
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
import func Layout.concat
extension Linear.Direct {
    @usableFromInline
    struct ChebyshevPolynomial {
        @usableFromInline let rawValue: Array<Float64>
    }
    @usableFromInline
    struct ChebyshevPowerRational {
        @usableFromInline let p: ChebyshevPolynomial
        @usableFromInline let q: ChebyshevPolynomial
    }
}
extension Linear.Direct.ChebyshevPolynomial {
    /// Lazily generates `T₀(x), T₁(x), …` without an upper degree bound.
    @inlinable
    static func basis(at x: Float64) -> some Sequence<Float64> {
        sequence(state: (previous: 1.0, current: x)) { state in
            defer {
                state = (state.current, 2 * x * state.current - state.previous)
            }
            return state.previous
        }
    }
}
extension Linear.Direct.ChebyshevPolynomial {
    @inlinable
    package init(_ coefficients: Array<Float64>) {
        rawValue = coefficients
    }
    @inlinable
    package init(degree: Int, at x: Float64) {
        assert(0 <= degree)
        rawValue = .init(Self.basis(at: x).prefix(degree + 1))
    }
}
extension Linear.Direct.ChebyshevPowerRational {
    @inlinable
    package init(raw: (p: Linear.Direct.ChebyshevPolynomial, q: Linear.Direct.ChebyshevPolynomial)) {
        (p, q) = raw
    }
    @inlinable
    package init(raw: (p: Array<Float64>, q: Array<Float64>)) {
        self.init(raw: (.init(raw.p), .init(raw.q)))
    }
}
extension Linear.Direct.ChebyshevPolynomial {
    @inlinable
    func callAsFunction(_ x: Float64) -> Float64 {
        assert(!rawValue.isEmpty)
        let x₂ = 2 * x
        let (b₁, b₂) = rawValue.reversed().reduce((0.0, 0.0)) {(
            fma(x₂, $0.0, $1 - $0.1),
            $0.0
        )}
        return fma(-x, b₂, b₁)
    }
}
extension Linear.Direct.ChebyshevPolynomial {
    @inlinable
    var derivative: Self {
        guard rawValue.count > 1 else {
            return.init(.init(arrayLiteral: 0))
        }
        var coefficients = rawValue
            .dropFirst()
            .reversed()
            .enumerated()
            .reduce(
                into: Array<Float64>(repeating: 0.0, count: rawValue.count + 1)
            ) {
                $0[rawValue.count - $1.0 - 2] = fma(
                    2 * Float64(rawValue.count - $1.0 - 1),
                    $1.1,
                    $0[rawValue.count - $1.0 - 0]
                )
            }
        coefficients[0] *= 0.5
        return.init(coefficients.dropLast(2))
    }
    @inlinable // compute roots of the chebyshev-polynomial and return positive-side-imaginary-only complex roots and real roots
    var roots: (Array<Complex128>, Array<Float64>) {
        var ℂ = Array<Complex128>()
        var ℝ = Array<Float64>()
        switch rawValue.count - 1 {
        case ...0:
            break
        case 1:
            ℝ.append(-rawValue[0] / rawValue[1])
        case let n:
            assert(1 < n)
            let l = hseqr(.E, .N, n,
                          1, n,
                          .none, n,
                          .none, .none,
                          .none, n,
                          .none as Optional<UnsafeMutablePointer<Float64>>, 0)
            assert(0 < l)
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: n * n + 2 * n + max(n, l)) { // eigenvalues from Colleague matrix
                let z = UnsafeMutableBufferPointer(rebasing: $0.prefix(n * n))
                let r = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(n * n).prefix(n))
                let i = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(n * n + n).prefix(n))
                let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(n * n + n + n).prefix(max(n, l)))
                w[0] = 0.5.squareRoot()
                vDSP.fill(&w[1..<n], with: 0.5)
                vDSP.clear(&z[0..<n*n])
                copy(n - 1,
                     w.baseAddress.unsafelyUnwrapped, 1,
                     z.baseAddress.unsafelyUnwrapped.advanced(by: 1), n + 1)
                copy(n - 1,
                     w.baseAddress.unsafelyUnwrapped, 1,
                     z.baseAddress.unsafelyUnwrapped.advanced(by: n), n + 1)
                vDSP.divide(w[0..<n], -rawValue[n], result: &w[0..<n])
                vDSP.add(multiplication: (rawValue[0..<n], w[0..<n]),
                         z[n * n - n..<n * n],
                         result: &z[n * n - n..<n * n])
                let s = hseqr(.E, .N, n,
                              1, n,
                              z.baseAddress, n,
                              r.baseAddress, i.baseAddress,
                              .none, n,
                              w.baseAddress, w.count)
                precondition(s == 0, "Chebyshev root solve failed")
                ℂ.reserveCapacity(n)
                ℝ.reserveCapacity(n)
                var iter = zip(r, i).makeIterator()
                while let (r, i) = iter.next() {
                    if i.isZero {
                        ℝ.append(r)
                    } else if case.some((r, -i)) = iter.next() {
                        ℂ.append(.init(real: r, imag: i.magnitude))
                    } else {
                        assertionFailure()
                    }
                }
            }
        }
        return (ℂ, ℝ)
    }
    @inlinable
    var`stationary-points`: Array<Float64> {
        derivative.roots.1.filter((-1...1).contains)
    }
    @inlinable
    var minimum: (value: Float64, location: Float64) {
        concat(Array(arrayLiteral: -1.0, 1.0), `stationary-points`).lazy.map {
            (value: self($0), location: $0)
        }.min {
            $0.value < $1.value
        }.unsafelyUnwrapped
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
    var zpkMinimumPhase: Linear.ZPK {
        let p = p.rawValue
        let q = q.rawValue
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
                w.dropFirst().initialize(repeating: 0.5)
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
                    } else if case.some((r, -i)) = iter.next() { // sweep conj
                        let x = Complex128.RawValue(.init(r: r, i: i.magnitude))
                        let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
                        let lhs = add(x, s)
                        let rhs = sub(x, s)
                        let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
                        assert(length_squared(z.vector).isLess(than: 1))
                        zc.append(.init(real: z.r, imag: z.i.magnitude))
                    } else {
                        assertionFailure()
                    }
                }
            }
            if 1 < q.count {
                w[0] = 0.5.squareRoot()
                w.dropFirst().initialize(repeating: 0.5)
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
                    } else if case.some((r, -i)) = iter.next() { // sweep conj
                        let x = Complex128.RawValue(.init(r: r, i: i.magnitude))
                        let s = mul(libcsqrt(add(x, 1)), libcsqrt(sub(x, 1)))
                        let lhs = add(x, s)
                        let rhs = sub(x, s)
                        let z = div(1, length_squared(lhs.vector) < length_squared(rhs.vector) ? rhs : lhs)
                        assert(length_squared(z.vector).isLess(than: 1))
                        pc.append(.init(real: z.r, imag: z.i.magnitude))
                    } else {
                        assertionFailure()
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
