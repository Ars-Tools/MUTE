//
//  Prototype.swift
//  MUTE
//
//  Created by Kota on 8/13/R7.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func Accelerate.vecLib.vDSP_deq22D
import func BLAS.gemv
import func BLAS.gemm
import typealias CoreMedia.CMTime
import protocol DSP.Stream
import protocol DSP.Frequency
import typealias DSP.Filter
import typealias DSP.Instance
import func DSP.filter
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import simd
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Publishers
@preconcurrency import typealias Combine.Just
@usableFromInline
enum Prototype {
    @usableFromInline
    enum TransferFunction: Sendable {
        @usableFromInline
        struct Rn<Cutoff: Publisher<Frequency, Never> & Sendable> {
            @usableFromInline let ω₀: Cutoff
            @usableFromInline let Bₛ: Array<Float64>
            @usableFromInline let Aₛ: Array<Float64>
        }
        @usableFromInline
        struct Ar {
            @usableFromInline let ω₀: Stream
            @usableFromInline let Bₛ: Array<Float64>
            @usableFromInline let Aₛ: Array<Float64>
        }
    }
    @usableFromInline
    enum BiquadSeries: Sendable {
        @usableFromInline
        struct Rn<Cutoff: Publisher<Frequency, Never> & Sendable> {
            @usableFromInline let ω₀: Cutoff
            @usableFromInline let Hₛ: Array<(bₛ: SIMD3<Float64>, aₛ: SIMD3<Float64>)>
        }
        @usableFromInline
        struct Ar {
            @usableFromInline let ω₀: Stream
            @usableFromInline let Hₛ: Array<(bₛ: SIMD3<Float64>, aₛ: SIMD3<Float64>)>
        }
    }
	@usableFromInline
    enum BLT {
        @usableFromInline
        struct Kr<Cutoff: Publisher<Frequency, Never> & Sendable> {
            @usableFromInline let ω₀: Cutoff
            @usableFromInline let Bₛ: Stream
            @usableFromInline let Aₛ: Stream
        }
        @usableFromInline
        struct Ar {
            @usableFromInline let ω₀: Stream
            @usableFromInline let Bₛ: Stream
            @usableFromInline let Aₛ: Stream
        }
    }
}
extension Prototype.TransferFunction {
    @inlinable
    static func Krawtchouk(size n: Int, target: UnsafeMutableBufferPointer<Float64>) {
        precondition(0 < n)
        guard case(let count, false) = n.multipliedReportingOverflow(by: n) else {
            preconditionFailure()
        }
        precondition(count <= target.count)
        target[0] = 1
        for r in 1..<n {
            target[r] = -target[r - 1] * Float64(n - r) / Float64(r)
        }
        for offset in stride(from: n, to: count, by: n) {
            target[offset] = 1
            target[offset + 1] = target[offset + 1 - n] + 2
            vDSP.twoPoleTwoZeroFilter(
                target[offset - n ..< offset],
                coefficients: (1, 1, 0, -1, 0),
                result: &target[offset ..< offset + n]
            )
        }
    }
    @inlinable
    static func Krawtchouk(size n: Int) -> Array<Float64> {
        .init(unsafeUninitializedCapacity: n * n) {
            $1 = $0.count
            Krawtchouk(size: n, target: $0)
        }
    }
    @inlinable // ω is [0, 1) normalized angular frequency, 0.5 = π, 1 = 2π
    static func BLT(prewarping ω: Float64, size n: Int, target: UnsafeMutableBufferPointer<Float64>) {
        guard case(let n², false) = n.multipliedReportingOverflow(by: n) else {
            preconditionFailure()
        }
        Krawtchouk(size: n, target: target)
        let θ = ω.remainder(dividingBy: 1)
        let γ = θ.magnitude
        switch γ {
        case 0:
            vDSP.clear(&target[0+n..<n²])
        case 0.5:
            vDSP.clear(&target[0..<n²-n])
        case 0.25...:
            let k = __tanpi(copysign(0.5 - γ, θ))
            for (c, s) in zip(stride(from: n²-n, to: 0, by: -n), sequence(first: k) { .some($0 * k) }) {
                vDSP.multiply(s, target[c-n..<c], result: &target[c-n..<c])
            }
        default:
            let k = __tanpi(θ)
            for (c, s) in zip(stride(from: n, to: n²-0, by: +n), sequence(first: k) { .some($0 * k) }) {
                vDSP.multiply(s, target[c..<c+n], result: &target[c..<c+n])
            }
        }
    }
    @inlinable // ω is [0, 1) normalized angular frequency, 0.5 = π, 1 = 2π
    static func BLT(prewarping ω: Float64, size n: Int) -> Array<Float64> {
        guard case(let capacity, false) = n.multipliedReportingOverflow(by: n) else {
            preconditionFailure()
        }
        return.init(unsafeUninitializedCapacity: capacity) {
            $1 = $0.count
            BLT(prewarping: ω, size: n, target: $0)
        }
    }
}
extension Prototype.TransferFunction.Rn: Filter.TransferFunction {
    @usableFromInline typealias B = Array<Float64>
    @usableFromInline typealias A = Array<Float64>
    @inlinable
    func coefficients(for Tₛ: CMTime) -> Publishers.Map<Cutoff, (b: B, a: A)> {
        let n = max(Bₛ.count, Aₛ.count)
        guard case(let capacity, false) = n.multipliedReportingOverflow(by: n) else {
            preconditionFailure()
        }
        return ω₀.map { ω in
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: capacity) { m in
                Prototype.TransferFunction.BLT(prewarping: ω.increment(for: Tₛ), size: n, target: m)
                return (
                    .init(unsafeUninitializedCapacity: n) {
                        $1 = $0.count
                        gemv($1, Bₛ.count, 1,
                             m.baseAddress.unsafelyUnwrapped, $1, .N,
                             Bₛ, 1,
                             0,
                             $0.baseAddress.unsafelyUnwrapped, 1)
                    },
                    .init(unsafeUninitializedCapacity: n) {
                        $1 = $0.count
                        gemv($1, Aₛ.count, 1,
                             m.baseAddress.unsafelyUnwrapped, $1, .N,
                             Aₛ, 1,
                             0,
                             $0.baseAddress.unsafelyUnwrapped, 1)
                    },
                )
            }
        }
        
    }
    @inlinable
    var counts: SIMD2<Int> {
        .init(repeating: max(Bₛ.count, Aₛ.count))
    }
}
extension Prototype.TransferFunction.Ar: DSP.Stream {
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        guard ω₀.count == 1, !Bₛ.isEmpty, !Aₛ.isEmpty else { throw Error.invalidChannel }
        switch max(Bₛ.count, Aₛ.count) {
        case 1:
            guard case.some(let b) = Bₛ.first, case.some(let a) = Aₛ.first else {
                throw Error.unmatchChannel
            }
            return {
                vDSP.fill(&UnsafeMutableBufferPointer(start: $2.advanced(by: 0 * $3), count: $1)[0..<$1], with: b)
                vDSP.fill(&UnsafeMutableBufferPointer(start: $2.advanced(by: 1 * $3), count: $1)[0..<$1], with: a)
            }
        case 2:
            guard case.some(let b₀) = Bₛ.first, case.some(let a₀) = Aₛ.first else {
                throw Error.unmatchChannel
            }
            let ω = try ω₀(interval: interval, capacity: capacity, instance: &instance)
            let b₁ = Bₛ.dropFirst().first ?? .zero
            let a₁ = Aₛ.dropFirst().first ?? .zero
            let Fₛ = interval.seconds
            return {
                ω($0, $1, $2, $3)
                let buffer = UnsafeMutableBufferPointer<Float64>(start: $2, count: 3 * $3 + $1)
                vDSP.multiply(Fₛ, buffer[0..<$1], result: &buffer[0..<$1])
                vForce.tanPi(buffer[0..<$1], result: &buffer[0..<$1])
                vDSP.add(multiplication: (buffer[0..<$1], a₁), -a₀, result: &buffer[3*$3..<3*$3+$1])
                vDSP.add(multiplication: (buffer[0..<$1], a₁),  a₀, result: &buffer[2*$3..<2*$3+$1])
                vDSP.add(multiplication: (buffer[0..<$1], b₁), -b₀, result: &buffer[1*$3..<1*$3+$1])
                vDSP.add(multiplication: (buffer[0..<$1], b₁),  b₀, result: &buffer[0*$3..<0*$3+$1])
            }
        case let n:assert(2 < n)
            let ω = try ω₀(interval: interval, capacity: capacity, instance: &instance)
            let m = ( n - 1 ) / 2
            let Fₛ = interval.seconds
            let Kₛ = Prototype.TransferFunction.Krawtchouk(size: n)
            return { [Bₛ, Aₛ] moment, length, target, stride in
                ω(moment, length, target, stride)
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( 2 * n ) * length) {
                    let x = UnsafeMutableBufferPointer<Float64>(rebasing: $0[(0)*length..<(m+0)*length]) // cot
                    let z = UnsafeMutableBufferPointer<Float64>(rebasing: $0[(m)*length..<(m+1)*length]) // 1
                    let y = UnsafeMutableBufferPointer<Float64>(rebasing: $0[(m+1)*length..<(n)*length]) // tan
                    let w = UnsafeMutableBufferPointer<Float64>(rebasing: $0.suffix(n * length)) // workspace
                    vDSP.multiply(Fₛ, UnsafeBufferPointer<Float64>(start: target, count: length), result: &y[0..<length])
                    vDSP.add(multiplication: (y[0..<length], -1), 0.5, result: &x[m*length-length..<m*length])
                    vForce.tanPi(y[0..<length], result: &y[0..<length])
                    vForce.tanPi(x[m*length-length..<m*length], result: &x[m*length-length..<m*length])
                    for k in Swift.stride(from: x.count - length, to: 0, by: -length) { // x, lower
                        vDSP.multiply(x[x.count-length..<x.count],
                                      x[k..<k+length],
                                      result: &x[k-length..<k])
                    }
                    for k in Swift.stride(from: length, to: y.count, by: length) { // y, upper
                        vDSP.multiply(y[0..<length],
                                      y[k-length..<k],
                                      result: &y[k..<k+length])
                    }
                    vDSP.fill(&z[0..<length], with: 1)
                    for (k, b) in Bₛ.enumerated() {
                        vDSP.multiply(b,
                                      $0[k*length..<k*length+length],
                                      result: &w[k*length..<k*length+length])
                    }
                    gemm(length, n, Bₛ.count,
                         1,
                         w.baseAddress.unsafelyUnwrapped, length, .N,
                         Kₛ, n, .T,
                         0,
                         target.advanced(by: 0 * stride), stride)
                    for (k, a) in Aₛ.enumerated() {
                        vDSP.multiply(a,
                                      $0[k*length..<k*length+length],
                                      result: &w[k*length..<k*length+length])
                    }
                    gemm(length, n, Aₛ.count,
                         1,
                         w.baseAddress.unsafelyUnwrapped, length, .N,
                         Kₛ, n, .T,
                         0,
                         target.advanced(by: n * stride), stride)
                }
            }
        }
    }
    @inlinable
    var count: Int {
        2 * max(Bₛ.count, Aₛ.count)
    }
}
extension Prototype.BiquadSeries {
    @usableFromInline
    static let Krawtchouk = matrix_double3x3(columns: (
        .init( 1, -2,  1),
        .init( 1,  0, -1),
        .init( 1,  2,  1)
    ))
    @inlinable
    static func BLT(prewarping ω: Float64) -> matrix_double3x3 {
        let θ = ω.remainder(dividingBy: 1)
        let γ = θ.magnitude
        switch γ {
        case 0:
            return.init(columns: (
                Krawtchouk.columns.0,
                .zero,
                .zero
            ))
        case 0.5:
            return.init(columns: (
                .zero,
                .zero,
                Krawtchouk.columns.2
            ))
        case 0.25...:
            let k = __tanpi(copysign(0.5 - γ, θ))
            return.init(columns: (
                Krawtchouk.columns.0 * k * k,
                Krawtchouk.columns.1 * k,
                Krawtchouk.columns.2
            ))
        default:
            let k = __tanpi(θ)
            return.init(columns: (
                Krawtchouk.columns.0,
                Krawtchouk.columns.1 * k,
                Krawtchouk.columns.2 * k * k
            ))
        }
    }
}
extension Prototype.BiquadSeries.Rn: DSP.Filter.BiquadSeries {
    @usableFromInline typealias Biquad = Array<(b: SIMD3<Scalar>, a: SIMD3<Scalar>)>
    @usableFromInline typealias Sections = Publishers.Map<Cutoff, (Range<Int>, Biquad)>
    @usableFromInline typealias A = Array<Scalar>
    @usableFromInline typealias B = Array<Scalar>
    @usableFromInline typealias Scalar = Float64
    @inlinable
    func sections(for Tₛ: CMTime) -> Sections {
        let H = Hₛ.map(simd_double2x3.init(columns:))
        return ω₀.map {
            let Mₛ = Prototype.BiquadSeries.BLT(prewarping: $0.increment(for: Tₛ))
            return (0..<H.count, H.map { Mₛ * $0 }.map(\.columns))
        }
    }
    @inlinable
    var count: Int {
        Hₛ.count
    }
}
extension Prototype.BiquadSeries.Ar: DSP.Stream {
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        guard ω₀.count == 1 else { throw Error.invalidChannel }
        let ω = try ω₀(interval: interval, capacity: capacity, instance: &instance)
        let (ldKₛ, r) = MemoryLayout<SIMD3<Float64>>.stride.quotientAndRemainder(dividingBy: MemoryLayout<Float64>.size)
        assert(r == 0)
        let Kₛ = withUnsafeBytes(of: Prototype.BiquadSeries.Krawtchouk) {
            $0.withMemoryRebound(to: Float64.self, Array.init)
        }
        assert(Kₛ.count == 3 * ldKₛ)
        let Fₛ = interval.seconds
        return { [Hₛ] moment, length, target, stride in
            ω(moment, length, target, stride)
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: 5 * length) {
                vDSP.multiply(Fₛ, UnsafeBufferPointer(start: target, count: length), result: &$0[4*length..<5*length])
                vDSP.add(multiplication: ($0[4*length..<5*length], -1), 0.5, result: &$0[3*length..<4*length])
                vForce.tanPi($0[3*length..<5*length], result: &$0[3*length..<5*length])
                for (k, (b, a)) in Hₛ.enumerated() {
                    vDSP.multiply(b.x, $0[3*length..<4*length], result: &$0[0*length..<1*length])
                    vDSP.fill(&$0[1*length..<2*length], with: b.y)
                    vDSP.multiply(b.z, $0[4*length..<5*length], result: &$0[2*length..<3*length])
                    gemm(length, 3, 3,
                         1,
                         $0.baseAddress.unsafelyUnwrapped, length, .N,
                         Kₛ, ldKₛ, .T,
                         0,
                         target.advanced(by: (6 * k + 0) * stride), stride)
                    vDSP.multiply(a.x, $0[3*length..<4*length], result: &$0[0*length..<1*length])
                    vDSP.fill(&$0[1*length..<2*length], with: a.y)
                    vDSP.multiply(a.z, $0[4*length..<5*length], result: &$0[2*length..<3*length])
                    gemm(length, 3, 3,
                         1,
                         $0.baseAddress.unsafelyUnwrapped, length, .N,
                         Kₛ, ldKₛ, .T,
                         0,
                         target.advanced(by: (6 * k + 3) * stride), stride)
                }
            }
        }
    }
    @inlinable
    var count: Int {
        6 * Hₛ.count
    }
}
extension Prototype.BLT.Kr: DSP.Stream {
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let Nₛ = SIMD2<Int>(Bₛ.count, Aₛ.count)
        guard (0 .< Nₛ) == .init(repeating: true) else { throw Error.invalidChannel }
        let B = try Bₛ(interval: interval, capacity: capacity, instance: &instance)
        let A = try Aₛ(interval: interval, capacity: capacity, instance: &instance)
        switch Nₛ.max() as Int {
        case 1:
            return {
                B($0, $1, $2.advanced(by: 0 * $3), $3)
                A($0, $1, $2.advanced(by: 1 * $3), $3)
            }
        case 2:
            let K = Atomic<Float64>(0)
            let cancel = ω₀.sink {
                K.store(__tanpi($0.increment(for: interval)), ordering: .relaxed)
            }
            instance.store(cancel, interval: interval, capacity: capacity)
            return {
                let k = K.load(ordering: .relaxed)
                let b = UnsafeMutableBufferPointer(start: $2.advanced(by: 0 * $3), count: $3 + $1)
                let a = UnsafeMutableBufferPointer(start: $2.advanced(by: 2 * $3), count: $3 + $1)
                vDSP.clear(&b[$3..<$3+$1])
                B($0, $1, b.baseAddress.unsafelyUnwrapped, $3)
                vDSP.multiply(k, b[$3..<$3+$1], result: &b[$3..<$3+$1])
                vDSP.addSubtract(b[$3..<$3+$1], b[0..<$1],
                                 addResult: &b[0..<$1],
                                 subtractResult: &b[$3..<$3+$1])
                vDSP.clear(&a[$3..<$3+$1])
                A($0, $1, a.baseAddress.unsafelyUnwrapped, $3)
                vDSP.multiply(k, a[$3..<$3+$1], result: &a[$3..<$3+$1])
                vDSP.addSubtract(a[$3..<$3+$1], a[0..<$1],
                                 addResult: &a[0..<$1],
                                 subtractResult: &a[$3..<$3+$1])
            }
        case let N:
            let Kₛ = switch N.multipliedReportingOverflow(by: N) {
            case(let N², false):
                Mutex<Array<Float64>>(.init(unsafeUninitializedCapacity: N²) {
                    $1 = $0.count
                    $0.prefix(1).initialize(repeating: 1)
                    $0.dropFirst().initialize(repeating: .zero)
                })
            default:
                throw Error.lackOfResource("Kₛ")
            }
            let cancel = ω₀.sink {
                let ω = $0.increment(for: interval)
                Kₛ.withLock {
                    $0.withUnsafeMutableBufferPointer {
                        Prototype.TransferFunction.BLT(prewarping: ω, size: N, target: $0)
                    }
                }
            }
            instance.store(cancel, interval: interval, capacity: capacity)
            return { moment, length, target, stride in
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: N * length) {
                    guard case.some(let W) = $0.baseAddress else { return }
                    let K = Kₛ.withLock(\.self)
                    B(moment, length, W, length)
                    gemm(length, N, Bₛ.count,
                         1,
                         W, length, .N,
                         K, N, .T,
                         0,
                         target.advanced(by: 0 * stride), stride)
                    A(moment, length, W, length)
                    gemm(length, N, Aₛ.count,
                         1,
                         W, length, .N,
                         K, N, .T,
                         0,
                         target.advanced(by: N * stride), stride)
                }
            }
        }
    }
    @inlinable
    var count: Int {
        2 * max(Bₛ.count, Aₛ.count)
    }
}
extension Prototype.BLT.Ar: DSP.Stream {
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let Nₛ = SIMD2<Int>(Bₛ.count, Aₛ.count)
        guard (0 .< Nₛ) == .init(repeating: true), ω₀.count == 1 else { throw Error.invalidChannel }
        let ω = try ω₀(interval: interval, capacity: capacity, instance: &instance)
        let B = try Bₛ(interval: interval, capacity: capacity, instance: &instance)
        let A = try Aₛ(interval: interval, capacity: capacity, instance: &instance)
        let Fₛ = interval.seconds
        switch Nₛ.max() as Int {
        case 1:
            return {
                B($0, $1, $2.advanced(by: 0 * $3), $3)
                A($0, $1, $2.advanced(by: 1 * $3), $3)
            }
        case 2:
            return { moment, length, target, stride in
                ω(moment, length, target, length)
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: length) { K in
                    vDSP.multiply(Fₛ, UnsafeBufferPointer(start: target, count: length), result: &K[0..<length])
                    vForce.tanPi(K, result: &K[0..<length])
                    let b = UnsafeMutableBufferPointer(start: target.advanced(by: 0 * stride), count: stride + length)
                    let a = UnsafeMutableBufferPointer(start: target.advanced(by: 2 * stride), count: stride + length)
                    vDSP.clear(&b[stride..<stride+length])
                    B(moment, length, b.baseAddress.unsafelyUnwrapped, stride)
                    vDSP.multiply(K, b[stride..<stride+length], result: &b[stride..<stride+length])
                    vDSP.addSubtract(b[stride..<stride+length], b[0..<length],
                                     addResult: &b[0..<length],
                                     subtractResult: &b[stride..<stride+length])
                    vDSP.clear(&a[stride..<stride+length])
                    A(moment, length, a.baseAddress.unsafelyUnwrapped, stride)
                    vDSP.multiply(K, a[stride..<stride+length], result: &a[stride..<stride+length])
                    vDSP.addSubtract(a[stride..<stride+length], a[0..<length],
                                     addResult: &a[0..<length],
                                     subtractResult: &a[stride..<stride+length])
                }
            }
        case let N:
            let Kₛ = Prototype.TransferFunction.Krawtchouk(size: N)
            return { moment, length, target, stride in
                ω(moment, length, target, length)
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( N + 2 ) * length) {
                    let W = UnsafeMutableBufferPointer(rebasing: $0.prefix(N * length))
                    let K = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(N * length).prefix(length))
                    let k = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(N * length).suffix(length))
                    vDSP.multiply(Fₛ, UnsafeBufferPointer(start: target, count: length), result: &k[0..<length])
                    vForce.tanPi(k, result: &k[0..<length])
                    B(moment, length, W.baseAddress.unsafelyUnwrapped, length)
                    vDSP.fill(&K[0..<length], with: 1)
                    for offset in Swift.stride(from: length, to: Nₛ.x * length, by: length) {
                        vDSP.multiply(k, K[0..<length], result: &K[0..<length])
                        vDSP.multiply(K, W[offset..<offset+length], result: &W[offset..<offset+length])
                    }
                    gemm(length, N, Bₛ.count,
                         1,
                         W.baseAddress.unsafelyUnwrapped, length, .N,
                         Kₛ, N, .T,
                         0,
                         target.advanced(by: 0 * stride), stride)
                    A(moment, length, W.baseAddress.unsafelyUnwrapped, length)
                    vDSP.fill(&K[0..<length], with: 1)
                    for offset in Swift.stride(from: length, to: Nₛ.y * length, by: length) {
                        vDSP.multiply(K, k[0..<length], result: &K[0..<length])
                        vDSP.multiply(K, W[offset..<offset+length], result: &W[offset..<offset+length])
                    }
                    gemm(length, N, Aₛ.count,
                         1,
                         W.baseAddress.unsafelyUnwrapped, length, .N,
                         Kₛ, N, .T,
                         0,
                         target.advanced(by: N * stride), stride)
                }
            }
        }
    }
    @inlinable
    var count: Int {
        2 * max(Bₛ.count, Aₛ.count)
    }
}
// MARK: TransferFunction
@inline(__always)@_transparent
func filter(_ source: Stream,
            ω₀: some Publisher<(Int, Frequency), Never>,
            Bₛ: Array<Float64>,
            Aₛ: Array<Float64>) -> some DSP.Stream {
    filter(source,
           iir: repeatElement(ω₀, count: source.count).enumerated().publisher.map { k, y in
        (k, Prototype.TransferFunction.Rn(ω₀: y.compactMap {
            k == $0 ? .some($1) : .none
        }, Bₛ: Bₛ, Aₛ: Aₛ))
    }, counts: .init(repeating: max(Bₛ.count, Aₛ.count)))
}
@inline(__always)@_transparent
func filter(_ source: Stream,
            ω₀: some Publisher<Frequency, Never> & Sendable,
            Bₛ: Array<Float64>,
            Aₛ: Array<Float64>) -> some DSP.Stream {
    filter(source,
           iir: Prototype.TransferFunction.Rn(ω₀: ω₀, Bₛ: Bₛ, Aₛ: Aₛ))
}
@inline(__always)@_transparent
func filter(_ source: Stream,
            ω₀: some Sequence<Frequency>,
            Bₛ: Array<Float64>,
            Aₛ: Array<Float64>) -> some DSP.Stream {
    filter(source,
           iir: ω₀.lazy.map {
        Prototype.TransferFunction.Rn(ω₀: Just($0), Bₛ: Bₛ, Aₛ: Aₛ)
    })
}
@inline(__always)@_transparent
func filter(_ source: Stream,
            ω₀: Frequency,
            Bₛ: Array<Float64>,
            Aₛ: Array<Float64>) -> some DSP.Stream {
    filter(source,
           iir: Prototype.TransferFunction.Rn(ω₀: Just(ω₀), Bₛ: Bₛ, Aₛ: Aₛ)
    )
}
@inline(__always)@_transparent@_disfavoredOverload
func filter(_ source: Stream,
            ω₀: Frequency...,
            Bₛ: Array<Float64>,
            Aₛ: Array<Float64>) -> some DSP.Stream {
    filter(source, ω₀: ω₀, Bₛ: Bₛ, Aₛ: Aₛ)
}
@inline(__always)@_transparent
func filter(_ source: Stream,
            ω₀: Stream,
            Bₛ: Array<Float64>,
            Aₛ: Array<Float64>) -> some DSP.Stream {
    filter(source, iir: Prototype.TransferFunction.Ar(ω₀: ω₀, Bₛ: Bₛ, Aₛ: Aₛ), counts: .init(repeating: max(Bₛ.count, Aₛ.count)))
}
// MARK: BiquadSeries
@inline(__always)@_transparent
func filter(_ source: Stream,
            ω₀: some Publisher<(Int, Frequency), Never>,
            H₁: some Sequence<(SIMD2<Float64>, SIMD2<Float64>)>,
            H₂: some Sequence<(SIMD3<Float64>, SIMD3<Float64>)>) -> some DSP.Stream {
    let Hₛ = H₂ + H₁.map { (SIMD3<Float64>($0.x, $0.y, 0), SIMD3<Float64>($1.x, $1.y, 0)) }
    return filter(source,
                  sos: repeatElement(ω₀, count: source.count).enumerated().publisher.map { k, ω in
        (k, Prototype.BiquadSeries.Rn(ω₀: ω.compactMap {
            $0 == k ? .some($1) : .none
        }, Hₛ: Hₛ))
    }, count: Hₛ.count)
}
@inline(__always)@_transparent
func filter(_ source: Stream,
            ω₀: some Publisher<Frequency, Never> & Sendable,
            H₁: some Sequence<(SIMD2<Float64>, SIMD2<Float64>)>,
            H₂: some Sequence<(SIMD3<Float64>, SIMD3<Float64>)>) -> some DSP.Stream {
    let Hₛ = H₂ + H₁.map { (SIMD3<Float64>($0.x, $0.y, 0), SIMD3<Float64>($1.x, $1.y, 0)) }
    return filter(source, sos: Prototype.BiquadSeries.Rn(ω₀: ω₀, Hₛ: Hₛ))
}
@inline(__always)@_transparent
func filter(_ source: Stream,
            ω₀: some Sequence<Frequency>,
            H₁: some Sequence<(SIMD2<Float64>, SIMD2<Float64>)>,
            H₂: some Sequence<(SIMD3<Float64>, SIMD3<Float64>)>) -> some DSP.Stream {
    let Hₛ = H₂ + H₁.map { (SIMD3<Float64>($0.x, $0.y, 0), SIMD3<Float64>($1.x, $1.y, 0)) }
    return filter(source, sos: ω₀.lazy.map {
        Prototype.BiquadSeries.Rn(ω₀: Just($0), Hₛ: Hₛ)
    }, count: .some(Hₛ.count))
}
@inline(__always)@_transparent@_disfavoredOverload
func filter(_ source: Stream,
            ω₀: Frequency,
            H₁: some Sequence<(SIMD2<Float64>, SIMD2<Float64>)>,
            H₂: some Sequence<(SIMD3<Float64>, SIMD3<Float64>)>) -> some DSP.Stream {
    let Hₛ = H₂ + H₁.map { (SIMD3<Float64>($0.x, $0.y, 0), SIMD3<Float64>($1.x, $1.y, 0)) }
    return filter(source, sos: Prototype.BiquadSeries.Rn(ω₀: Just(ω₀), Hₛ: Hₛ))
}
@inline(__always)@_transparent@_disfavoredOverload
func filter(_ source: Stream,
            ω₀: Frequency...,
            H₁: some Sequence<(SIMD2<Float64>, SIMD2<Float64>)>,
            H₂: some Sequence<(SIMD3<Float64>, SIMD3<Float64>)>) -> some DSP.Stream {
    filter(source, ω₀: ω₀, H₁: H₁, H₂: H₂)
}
@inline(__always)@_transparent
func filter(_ source: Stream,
            ω₀: Stream,
            H₁: some Sequence<(SIMD2<Float64>, SIMD2<Float64>)>,
            H₂: some Sequence<(SIMD3<Float64>, SIMD3<Float64>)>) -> some DSP.Stream {
    let Hₛ = H₂ + H₁.map { (SIMD3<Float64>($0.x, $0.y, 0), SIMD3<Float64>($1.x, $1.y, 0)) }
    return filter(source, sos: Prototype.BiquadSeries.Ar(ω₀: ω₀, Hₛ: Hₛ))
}
//extension Prototype.BLT {
//    @inlinable
//    static func Matrix(size n: Int, target: UnsafeMutableBufferPointer<Float64>) {
//        withUnsafeTemporaryAllocation(of: Int32.self, capacity: 3 * n * n) {
//            let lhs = $0.extracting(1 * n * n ..< 2 * n * n)
//            let rhs = $0.extracting(2 * n * n ..< 3 * n * n)
//            $0.initialize(repeating: .zero)
//            lhs[0] = 1
//            rhs[0] = 1
//            for (k, j) in stride(from: 0, to: n * n, by: n).dropLast().enumerated() {
//                for i in j...j+k {
//                    lhs[i+n+0] &+= lhs[i]
//                    rhs[i+n+0] &+= rhs[i]
//                }
//                for i in j...j+k {
//                    lhs[i+n+1] &+= lhs[i]
//                    rhs[i+n+1] &-= rhs[i]
//                }
//            }
//            for (p, q) in (0..<n).reversed().enumerated() {
//                let lhs = lhs[p*n...p*n+p]
//                let rhs = rhs[q*n...q*n+q]
//                for (s, t) in lhs.enumerated() {
//                    for (u, v) in rhs.enumerated() {
//                        $0[p*n+s+u] &+= t &* v
//                    }
//                }
//            }
//            assert(n * n <= target.count)
//            vDSP.convertElements(of: $0.prefix(n * n),
//                                 to: &target[target.startIndex..<target.startIndex.advanced(by: n * n)])
//        }
//    }
//    @inlinable
//    static func Matrix(size n: Int) -> Array<Float64> {
//        .init(unsafeUninitializedCapacity: n * n) {
//            $1 = $0.count
//            Matrix(size: n, target: $0)
//        }
//    }
//}
//extension Prototype.BLT: DSP.Stream {
//	@inlinable
//	var count: Int {
//		2 * max(Bₛ.count, Aₛ.count)
//	}
//	@inlinable
//	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//		guard ω₀.count == 1 else { throw Error.invalidChannel }
//		guard Bₛ.count == Aₛ.count else { throw Error.unmatchChannel }
//		switch max(Bₛ.count, Aₛ.count) {
//		case 1:
//			return {
//				for target in zip(stride(from: 0, to: $3, by: $3).lazy.map($2.advanced(by:)), CollectionOfOne($1)).map(UnsafeMutableBufferPointer.init) {
//                    vDSP.fill(&target[0..<target.count], with: 1)
//				}
//			}
//		case let n:
//			let xₖ = try ω₀(interval: interval, capacity: capacity, instance: &instance)
//			let Tₛ = interval.seconds
//            let Mₛ = Prototype.BLT.Matrix(size: n)
//			return { moment, length, target, stride in
//                withUnsafeTemporaryAllocation(of: Float64.self, capacity: n * length) {
//                    guard let source = $0.baseAddress else { return }
//                    xₖ(moment, length, source, length)
//                    vDSP.multiply(Tₛ, $0[0..<length], result: &$0[0..<length])
//                    vForce.tanPi($0[0..<length], result: &$0[0..<length])
////                    for offset in (0..<n).reversed() {
////                        vvpow(source, .init(offset), source.advanced(by: offset * length), length)
////                    }
//                    for degree in 1..<n {
//                        vDSP.multiply($0[0..<length],
//                                      $0[degree * length - length ..< degree * length],
//                                      result: &$0[degree * length ..< degree * length + length])
//                    }
//                    vDSP.fill(&UnsafeMutableBufferPointer(start: source, count: length)[0..<length], with: 1)
//					for (bₖ, bₛ) in Bₛ.enumerated() {
//						vDSP.multiply(bₛ,
//									  $0[(bₖ) * length ..< (bₖ + 1) * length],
//									  result: &UnsafeMutableBufferPointer(start: target.advanced(by: (n+bₖ) * stride), count: length)[0..<length])
//					}
//                    gemm(length, n, n,
//                         1,
//                         target.advanced(by: n * stride), stride, .N,
//                         Mₛ, n, .T,
//                         0,
//                         target, stride)
//					for (aₖ, aₛ) in Aₛ.enumerated() {
//						vDSP.multiply(aₛ,
//									  $0[(aₖ) * length ..< (aₖ + 1) * length],
//									  result: &UnsafeMutableBufferPointer(start: source.advanced(by: aₖ * length), count: length)[0..<length])
//					}
//                    gemm(length, n, n,
//                         1,
//                         source, length, .N,
//                         Mₛ, n, .T,
//                         0,
//                         target.advanced(by: n * stride), stride)
//				}
//			}
//		}
//	}
//}
