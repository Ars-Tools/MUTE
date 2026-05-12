//
//  Prototype+Papoulis.swift
//  MUTE
//
//  Created by Kota on 8/14/R7.
//
import typealias Accelerate.vDSP
import protocol DSP.Stream
import protocol DSP.Frequency
import typealias Numerics.Complex128
import simd
@preconcurrency import protocol Combine.Publisher

@inlinable
func legendre(count: Int) -> Array<Float64> {
    sequence(state: ([1.0], [1.0, 0.0])) { s in
        defer {
            (s.0, s.1) = (s.1, Array<Float64>(unsafeUninitializedCapacity: s.1.count + 1) {
                $0[s.1.count] = 0
                vDSP.multiply(.init(2 * s.1.count - 1), s.1, result: &$0[0..<s.1.count])
                vDSP.add(multiplication: (s.0, .init(1 - s.1.count)), $0[2..<2 + s.0.count], result: &$0[2..<2 + s.0.count])
                vDSP.divide($0, .init(s.1.count), result: &$0)
                $1 = $0.count
            })
        }
        return .some(s.0)
    }.dropFirst(count).prefix(1).flatMap(\.self)
}

@inlinable
func papoulisAdd(_ lhs: Array<Float64>, _ rhs: Array<Float64>) -> Array<Float64> {
    let count = max(lhs.count, rhs.count)
    let l = Array(repeating: 0.0, count: count - lhs.count) + lhs
    let r = Array(repeating: 0.0, count: count - rhs.count) + rhs
    return zip(l, r).map(+)
}

@inlinable
func papoulisMultiply(_ lhs: Array<Float64>, _ rhs: Array<Float64>) -> Array<Float64> {
    var result = Array(repeating: 0.0, count: lhs.count + rhs.count - 1)
    for (i, x) in lhs.enumerated() {
        for (j, y) in rhs.enumerated() {
            result[i + j] += x * y
        }
    }
    return result
}

@inlinable
func papoulisScale(_ lhs: Array<Float64>, by scalar: Float64) -> Array<Float64> {
    lhs.map { scalar * $0 }
}

@inlinable
func papoulisIntegrate(_ lhs: Array<Float64>) -> Array<Float64> {
    let degree = lhs.count - 1
    return lhs.enumerated().map { offset, value in
        value / Float64(degree - offset + 1)
    } + [0]
}

@inlinable
func papoulisEvaluate(_ lhs: Array<Float64>, at x: Float64) -> Float64 {
    lhs.reduce(0) { fma($0, x, $1) }
}

@inlinable
func papoulisCompose(_ lhs: Array<Float64>, affine: SIMD2<Float64>) -> Array<Float64> {
    lhs.reduce([0.0]) { partial, coefficient in
        papoulisAdd(
            papoulisMultiply(partial, [affine.x, affine.y]),
            [coefficient]
        )
    }
}

@inlinable
func papoulisPolynomial(order n: Int) -> Array<Float64> {
    precondition(n > 0)
    let k = n.isMultiple(of: 2) ? (n - 2) / 2 : (n - 1) / 2
    let phi = (0...k).reduce([0.0]) { partial, i in
        let a: Float64
        if n.isMultiple(of: 2) {
            let parity = k.isMultiple(of: 2)
            guard i.isMultiple(of: 2) == parity else { return partial }
            a = Float64(2 * i + 1) / sqrt(Float64((k + 1) * (k + 2)))
        } else {
            a = Float64(2 * i + 1) / sqrt(2 * Float64(k + 1))
        }
        return papoulisAdd(partial, papoulisScale(legendre(count: i), by: a))
    }
    let integrand = {
        let square = papoulisMultiply(phi, phi)
        if n.isMultiple(of: 2) {
            return papoulisMultiply([1, 1], square)
        }
        return papoulisScale(square, by: 2 / Float64(n + 1))
    }()
    let integral = papoulisIntegrate(integrand)
    let shifted = papoulisCompose(integral, affine: SIMD2<Float64>(2, -1))
    var polynomial = shifted
    polynomial[polynomial.endIndex - 1] -= papoulisEvaluate(integral, at: -1)
    return polynomial
}

@inlinable
func papoulisCharacteristic(order n: Int) -> Array<Float64> {
    let l = papoulisPolynomial(order: n)
    let u = Array(l.reversed())
    var s = Array(repeating: 0.0, count: 2 * n + 1)
    s[s.endIndex - 1] = 1
    for (power, coefficient) in u.enumerated().dropFirst() {
        s[2 * n - 2 * power] += power.isMultiple(of: 2) ? coefficient : -coefficient
    }
    return s
}

