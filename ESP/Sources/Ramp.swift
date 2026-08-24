//
//  Ramp.swift
//  MUTE
//
//  Created by Kota on 10/30/25.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func simd.log2
import func simd.exp2
public enum Ramp {}
extension Ramp {
    @inlinable@_transparent
    public static func logspace(in range: ClosedRange<Float64>, count: Int) -> Array<Float64> {
        .init(unsafeUninitializedCapacity: count) {
            let range = log2(SIMD2<Float64>(range.lowerBound, range.upperBound))
            vDSP.formRamp(withInitialValue: range.x, increment: (range.y - range.x) / .init($0.count), result: &$0)
            vForce.exp2($0, result: &$0)
            $1 = $0.count
        }
    }
}
