//
//  Octave.swift
//  MUTE
//
//  Created by Kota on 10/30/25.
//
import protocol Accelerate.AccelerateBuffer
import enum Accelerate.vDSP
import enum Accelerate.vForce
import func Darwin.pow
import let Darwin.M_LN2
import let Darwin.M_LN10
import func vFORCE.vvpow
import func LAPACK.gels
public enum Octave {}
extension Octave {
    // estimate slope and intercept for dB/oct. from frequency response
    @inlinable
    public static func`dB/oct.`(frequency: some AccelerateBuffer<Float64>,
                                response: some AccelerateBuffer<Float64>,
                                confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>) -> SIMD2<Float64> {
        let m = response.count
        let n = 2
        let l = gels(m, n, 1,
                     .none, m, .N,
                     .none, max(m, n),
                     .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l, "lapack size \(l)")
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + max(m, n) + l) {
            let A = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let b = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(max(m, n)))
            let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + max(m, n)).prefix(l))
            // C
            if let confidence {
                vForce.sqrt(confidence, result: &A[1*m..<2*m])
            } else {
                vDSP.fill(&A[1*m..<2*m], with: 1)
            }
            // A
            vForce.log2(frequency, result: &A[0..<m])
            vDSP.multiply(A[1*m..<2*m], A[0..<m], result: &A[0..<m])
            Guard.removeAbnormal(of: &A[0..<m])
            // B
            vForce.log10(response, result: &b[0..<m])
            vDSP.multiply(20, b[0..<m], result: &b[0..<m])
            vDSP.multiply(A[1*m..<2*m], b[0..<m], result: &b[0..<m])
            Guard.removeAbnormal(of: &b[0..<m])
            let s = gels(m, n, 1,
                         A.baseAddress, m, .N,
                         b.baseAddress, max(m, n),
                         w.baseAddress, l)
            assert(0 == s)
            return.init(b[0], b[1])
        }
    }
    @inlinable@inline(__always)@_transparent
    public static func`dB/oct.`(response: some AccelerateBuffer<Float64>,
                                confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>) -> SIMD2<Float64> {
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: response.count) {
            vDSP.formRamp(withInitialValue: 0.5, increment: 1, result: &$0[0..<$0.count])
            vDSP.divide($0, .init($0.count), result: &$0[0..<$0.count])
            return `dB/oct.`(frequency: $0,
                             response: response,
                             confidence: confidence)
        }
    }
}
extension Octave {
    @inlinable
    public static func lnslope(frequency: some AccelerateBuffer<Float64> & Sequence<Float64>,
                               response: some AccelerateBuffer<Float64>,
                               confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>) -> Array<Float64> {
        let ƒ = `dB/oct.`(frequency: frequency,
                          response: response,
                          confidence: confidence) * M_LN10 / 20
        return.init(unsafeUninitializedCapacity: frequency.count) {
            vForce.log2(frequency, result: &$0)
            vDSP.add(multiplication: ($0, ƒ.x), ƒ.y, result: &$0)
            vForce.exp($0, result: &$0)
            Guard.removeAbnormal(of: $0)
            $1 = $0.count
        }
    }
    @inlinable@inline(__always)@_transparent
    public static func lnslope(response: some AccelerateBuffer<Float64>,
                               confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>) -> Array<Float64> {
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: response.count) {
            vDSP.formRamp(withInitialValue: 0.5, increment: 1, result: &$0[0..<$0.count])
            vDSP.divide($0, .init($0.count), result: &$0[0..<$0.count])
            return lnslope(frequency: $0,
                           response: response,
                           confidence: confidence)
        }
    }
}
