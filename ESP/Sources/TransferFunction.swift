//
//  TransferFunction.swift
//  MUTE
//
//  Created by Kota on 8/29/26.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Numerics.Complex128
import func BLAS.gemv
import func BLAS.copy
import func MKL.vDSP_clr
import func MKL.vDSP_mul
import func MKL.vDSP_div
public enum TransferFunction {}
extension TransferFunction {
    public struct Transformer<RawValue: DFT.`Protocol`> {
        @usableFromInline
        let rawValue: RawValue
    }
}
extension TransferFunction.Transformer where RawValue == DFT.BFS {
    @inlinable
    public init(count: Int) {
        rawValue = .init(count: count)
    }
}
extension TransferFunction.Transformer {
    @inlinable
    public var count: Int {
        rawValue.count
    }
}
extension TransferFunction.Transformer {
    @inlinable
    public func response(b: some AccelerateBuffer<Float64>,
                         a: some AccelerateBuffer<Float64>) -> Array<Complex128> {
        .init(unsafeUninitializedCapacity: 3 * rawValue.count) {
            precondition(b.count <= rawValue.count)
            precondition(a.count <= rawValue.count)
            let H = $0.extracting(0*rawValue.count..<1*rawValue.count)
            let B = $0.extracting(1*rawValue.count..<2*rawValue.count)
            let A = $0.extracting(2*rawValue.count..<3*rawValue.count)
            H.withMemoryRebound(to: Float64.self) {
                let r = $0.baseAddress.unsafelyUnwrapped
                vDSP_clr(r, 1, $0.count)
                b.withUnsafeBufferPointer {
                    copy($0.count,
                         $0.baseAddress.unsafelyUnwrapped, 1, r, 2)
                }
            }
            rawValue.forward(x: H.baseAddress.unsafelyUnwrapped,
                             y: B.baseAddress.unsafelyUnwrapped)
            H.withMemoryRebound(to: Float64.self) {
                let r = $0.baseAddress.unsafelyUnwrapped
                vDSP_clr(r, 1, $0.count)
                a.withUnsafeBufferPointer {
                    copy($0.count,
                         $0.baseAddress.unsafelyUnwrapped, 1, r, 2)
                }
            }
            rawValue.forward(x: H.baseAddress.unsafelyUnwrapped,
                             y: A.baseAddress.unsafelyUnwrapped)
            vDSP_div(B.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                     A.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                     H.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                     rawValue.count)
            $1 = H.count
        }
    }
}
extension TransferFunction.Transformer {
    @inlinable
    public func response(cascade: some Sequence<(Float64, Float64, Float64, Float64, Float64)>) -> Array<Complex128> {
        .init(unsafeUninitializedCapacity: 2 * rawValue.count) {
            let Y = $0.extracting(0*rawValue.count..<1*rawValue.count)
            let X = $0.extracting(1*rawValue.count..<2*rawValue.count)
            Y.initialize(repeating: 1)
            for (b₀, b₁, b₂, a₁, a₂) in cascade {
                X[0] = .init(real: b₀, imag: 0)
                X[1] = .init(real: b₁, imag: 0)
                X[2] = .init(real: b₂, imag: 0)
                X[3...].initialize(repeating: .zero)
                rawValue.forward(x: X.baseAddress.unsafelyUnwrapped, inc: 1,
                                 y: X.baseAddress.unsafelyUnwrapped, inc: 1)
                vDSP_mul(Y.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                         X.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                         Y.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                         rawValue.count)
                X[0] = .init(real: 1, imag: 0)
                X[1] = .init(real: a₁, imag: 0)
                X[2] = .init(real: a₂, imag: 0)
                X[3...].initialize(repeating: .zero)
                rawValue.forward(x: X.baseAddress.unsafelyUnwrapped, inc: 1,
                                 y: X.baseAddress.unsafelyUnwrapped, inc: 1)
                vDSP_div(Y.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                         X.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                         Y.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                         rawValue.count)
            }
            $1 = Y.count
        }
    }
}
extension TransferFunction {
    @inlinable
    public static func response(frequency: some AccelerateBuffer<Float64>,
                                b: some AccelerateBuffer<Float64>,
                                a: some AccelerateBuffer<Float64>) -> Array<Complex128> {
        let ω = frequency.count
        let m = 2 * ω
        let n = max(b.count, a.count)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * (2 + n)) {
            let Z = $0.extracting(m*(  0)..<m*(n+0))
            let B = $0.extracting(m*(n+0)..<m*(n+1))
            let A = $0.extracting(m*(n+1)..<m*(n+2))
            for k in 0..<n {
                vDSP.multiply(.init(-2*k), frequency, result: &Z[k*m+ω..<k*m+m])
                vForce.cosPi(Z[k*m+ω..<k*m+m], result: &Z[k*m+0..<k*m+ω])
                vForce.sinPi(Z[k*m+ω..<k*m+m], result: &Z[k*m+ω..<k*m+m])
            }
            b.withUnsafeBufferPointer {
                gemv(m, $0.count,
                     1,
                     Z.baseAddress.unsafelyUnwrapped, m, .N,
                     $0.baseAddress.unsafelyUnwrapped, 1,
                     0,
                     B.baseAddress.unsafelyUnwrapped, 1)
            }
            a.withUnsafeBufferPointer {
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
    @_disfavoredOverload
    @inlinable@inline(__always)@_transparent
    public static func response(frequency: some AccelerateBuffer<Float64>,
                                b: Float64...,
                                a: Float64...) -> Array<Complex128> {
        response(frequency: frequency, b: b, a: a)
    }
}
extension TransferFunction {
    @inlinable
    public static func response(frequency: some AccelerateBuffer<Float64>,
                                cascade: some Sequence<(Float64, Float64, Float64, Float64, Float64)>) -> Array<Complex128> {
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
            for (b₀, b₁, b₂, a₁, a₂) in cascade {
                gemv(m, 3,
                     1,
                     Z.baseAddress.unsafelyUnwrapped, m, .N,
                     [b₀, b₁, b₂], 1,
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
                     [1, a₁, a₂], 1,
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
    @_disfavoredOverload
    @inlinable@inline(__always)@_transparent
    public static func response(frequency: some AccelerateBuffer<Float64>,
                                cascade: (Float64, Float64, Float64, Float64, Float64)...) -> Array<Complex128> {
        response(frequency: frequency, cascade: cascade)
    }
}
