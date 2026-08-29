//
//  Ramp.swift
//  MUTE
//
//  Created by Kota on 10/30/25.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func simd.log
import func simd.log2
import func simd.exp2
public enum Ramp {}
extension Ramp {
    @inlinable@inline(__always)@_transparent
    public static func arange(in range: ClosedRange<Float64>, count: Int) -> Array<Float64> {
        vDSP.ramp(withInitialValue: range.lowerBound, increment: ( range.upperBound - range.lowerBound ) / .init(count), count: count)
    }
    @inlinable@inline(__always)@_transparent
    public static func linspace(in range: ClosedRange<Float64>, count: Int) -> Array<Float64> {
        vDSP.ramp(in: range, count: count)
    }
    @inlinable
    public static func logspace(in range: ClosedRange<Float64>, count: Int) -> Array<Float64> {
        .init(unsafeUninitializedCapacity: count) {
            $1 = $0.count
            let range = log2(SIMD2<Float64>(range.lowerBound, range.upperBound))
            vDSP.formRamp(withInitialValue: range.x, increment: (range.y - range.x) / .init($1), result: &$0)
            vForce.exp2($0, result: &$0)
        }
    }
    @inlinable
    public static func chirp(in range: ClosedRange<Float64> = 0.0 ... 0.5, linear count: Int) -> Array<Float64> {
        .init(unsafeUninitializedCapacity: count) {
            $1 = count
            // ω(t) = at + b
            // ∫ω(t) = at^2/2 + bt
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
            vDSP.evaluatePolynomial(usingCoefficients: [
                (range.upperBound - range.lowerBound) / .init($1),
                (range.lowerBound * 2),
                0.0
            ], withVariables: $0, result: &$0)
            vForce.sinPi($0, result: &$0)
        }
    }
    @inlinable
    public static func chirp(in range: ClosedRange<Float64>, exponential count: Int) -> Array<Float64> {
        .init(unsafeUninitializedCapacity: count) {
            $1 = count
            // ω(t) = a•exp(βt)
            // ∫ω(t) = a•exp(βt)/β
            let γ = log(SIMD2(range.lowerBound, range.upperBound))
            let ξ = (γ.y - γ.x) / .init($1)
            vDSP.formRamp(withInitialValue: 0, increment: ξ, result: &$0)
            vForce.expm1($0, result: &$0) // 0-start
            vDSP.multiply(2 * range.lowerBound / ξ, $0, result: &$0)
            vForce.sinPi($0, result: &$0)
        }
    }
}
