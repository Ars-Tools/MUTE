//
//  Timestretch.swift
//  MUTE
//
//  Created by Kota on 10/20/25.
//
@preconcurrency import protocol Combine.Publisher
import Accelerate.vecLib
import typealias CoreMedia.CMTime
import protocol DSP.Stream
import typealias DSP.Instance
import typealias Auxiliary.Autorelease
import protocol Numerics.RationalNumber
import typealias Numerics.Rational128
@usableFromInline
enum Timestretch {
    @usableFromInline
    struct He<Source: Buffer.`Protocol`, Factor: RationalNumber> {
        @usableFromInline let source: Source
        @usableFromInline let factor: Factor
    }
}
extension Timestretch.He: Stream {
    @inlinable
    var count: Int {
        source.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let count = count
        let log2n = 14
        let frame = 1 << ( log2n - 0 )
        let shift = 1 << ( log2n - 4 )
        let dft = Autorelease.Opaque(pointer: vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped) {
            vDSP_destroy_fftsetupD($0)
        }
        let window = Array<Float64>(unsafeUninitializedCapacity: frame) {
            $1 = $0.count
            vDSP.clear(&$0)
            vDSP.formWindow(usingSequence: .hanningDenormalized, result: &$0[0..<$1/4], isHalfWindow: false)
        }
        let stream = try source(interval: interval, capacity: capacity, instance: &instance)
        let target = Buffer(stream: count, period: capacity + frame)
        return { [factor] in
            let cursor = $0.samples(for: interval)
            let remain = cursor - cursor.quotientAndRemainder(dividingBy: shift).remainder
            let offset = stride(from: remain, to: remain + $1, by: shift)
            let source = stream($0, $1)
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( 3 * count + 4 ) * frame) {
                var z = DSPDoubleSplitComplex(realp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 0 * count + 0 ) * frame),
                                              imagp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 1 * count + 0 ) * frame))
                var w = DSPDoubleSplitComplex(realp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * count + 0 ) * frame),
                                              imagp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * count + 2 ) * frame))
                let λ = $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 2 * count + 0 ) * frame )
                for offset in offset {
                    // fetch
                    let convey = offset * Int(factor.denominator) / Int(factor.numerator)
                    // radius
                    source.copy(cursor: convey, length: frame, target: z.realp, stride: frame)
                    for memory in stride(from: z.realp, to: z.realp.advanced(by: count * frame), by: frame) {
                        vDSP_vmulD(window, 1, memory, 1, memory, 1, .init(frame))
                    }
                    vDSP_vclrD(z.imagp, 1, .init(count * frame))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &z, 1, frame,
                                    &w,
                                    .init(log2n), .init(count),
                                    .init(kFFTDirection_Forward))
                    //
                    vDSP_zvabsD(&z, 1, λ, 1, .init(count * frame))
                    // radian
                    target.copy(cursor: offset, length: frame, target: z.realp, stride: frame)
                    for memory in stride(from: z.realp, to: z.realp.advanced(by: count * frame), by: frame) {
                        vDSP_vmulD(window, 1, memory, 1, memory, 1, .init(frame))
                    }
                    vDSP_vclrD(z.imagp, 1, .init(count * frame))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &z, 1, frame,
                                    &w,
                                    .init(log2n), .init(count),
                                    .init(kFFTDirection_Forward))
                    //
                    vDSP_zvphasD(&z, 1, z.imagp, 1, .init(count * frame))
                    vvsincos(z.imagp, z.realp, z.imagp, withUnsafePointer(to: Int32(count * frame), \.self))
                    // synth
                    vDSP_vmulD(λ, 1, z.realp, 1, z.realp, 1, .init(count * frame))
                    vDSP_vmulD(λ, 1, z.imagp, 1, z.imagp, 1, .init(count * frame))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &z, 1, frame,
                                    &w,
                                    .init(log2n), .init(count),
                                    .init(kFFTDirection_Inverse))
                    // merge
                    vDSP_vsdivD(z.realp, 1, withUnsafePointer(to: Float64(frame), \.self), z.realp, 1, .init(count * frame))
                    target.blend(cursor: offset, length: frame, weight: window, source: z.realp, stride: frame)
                }
            }
            target.copy(cursor: cursor, length: $1, target: $2, stride: $3)
            target.flush(cursor: cursor, length: $1)
        }
    }
}
public func timestretch(_ source: some Buffer.`Protocol`, rate factor: some RationalNumber) -> some Stream {
    Timestretch.He(source: source, factor: factor)
}
@_disfavoredOverload
public func timestretch(_ source: some Buffer.`Protocol`, rate factor: Rational128) -> some Stream {
    Timestretch.He(source: source, factor: factor)
}
extension Buffer {
    @inlinable
    public func timestretch(ratio: some RationalNumber<some Numeric>, to target: Buffer, log2n: Int = 14) {
        let frame = 1 << ( log2n - 0 )
        let shift = 1 << ( log2n - 4 )
        let count = Swift.min(stream, target.stream)
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
            vDSP_hann_windowD(w, .init(frame/4), .init(vDSP_HANN_DENORM))
            
            for cursor in stride(from: 0, to: target.period - frame, by: shift) {
                
                // fetch
                let lower = Swift.min(cursor * Int(ratio.denominator) / Int(ratio.numerator), period)
                let upper = Swift.min(lower + frame, period)
                let fetch = lower..<upper
                let clear = fetch.count..<frame
                
                // radius
                copy(cursor: fetch.lowerBound, length: fetch.count, target: x.realp, stride: frame)
                for r in stride(from: x.realp, to: x.realp.advanced(by: count * frame), by: frame) {
                    vDSP_vclrD(x.realp.advanced(by: clear.lowerBound), 1, .init(clear.count))
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
}
