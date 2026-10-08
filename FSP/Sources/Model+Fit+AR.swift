//
//  Model+Fit+AR.swift
//  MUTE
//
//  Created by Kota on 10/8/26.
//
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import func Accelerate.vDSP_wienerD
import func KSP.wiener
import func simd.fma
extension Model {
    @inlinable
    public static func fit(
        response: some AccelerateBuffer<Float64> & Collection<Float64>,
        order: Int
    ) -> Model.AR {
        .init(raw: .init(unsafeUninitializedCapacity: 4 * order + 2) {
            vDSP.correlate(response, withKernel: response.dropLast(order), result: &$0[3*order+1 ..< 4*order+2])
            vDSP.negative($0[3*order+2 ..< 4*order+2], result: &$0[2*order+1 ..< 3*order+1])
            switch wiener(
                $0.baseAddress.unsafelyUnwrapped.advanced(by: 3*order+1),
                $0.baseAddress.unsafelyUnwrapped.advanced(by: 2*order+1),
                $0.baseAddress.unsafelyUnwrapped.advanced(by: 1),
                $0.baseAddress.unsafelyUnwrapped.advanced(by: order+1),
                order
            ) {
            case let info:
                assert(info == 0)
            }
            $0.prefix(1).initialize(repeating: 1)
            $1 = order + 1
        })
    }
}
