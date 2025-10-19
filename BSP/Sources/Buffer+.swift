//
//  Buffer+.swift
//  MUTE
//
//  Created by Kota on 10/15/25.
//
import Accelerate
import DSP
extension Buffer {
    @inlinable@_transparent
    public func maximize(dB: Float64 = 0) {
        let signal = zip(stride(from: start, to: start.advanced(by: stream * period), by: period), sequence(first: period, next: \.self)).map(UnsafeMutableBufferPointer.init(start:count:))
        switch vDSP.maximum(signal.map(vDSP.maximumMagnitude)) {
        case let normal where normal.isNormal:
            for signal in signal {
                vDSP.divide(signal, normal, result: &signal[0..<signal.count])
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
    static func stretch(from source: Buffer,
                        to target: inout Buffer,
                        log2n: Int = 12) {
        let ratio = Float64(source.period) / Float64(target.period)
        let frame = 1 << ( log2n - 0 )
        let shift = 1 << ( log2n - 8 )
        let count = Swift.max(source.stream, target.stream)
        let dft = vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped
        defer { vDSP_destroy_fftsetupD(dft) }
        target.flush(cursor: 0, length: target.period)
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( 3 * count + 5 ) * frame) {
            var x = DSPDoubleSplitComplex(realp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 0 * count + 0 ) * frame),
                                          imagp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 1 * count + 0 ) * frame))
            var y = DSPDoubleSplitComplex(realp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * count + 0 ) * frame),
                                          imagp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * count + 2 ) * frame))
            let z = $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 2 * count + 0 ) * frame)
            let w = $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * count + 4 ) * frame)
            
            // window
            vDSP_vclrD(w, 1, .init(frame))
            vDSP_hann_windowD(w, .init(frame / 2), .init(vDSP_HANN_DENORM))
            
            for cursor in stride(from: 0, to: target.period - frame, by: shift) {
                
                // fetch
                let convey = Int(ratio * Float64(cursor))
                
                // radius
                source.copy(cursor: convey, length: frame, target: x.realp, stride: frame)
                for r in stride(from: x.realp, to: x.realp.advanced(by: count * frame), by: frame) {
                    vDSP_vmulD(r, 1, w, 1, r, 1, .init(frame))
                }
                vDSP_vclrD(x.imagp, 1, .init(count * frame))
                vDSP_fftm_ziptD(dft,
                                &x, 1, frame,
                                &y,
                                .init(log2n), .init(count),
                                .init(kFFTDirection_Forward))
                vDSP_zvabsD(&x, 1, z, 1, .init(count * frame))
                
                // radian
                target.copy(cursor: cursor, length: frame, target: x.realp, stride: frame)
                for r in stride(from: x.realp, to: x.realp.advanced(by: count * frame), by: frame) {
                    vDSP_vmulD(r, 1, w, 1, r, 1, .init(frame))
                }
                vDSP_vclrD(x.imagp, 1, .init(count * frame))
                vDSP_fftm_ziptD(dft,
                                &x, 1, frame,
                                &y,
                                .init(log2n), .init(count),
                                .init(kFFTDirection_Forward))
                vDSP_zvphasD(&x, 1, x.imagp, 1, .init(count * frame))
                
                // synth
                vvsincos(x.imagp, x.realp, x.imagp, Swift.withUnsafePointer(to: Int32(count * frame), \.self))
                vDSP_vmulD(z, 1, x.realp, 1, x.realp, 1, .init(count * frame))
                vDSP_vmulD(z, 1, x.imagp, 1, x.imagp, 1, .init(count * frame))
                vDSP_fftm_ziptD(dft,
                                &x, 1, frame,
                                &y,
                                .init(log2n), .init(count),
                                .init(kFFTDirection_Inverse))
                vDSP_vsdivD(x.realp, 1,
                            Swift.withUnsafePointer(to: Float64(frame), \.self),
                            x.realp, 1,
                            .init(count * frame))
                target.blend(cursor: cursor, length: frame, weight: w, source: x.realp, stride: frame)
            }
        }
    }
    public func stretch(ratio: Float64, log2n: Int = 12) -> Buffer {
        var target = Buffer(stream: stream, period: .init(Float64(period) * ratio) + 1 << log2n)
        Buffer.stretch(from: self, to: &target, log2n: log2n)
        return target
    }
    public func stretch(to target: inout Buffer, log2n: Int = 12) {
        Buffer.stretch(from: self, to: &target, log2n: log2n)
    }
}
extension Buffer {
    @inlinable@_transparent
    func resample(to: inout Buffer) {
        
    }
}
