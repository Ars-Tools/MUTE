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
    @inlinable
    package init(_ coefficients: Array<Float64>) {
        rawValue = coefficients
    }
    @inlinable
    package init(degree: Int, at x: Float64) {
        assert(0 <= degree)
        rawValue = .init(unsafeUninitializedCapacity: degree + 1) {
            $1 = $0.count
            Self.basis(degree: degree, at: x, result: $0)
        }
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

    @inlinable
    static func basis(degree: Int, at x: Float64) -> Array<Float64> {
        assert(0 <= degree)
        return .init(basis(at: x).prefix(degree + 1))
    }

    /// Writes `T₀(x), …, T_degree(x)` directly into caller-owned storage.
    @inlinable
    static func basis(degree: Int,
                      at x: Float64,
                      result: UnsafeMutableBufferPointer<Float64>) {
        assert(0 <= degree)
        assert(result.count == degree + 1)
        let eof = result.update(from: basis(at: x)).index
        assert(eof == result.endIndex)
    }

    @inlinable
    func callAsFunction(_ x: Float64) -> Float64 {
        assert(!rawValue.isEmpty)
        let first = rawValue[0]
        guard 1 < rawValue.count else { return first }
        var b1 = 0.0
        var b2 = 0.0
        for coefficient in rawValue.dropFirst().reversed() {
            let b0 = coefficient + 2 * x * b1 - b2
            b2 = b1
            b1 = b0
        }
        return first + x * b1 - b2
    }

    @inlinable
    func derivative() -> Self {
        .init(.init(unsafeUninitializedCapacity: rawValue.count + 1) {
            $1 = $0.count
            $0.dropFirst(rawValue.count - 1).update(repeating: 0)
            for k in stride(from: rawValue.count - 2, through: 0, by: -1) {
                $0[k] = $0[k + 2] + 2 * Float64(k + 1) * rawValue[k + 1]
            }
            $0[0] *= 0.5
            let scale = max(1, rawValue.lazy.map(\.magnitude).max() ?? 1)
            let tolerance = 64 * Float64.ulpOfOne * scale
            while 1 < $1, $0[$1 - 1].magnitude <= tolerance {
                $1 -= 1
            }
        })
    }

    @inlinable
    func stationaryPoints(tolerance: Float64 = .ulpOfOne.squareRoot() * 256.0) -> Array<Float64> {
        switch derivative().roots() {
        case(let r, let i):
            zip(r, i).compactMap {
                (-1...1) ~= $0 && $1.magnitude <= tolerance * max(1, $0.magnitude) ? $0 : nil
            }
        }
    }

    @inlinable
    func minimum(tolerance: Float64 = .ulpOfOne.squareRoot() * 256.0) -> (value: Float64, location: Float64) {
        (.init(arrayLiteral: -1, 1) + stationaryPoints(tolerance: tolerance)).lazy.map {
            (value: self($0), location: $0)
        }.min {
            $0.value < $1.value
        }.unsafelyUnwrapped
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
extension Linear.Direct.ChebyshevPolynomial {
    @inlinable
    func roots() -> (r: ArraySlice<Float64>, i: ArraySlice<Float64>) {
        let degree = rawValue.count - 1
        let values = Array<Float64>(unsafeUninitializedCapacity: 2 * degree) {
            let r = UnsafeMutableBufferPointer(rebasing: $0[0 * degree ..< 1 * degree])
            let i = UnsafeMutableBufferPointer(rebasing: $0[1 * degree ..< 2 * degree])
            guard !r.isEmpty, !i.isEmpty else {
                $1 = 0
                return
            }
            guard 1 < degree else {
                r[0] = -rawValue[0] / rawValue[1]
                i[0] = 0
                $1 = $0.count
                return
            }
            let workspaceCount = hseqr(.E, .N, degree,
                                       1, degree,
                                       .none, degree,
                                       .none, .none,
                                       .none, degree,
                                       .none as Optional<UnsafeMutablePointer<Float64>>, 0)
            assert(0 < workspaceCount)
            withUnsafeTemporaryAllocation(of: Float64.self,
                                          capacity: degree * degree + workspaceCount) {
                vDSP.clear(&$0[0..<$0.count])
                let matrix = UnsafeMutableBufferPointer(rebasing: $0.prefix(degree * degree))
                let workspace = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(degree * degree).suffix(workspaceCount))
                workspace[0] = 0.5.squareRoot()
                vDSP.fill(&workspace[1..<degree], with: 0.5)
                copy(degree - 1,
                     workspace.baseAddress.unsafelyUnwrapped, 1,
                     matrix.baseAddress.unsafelyUnwrapped.advanced(by: 1), degree + 1)
                copy(degree - 1,
                     workspace.baseAddress.unsafelyUnwrapped, 1,
                     matrix.baseAddress.unsafelyUnwrapped.advanced(by: degree), degree + 1)
                vDSP.divide(workspace[0..<degree], -rawValue[degree], result: &workspace[0..<degree])
                vDSP.add(multiplication: (rawValue[0..<degree], workspace[0..<degree]),
                         matrix[degree * degree - degree..<degree * degree],
                         result: &matrix[degree * degree - degree..<degree * degree])
                let info = hseqr(.E, .N, degree,
                                 1, degree,
                                 matrix.baseAddress, degree,
                                 r.baseAddress, i.baseAddress,
                                 .none, degree,
                                 workspace.baseAddress, workspace.count)
                precondition(info == 0, "Chebyshev root solve failed")
            }
            $1 = $0.count
        }
        return (
            values.prefix(degree),
            values.suffix(degree)
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
