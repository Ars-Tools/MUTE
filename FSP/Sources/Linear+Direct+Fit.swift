//
//  Linear+Direct+Fit.swift
//  MUTE
//
//  Created by Kota on 9/4/26.
//
import typealias Numerics.Complex128
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func BLAS.ger
import func BLAS.copy
import func BLAS.gemv
import func LAPACK.gels
import func MKL.vDSP_ctoz
import func NSP.wiener
extension Linear.Direct {
    @inlinable // [0, 2π) complex spectrum → (b, a) direct-form, frequency is normalized angular frequency [0, 2π) → [0, 1.0)
    public static func Fit(frequency: some AccelerateBuffer<Float64>,
                           response: (r: some AccelerateBuffer<Float64>, i: some AccelerateBuffer<Float64>),
                           confidence: some AccelerateBuffer<Float64>, // weight
                           count: (b: Int, a: Int)) -> Self {
        let ω = frequency.count
        precondition(ω == response.r.count)
        precondition(ω == response.i.count)
        precondition(ω == confidence.count)
        precondition(ω > count.b)
        precondition(ω > count.a)
        precondition(count.b > 0)
        precondition(count.a > 0)
        let m = response.r.count + response.i.count
        let n = 1 + count.b + count.a
        let l = gels(m, n, 1,
                     .none, m, .N,
                     .none, max(m, n),
                     .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + max(m, n) + max(m, l)) {
            let A = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let b = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(max(m, n)))
            let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + max(m, n)).prefix(max(m, l)))
            // Basis
            for k in 0..<max(count.b, count.a) {
                vDSP.multiply(.init(-2*k-2), frequency, result: &A[ω..<m])
                vForce.cosPi(A[ω..<m], result: &A[0..<ω])
                vForce.sinPi(A[ω..<m], result: &A[ω..<m])
                if k < count.b {
                    let v = (1+k+0*count.b) * m ..< (1+k+0*count.b) * m + m
                    switch A[v].update(fromContentsOf: A[0..<m]) {
                    case let eof:
                        assert(eof == A[v].endIndex)
                    }
                }
                if k < count.a {
                    let v = (1+k+1*count.b) * m ..< (1+k+1*count.b) * m + m
                    switch A[v].update(fromContentsOf: A[0..<m]) {
                    case let eof:
                        assert(eof == A[v].endIndex)
                    }
                }
            }
            // precondition by solving Yule-Walker
            vDSP.add(multiplication: (response.r, response.r), multiplication: (response.i, response.i), result: &b[ω..<m])
            b[0] = 1
            gemv(ω, count.a,
                 1 / vDSP.sum(b[ω..<m]),
                 A.baseAddress.unsafelyUnwrapped.advanced(by: count.b * m + m), m, .T,
                 b.baseAddress.unsafelyUnwrapped.advanced(by: ω), 1,
                 0,
                 b.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1) // IDFT
            vDSP.negative(b[1..<1+count.a], result: &w[0..<0+count.a]) // RHS
            wiener(b.baseAddress.unsafelyUnwrapped,
                   w.baseAddress.unsafelyUnwrapped,
                   b.baseAddress.unsafelyUnwrapped.advanced(by: ω),
                   A.baseAddress.unsafelyUnwrapped.advanced(by: 0), // ignore performance score
                   count.a) // solve Yule-Walker
            vDSP.fill(&A[0..<ω], with: 1)
            vDSP.clear(&A[ω..<m])
            gemv(m, count.a,
                 1,
                 A.baseAddress.unsafelyUnwrapped.advanced(by: count.b * m + m), m, .N,
                 b.baseAddress.unsafelyUnwrapped.advanced(by: ω), 1,
                 1,
                 A.baseAddress.unsafelyUnwrapped, 1) // DFT
            vDSP.add(multiplication: (A[0..<ω], A[0..<ω]), multiplication: (A[ω..<m], A[ω..<m]), result: &A[0..<ω])
            vDSP.divide(confidence, A[0..<ω], result: &A[0..<ω])
            vForce.sqrt(A[0..<ω], result: &A[0..<ω])
            vDSP.clear(&A[ω..<m])
            //
            for k in 0..<count.b {
                let c = (1+k+0*count.b) * m + 0 ..< (1+k+0*count.b) * m + ω
                let s = (1+k+0*count.b) * m + ω ..< (1+k+0*count.b) * m + m
                vDSP.multiply(A[0..<ω], A[c], result: &A[c])
                vDSP.multiply(A[0..<ω], A[s], result: &A[s])
            }
            for k in 0..<count.a {
                let c = (1+k+1*count.b) * m + 0 ..< (1+k+1*count.b) * m + ω
                let s = (1+k+1*count.b) * m + ω ..< (1+k+1*count.b) * m + m
                vDSP.subtract(multiplication: (A[c], response.r), multiplication: (A[s], response.i), result: &w[0..<ω])
                vDSP.add(multiplication: (A[c], response.i), multiplication: (A[s], response.r), result: &w[ω..<m])
                vDSP.negative(w[0..<m], result: &w[0..<m])
                vDSP.multiply(A[0..<ω], w[0..<ω], result: &A[c])
                vDSP.multiply(A[0..<ω], w[ω..<m], result: &A[s])
            }
            vDSP.multiply(A[0..<ω], response.r, result: &b[0..<ω])
            vDSP.multiply(A[0..<ω], response.i, result: &b[ω..<m])
            let s = gels(m, n, 1,
                         A.baseAddress, m, .N,
                         b.baseAddress, b.count,
                         w.baseAddress, w.count)
            assert(0 == s)
            return.init(raw: (
                .init(b.prefix(1 + count.b)),
                .init(arrayLiteral: 1) + b.dropFirst(1 + count.b).prefix(count.a)
            ))
        }
    }
    @inlinable // [0, 2π) complex spectrum → (b, a) direct-form, frequency is normalized angular frequency [0, 2π) → [0, 1.0)
    public static func Fit(frequency: some AccelerateBuffer<Float64>,
                           response: some AccelerateBuffer<Complex128>,
                           confidence: some AccelerateBuffer<Float64>, // weight
                           count: (b: Int, a: Int)) -> Self {
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * response.count) {
            let r = $0.extracting(0 * response.count ..< 1 * response.count)
            let i = $0.extracting(1 * response.count ..< 2 * response.count)
            response.withUnsafeBufferPointer {
                vDSP_ctoz($0.baseAddress.unsafelyUnwrapped.rawPointer, 1,
                          r.baseAddress.unsafelyUnwrapped, i.baseAddress.unsafelyUnwrapped, 1,
                          $0.count)
            }
            return Fit(frequency: frequency,
                       response: (r, i),
                       confidence: confidence,
                       count: count)
        }
    }
}