@inlinable
func papoulisPoles(order n: Int) -> Array<Complex128> {
    let tolerance = sqrt(Float64.ulpOfOne)
    let poles = roots(poly: papoulisCharacteristic(order: n)).filter {
        $0.real < -tolerance
    }
    assert(poles.count == n)
    return poles
}

@inlinable // SOS
func papoulis(lpf order: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
    let tolerance = sqrt(Float64.ulpOfOne)
    let poles = papoulisPoles(order: order)
    let H1 = poles
        .filter { $0.imag.magnitude < tolerance }
        .map { pole in
            let alpha = -pole.real
            return (SIMD2<Float64>(0, alpha), SIMD2<Float64>(1, alpha))
        }
    let H2 = poles
        .filter { $0.imag > tolerance }
        .map { pole in
            let alpha = -2 * pole.real
            let beta = pole.magnitudeSquared
            return (SIMD3<Float64>(0, 0, beta), SIMD3<Float64>(1, alpha, beta))
        }
    return (H1, H2)
}

@inlinable // SOS
func papoulis(hpf order: Int) -> (Array<(SIMD2<Float64>, SIMD2<Float64>)>, Array<(SIMD3<Float64>, SIMD3<Float64>)>) {
    let tolerance = sqrt(Float64.ulpOfOne)
    let poles = papoulisPoles(order: order)
    let H1 = poles
        .filter { $0.imag.magnitude < tolerance }
        .map { pole in
            let alpha = -pole.real
            return (SIMD2<Float64>(alpha, 0), SIMD2<Float64>(alpha, 1))
        }
    let H2 = poles
        .filter { $0.imag > tolerance }
        .map { pole in
            let alpha = -2 * pole.real
            let beta = pole.magnitudeSquared
            return (SIMD3<Float64>(beta, 0, 0), SIMD3<Float64>(beta, alpha, 1))
        }
    return (H1, H2)
}

public func filter(_ source: Stream, lpf omega0: some Publisher<(Int, Frequency), Never> & Sendable, papoulis order: Int) -> some Stream {
    let (H1, H2) = papoulis(lpf: order)
    assert(H1.count + 2 * H2.count == order)
    return Prototype.Kr(x0: source, ω0: omega0, H₁: H1, H₂: H2)
}

public func filter(_ source: Stream, lpf omega0: some Publisher<Frequency, Never>, papoulis order: Int) -> some Stream {
    filter(source, lpf: omega0.repeat(count: source.count), papoulis: order)
}

public func filter(_ source: Stream, lpf omega0: some Sequence<Frequency>, papoulis order: Int) -> some Stream {
    filter(source, lpf: omega0.prefix(count: source.count), papoulis: order)
}

public func filter(_ source: Stream, lpf omega0: Frequency, papoulis order: Int) -> some Stream {
    filter(source, lpf: `repeat`(omega0, count: source.count), papoulis: order)
}

public func filter(_ source: Stream, lpf omega0: Stream, papoulis order: Int) -> some Stream {
    let (H1, H2) = papoulis(lpf: order)
    assert(H1.count + 2 * H2.count == order)
    return Prototype.Ar(x0: source, ω0: omega0, H₁: H1, H₂: H2)
}

public func filter(_ source: Stream, hpf omega0: some Publisher<(Int, Frequency), Never> & Sendable, papoulis order: Int) -> some Stream {
    let (H1, H2) = papoulis(hpf: order)
    assert(H1.count + 2 * H2.count == order)
    return Prototype.Kr(x0: source, ω0: omega0, H₁: H1, H₂: H2)
}

public func filter(_ source: Stream, hpf omega0: some Publisher<Frequency, Never>, papoulis order: Int) -> some Stream {
    filter(source, hpf: omega0.repeat(count: source.count), papoulis: order)
}

public func filter(_ source: Stream, hpf omega0: some Sequence<Frequency>, papoulis order: Int) -> some Stream {
    filter(source, hpf: omega0.prefix(count: source.count), papoulis: order)
}

public func filter(_ source: Stream, hpf omega0: Frequency, papoulis order: Int) -> some Stream {
    filter(source, hpf: `repeat`(omega0, count: source.count), papoulis: order)
}

public func filter(_ source: Stream, hpf omega0: Stream, papoulis order: Int) -> some Stream {
    let (H1, H2) = papoulis(hpf: order)
    assert(H1.count + 2 * H2.count == order)
    return Prototype.Ar(x0: source, ω0: omega0, H₁: H1, H₂: H2)
}
