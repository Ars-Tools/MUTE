//
//  WindowFunction.swift
//  MUTE
//
//  Created by Kota on 9/17/26.
//
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func simd.__exp10
import func simd.cos
import func simd.cosh
import func simd.acos
import func simd.acosh
import func simd._simd_sinc
import func KSP.vvi0
import func KSP.i0
public enum WindowFunction {
    case Rect
    case Bartlett
    case Jonathan
    case Hanning
    case Hamming
    case Blackman
    case Kaiser(α: Float64)
    case Gauss(σ²: Float64)
    case Sinc(α: Float64)
    case Chebyshev(α: Float64)
}
extension WindowFunction {
    @inlinable
    public func generate(into buffer: inout some AccelerateMutableBuffer<Float64>) {
        switch self {
        case.Rect:
            buffer.withUnsafeMutableBufferPointer {
                $0.update(repeating: 1)
            }
        case.Bartlett:
            buffer.withUnsafeMutableBufferPointer {
                vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0[..<($0.count/2+1)])
                vDSP.formRamp(withInitialValue: .init(($0.count+1)/2-1), increment: -1, result: &$0[($0.count/2+1)...])
                vDSP.divide($0, .init($0.count/2), result: &$0)
            }
        case.Jonathan:
            vDSP.formWindow(usingSequence: .hanningDenormalized, result: &buffer, isHalfWindow: false)
            vForce.sqrt(buffer, result: &buffer)
        case .Hanning:
            vDSP.formWindow(usingSequence: .hanningDenormalized, result: &buffer, isHalfWindow: false)
        case.Hamming:
            vDSP.formWindow(usingSequence: .hamming, result: &buffer, isHalfWindow: false)
        case.Blackman:
            vDSP.formWindow(usingSequence: .blackman, result: &buffer, isHalfWindow: false)
        case.Kaiser(let α):
            vDSP.formRamp(withInitialValue: -1, increment: 2 / .init(buffer.count), result: &buffer)
            vDSP.square(buffer, result: &buffer)
            vDSP.add(multiplication: (buffer, -1), 1, result: &buffer)
            vForce.sqrt(buffer, result: &buffer)
            vDSP.multiply(α * .pi, buffer, result: &buffer)
            buffer.withUnsafeMutableBufferPointer {
                vvi0($0.baseAddress.unsafelyUnwrapped, $0.baseAddress.unsafelyUnwrapped, $0.count)
            }
            vDSP.divide(buffer, i0(α * .pi), result: &buffer)
        case.Gauss(let σ²):
            vDSP.formRamp(withInitialValue: .init(-buffer.count/2), increment: 1, result: &buffer)
            vDSP.square(buffer, result: &buffer)
            vDSP.multiply(-.pi * σ² / .init(buffer.count), buffer, result: &buffer)
            vForce.exp(buffer, result: &buffer)
            vDSP.multiply((σ² / .init(buffer.count)).squareRoot() / .pi, buffer, result: &buffer)
        case.Sinc(let α):
            vDSP.formRamp(withInitialValue: .init(-buffer.count/2) * α * .pi, increment: α * .pi, result: &buffer)
            buffer.withUnsafeMutableBufferPointer {
                let eof = $0.update(fromContentsOf: $0.map(_simd_sinc))
                assert(eof == $0.endIndex)
            }
        case.Chebyshev(let α):
            let scale = __exp10(α)
            fatalError()
        }
    }
    @inlinable@_transparent
    public func generate(count: Int) -> Array<Float64> {
        .init(unsafeUninitializedCapacity: count) {
            $1 = $0.count
            generate(into: &$0)
        }
    }
}
