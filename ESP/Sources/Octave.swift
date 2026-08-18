//
//  Octave.swift
//  MUTE
//
//  Created by Kota on 10/30/25.
//
import protocol Accelerate.AccelerateBuffer
import func LAPACK.gels
import enum Accelerate.vDSP
import enum Accelerate.vForce
import let Darwin.M_LN10
// estimate slope and intercept for dB/oct. from frequency response
@inlinable
public func`dB/oct.`(frequency: some AccelerateBuffer<Float64> & Sequence<Float64>,
                     magnitude: some AccelerateBuffer<Float64>,
                     bandwidth: some RangeExpression<Float64>) -> (Float64, Float64) {
    precondition(frequency.count == magnitude.count)
    let range = frequency.enumerated().compactMap { bandwidth.contains($1) ? .some(UInt($0 + 1)) : .none }
    let count = range.count
    let size = gels(count, 2, 1,
                    unsafeBitCast(Optional<UnsafeMutablePointer<Float64>>.none, to: UnsafeMutablePointer<Float64>.self), count, .N,
                    unsafeBitCast(Optional<UnsafeMutablePointer<Float64>>.none, to: UnsafeMutablePointer<Float64>.self), count,
                    .none, -1)
    assert(0 < size, "lapack error \(size)")
    return withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * count + max(2, count) + size) {
        // A
        vDSP.gather(frequency, indices: range, result: &$0[0*count..<1*count])
        vForce.log2($0[0*count..<1*count], result: &$0[0*count..<1*count])
        vDSP.fill(&$0[1*count..<2*count], with: 1)
        // B
        vDSP.gather(magnitude, indices: range, result: &$0[2*count..<3*count])
        vForce.log10($0[2*count..<3*count], result: &$0[2*count..<3*count])
        vDSP.multiply(20, $0[2*count..<3*count], result: &$0[2*count..<3*count])
        // solve
        let info = gels(count, 2, 1,
                        $0.baseAddress.unsafelyUnwrapped.advanced(by: 0 * count), count, .N,
                        $0.baseAddress.unsafelyUnwrapped.advanced(by: 2 * count), count,
                        $0.baseAddress.unsafelyUnwrapped.advanced(by: 2 * count + max(2, count)), size)
        assert(info == 0, "lapack error \(info)")
        return ($0[2*count+0], $0[2*count+1])
    }
}
@inlinable
public func lnslope(frequency: some AccelerateBuffer<Float64> & Sequence<Float64>,
                    magnitude: some AccelerateBuffer<Float64>,
                    bandwidth: some RangeExpression<Float64>) -> Array<Float64> {
    let (α, β) = `dB/oct.`(frequency: frequency, magnitude: magnitude, bandwidth: bandwidth)
    return.init(unsafeUninitializedCapacity: frequency.count) {
        vForce.log2(frequency, result: &$0)
        vDSP.invertedClip($0, to: 0...0, result: &$0)
        vDSP.add(multiplication: ($0, 0.05 * M_LN10 * α), 0.05 * M_LN10 * β, result: &$0)
        $1 = $0.count
    }
}
