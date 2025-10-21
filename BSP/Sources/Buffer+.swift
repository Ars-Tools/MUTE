//
//  Buffer+.swift
//  MUTE
//
//  Created by Kota on 10/15/25.
//
import Accelerate
@_exported import typealias DSP.Buffer
extension Buffer {
    @inlinable@_transparent
    public func maximize(dB: Float64 = 0) {
        let signal = zip(stride(from: start, to: start.advanced(by: stream * period), by: period), sequence(first: period, next: \.self)).map(UnsafeMutableBufferPointer.init(start:count:))
        switch vDSP.maximum(signal.map(vDSP.maximumMagnitude)) {
        case let normal where normal.isNormal:
            let factor = normal * __exp10(-0.05 * dB)
            for signal in signal {
                vDSP.divide(signal, factor, result: &signal[0..<signal.count])
            }
        default:
            break
        }
    }
}
extension Buffer {
    @inlinable@_transparent
    public func reverse() {
        let signal = zip(stride(from: start, to: start.advanced(by: stream * period), by: period), sequence(first: period, next: \.self)).map(UnsafeMutableBufferPointer.init(start:count:))
        for signal in signal {
            vDSP.reverse(&signal[0..<signal.count])
        }
    }
}
extension Buffer {
    @inlinable@_transparent
    func fade(prefix ramp: Array<Float64>) {
        let signal = zip(stride(from: start, to: start.advanced(by: stream * period), by: period), sequence(first: period, next: \.self)).map(UnsafeMutableBufferPointer.init(start:count:))
        let phasor = ramp.suffix(period)
        for signal in signal {
            vDSP.multiply(phasor, signal[0..<phasor.count], result: &signal[0..<phasor.count])
        }
    }
    @inlinable@_transparent
    func fade(suffix ramp: Array<Float64>) {
        let signal = zip(stride(from: start, to: start.advanced(by: stream * period), by: period), sequence(first: period, next: \.self)).map(UnsafeMutableBufferPointer.init(start:count:))
        let phasor = ramp.prefix(period)
        for signal in signal {
            vDSP.multiply(phasor, signal[period-phasor.count..<period], result: &signal[period-phasor.count..<period])
        }
    }
    @inlinable
    public func fade(in sample: Int) {
        fade(prefix: .init(unsafeUninitializedCapacity: sample) {
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
            vDSP.divide($0, .init($0.count), result: &$0)
            $1 = $0.count
        })
    }
    @inlinable
    public func fade(in sample: Int, dB: Float64) {
        fade(prefix: .init(unsafeUninitializedCapacity: sample) {
            vDSP.formRamp(from: 0.05 * M_LOG2E * M_LN10 * dB, through: 0, result: &$0)
            vForce.exp2($0, result: &$0)
            $1 = $0.count
        })
    }
    @inlinable
    public func fade(out sample: Int) {
        fade(suffix: .init(unsafeUninitializedCapacity: sample) {
            vDSP.formRamp(withInitialValue: .init($0.count), increment: -1, result: &$0)
            vDSP.divide($0, .init($0.count), result: &$0)
            $1 = $0.count
        })
    }
    @inlinable
    public func fade(out sample: Int, dB: Float64) {
        fade(prefix: .init(unsafeUninitializedCapacity: sample) {
            vDSP.formRamp(from: 0, through: 0.05 * M_LOG2E * M_LN10 * dB, result: &$0)
            vForce.exp2($0, result: &$0)
            $1 = $0.count
        })
    }
}
