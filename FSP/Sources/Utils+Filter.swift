//
//  Utils+Filter.swift
//  MUTE
//
//  Created by Kota on 8/28/26.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Numerics.Complex128
import func MKL.vDSP_mul
import func MKL.vDSP_ztoc
import func BLAS.copy
import func BLAS.gemv
import typealias ESP.BiquadFilter
extension Utils {
    @inlinable
    public static func Response(frequency: some AccelerateBuffer<Float64>,
                                kernel: (b: some AccelerateBuffer<Float64>, a: some AccelerateBuffer<Float64>)) -> Array<Complex128> {
        let ω = frequency.count
        let m = 2 * ω
        let n = max(kernel.b.count, kernel.a.count)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * (2 + n)) {
            let Z = $0.extracting(m*(  0)..<m*(n+0))
            let B = $0.extracting(m*(n+0)..<m*(n+1))
            let A = $0.extracting(m*(n+1)..<m*(n+2))
            for k in 0..<n {
                vDSP.multiply(.init(-2*k), frequency, result: &Z[k*m+ω..<k*m+m])
                vForce.cosPi(Z[k*m+ω..<k*m+m], result: &Z[k*m+0..<k*m+ω])
                vForce.sinPi(Z[k*m+ω..<k*m+m], result: &Z[k*m+ω..<k*m+m])
            }
            kernel.b.withUnsafeBufferPointer {
                gemv(m, $0.count,
                     1,
                     Z.baseAddress.unsafelyUnwrapped, m, .N,
                     $0.baseAddress.unsafelyUnwrapped, 1,
                     0,
                     B.baseAddress.unsafelyUnwrapped, 1)
            }
            kernel.a.withUnsafeBufferPointer {
                gemv(m, $0.count,
                     1,
                     Z.baseAddress.unsafelyUnwrapped, m, .N,
                     $0.baseAddress.unsafelyUnwrapped, 1,
                     0,
                     A.baseAddress.unsafelyUnwrapped, 1)
            }
            vDSP.add(multiplication: (B[0..<ω], A[0..<ω]),
                     multiplication: (B[ω..<m], A[ω..<m]),
                     result: &Z[0..<ω])
            vDSP.subtract(multiplication: (B[ω..<m], A[0..<ω]),
                          multiplication: (B[0..<ω], A[ω..<m]),
                          result: &Z[ω..<m])
            vDSP.add(multiplication: (A[0..<ω], A[0..<ω]),
                     multiplication: (A[ω..<m], A[ω..<m]),
                     result: &A[0..<ω])
            vDSP.divide(Z[0..<ω], A[0..<ω], result: &Z[0..<ω])
            vDSP.divide(Z[ω..<m], A[0..<ω], result: &Z[ω..<m])
            return.init(unsafeUninitializedCapacity: ω) {
                $1 = $0.count
                $0.withMemoryRebound(to: Float64.self) {
                    copy(ω, Z.baseAddress.unsafelyUnwrapped.advanced(by: 0), 1, $0.baseAddress.unsafelyUnwrapped.advanced(by: 0), 2)
                    copy(ω, Z.baseAddress.unsafelyUnwrapped.advanced(by: ω), 1, $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2)
                }
            }
        }
    }
    @inlinable
    public static func Response(frequency: some AccelerateBuffer<Float64>,
                                sos: some Sequence<(Float64, Float64, Float64, Float64, Float64)>) -> Array<Complex128> {
        let ω = frequency.count
        let m = 2 * ω
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * 6) {
            let X = $0.extracting(m*4..<m*5)
            let Y = $0.extracting(m*5..<m*6)
            let Z = $0.extracting(m*0..<m*3)
            let W = $0.extracting(m*3..<m*4)
            vDSP.clear(&Y[0..<m])
            vDSP.fill(&Z[0..<ω], with: 1)
            vDSP.clear(&Z[ω..<m])
            for k in 1..<3 {
                vDSP.multiply(.init(-2*k), frequency, result: &Z[k*m+ω..<k*m+m])
                vForce.cosPi(Z[k*m+ω..<k*m+m], result: &Z[k*m+0..<k*m+ω])
                vForce.sinPi(Z[k*m+ω..<k*m+m], result: &Z[k*m+ω..<k*m+m])
            }
            for (b0, b1, b2, a1, a2) in sos {
                gemv(m, 3,
                     1,
                     Z.baseAddress.unsafelyUnwrapped, m, .N,
                     [b0, b1, b2], 1,
                     0,
                     W.baseAddress.unsafelyUnwrapped, 1)
                vDSP.add(multiplication: (W[0..<ω], W[0..<ω]),
                         multiplication: (W[ω..<m], W[ω..<m]),
                         result: &X[0..<ω])
                vForce.log(X[0..<ω], result: &X[0..<ω])
                vForce.atan2(x: W[0..<ω], y: W[ω..<m], result: &X[ω..<m])
                vDSP.add(Y, X, result: &Y[0..<m])
                gemv(m, 3,
                     1,
                     Z.baseAddress.unsafelyUnwrapped, m, .N,
                     [1, a1, a2], 1,
                     0,
                     W.baseAddress.unsafelyUnwrapped, 1)
                vDSP.add(multiplication: (W[0..<ω], W[0..<ω]),
                         multiplication: (W[ω..<m], W[ω..<m]),
                         result: &X[0..<ω])
                vForce.log(X[0..<ω], result: &X[0..<ω])
                vForce.atan2(x: W[0..<ω], y: W[ω..<m], result: &X[ω..<m])
                vDSP.subtract(Y, X, result: &Y[0..<m])
            }
            vDSP.divide(Y[0..<ω], 2, result: &Y[0..<ω])
            vForce.exp(Y[0..<ω], result: &Y[0..<ω])
            vForce.cos(Y[ω..<m], result: &W[0..<ω])
            vForce.sin(Y[ω..<m], result: &W[ω..<m])
            return.init(unsafeUninitializedCapacity: ω) {
                $1 = $0.count
                $0.withMemoryRebound(to: Float64.self) {
                    vDSP_mul(Y.baseAddress.unsafelyUnwrapped, 1,
                             W.baseAddress.unsafelyUnwrapped.advanced(by: 0), 1,
                             $0.baseAddress.unsafelyUnwrapped.advanced(by: 0), 2, ω)
                    vDSP_mul(Y.baseAddress.unsafelyUnwrapped, 1,
                             W.baseAddress.unsafelyUnwrapped.advanced(by: ω), 1,
                             $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2, ω)
                }
            }
        }
    }
//    @inlinable
//    public static func BLT(_ n: Int) -> Array<Float64> {
//        Array<Int>(unsafeUninitializedCapacity: n * n * 3) {
//            let lhs = $0.extracting(1 * n * n ..< 2 * n * n)
//            let rhs = $0.extracting(2 * n * n ..< 3 * n * n)
//            $0.initialize(repeating: .zero)
//            lhs[0] = 1
//            rhs[0] = 1
//            for (k, j) in stride(from: 0, to: n * n, by: n).dropLast().enumerated() {
//                for i in j...j+k {
//                    lhs[i+n+0] += lhs[i]
//                    rhs[i+n+0] += rhs[i]
//                }
//                for i in j...j+k {
//                    lhs[i+n+1] += lhs[i]
//                    rhs[i+n+1] -= rhs[i]
//                }
//            }
//            for (p, q) in (0..<n).reversed().enumerated() {
//                let lhs = lhs[p*n...p*n+p]
//                let rhs = rhs[q*n...q*n+q]
//                for (s, t) in lhs.enumerated() {
//                    for (u, v) in rhs.enumerated() {
//                        $0[p*n+s+u] += t * v
//                    }
//                }
//            }
//            $1 = n * n
//        }.map(Float64.init)
//    }
}
