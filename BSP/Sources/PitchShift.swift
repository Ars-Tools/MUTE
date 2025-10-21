//
//  PitchShift.swift
//  MUTE
//
//  Created by Kota on 10/12/25.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Just
import typealias CoreMedia.CMTime
import protocol DSP.Stream
import typealias DSP.Instance
import typealias DSP.Buffer
import typealias DSP.Framewise
import typealias DSP.Samples
import Accelerate.vecLib
import typealias Auxiliary.Autorelease
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
@usableFromInline
enum PitchShift {
    @usableFromInline
    struct Kr<Rate: Publisher<Float64, Never> & Sendable> {
        @usableFromInline let source: Stream
        @usableFromInline let window: Framewise.Window
        @usableFromInline let span: Float64
        @usableFromInline let rate: Rate
    }
    @usableFromInline
    struct Ar {
        @usableFromInline let source: Stream
        @usableFromInline let rate: Stream
    }
}
extension PitchShift.Kr: DSP.Stream {
    @inlinable
    var count: Int {
        source.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        let count = count
        let log2n = 14
        let frame = 1 << ( log2n - 0 )
        let shift = 1 << ( log2n - 4 )
        let window = Array<Float64>(unsafeUninitializedCapacity: frame) {
            $1 = $0.count
            vDSP.clear(&$0)
            vDSP.formWindow(usingSequence: .hanningDenormalized, result: &$0[0..<$1/4], isHalfWindow: false)
        }
        let dft = Autorelease.Opaque(pointer: vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped) {
            vDSP_destroy_fftsetupD($0)
        }
        let i = Buffer(stream: count, period: capacity + frame)
        let o = Buffer(stream: count, period: capacity + frame)
        let factor = Atomic<Float64>(0)
        let cancel = rate.sink {
            factor.store(max(0.5, min(2.0, $0)), ordering: .releasing)
        }
        return { [cancel] in
            let factor = factor.load(ordering: .acquiring)
            let offset = $0.samples(for: interval)
            let remain = offset - offset.quotientAndRemainder(dividingBy: shift).remainder
            let cursor = stride(from: remain, to: remain + $1, by: shift)
            kernel($0, $1, $2, $3)
            i.copy(cursor: offset + frame, length: $1, source: $2, stride: $3)
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( 3 * count + 4 ) * frame) {
                var z = DSPDoubleSplitComplex(realp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 0 * count + 0 ) * frame),
                                              imagp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 1 * count + 0 ) * frame))
                var w = DSPDoubleSplitComplex(realp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * count + 0 ) * frame),
                                              imagp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * count + 2 ) * frame))
                let λ = $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 2 * count + 0 ) * frame)
                for cursor in cursor {
                    //
                    vDSP_vrampD(withUnsafePointer(to: Float64(cursor), \.self),
                                withUnsafePointer(to: factor, \.self),
                                λ, 1, .init(frame))
                    // radius
                    i.read(cursor: λ, length: frame, target: z.realp, stride: frame)
                    for r in stride(from: z.realp, to: z.realp.advanced(by: count * frame), by: frame) {
                        vDSP_vmulD(r, 1, window, 1, r, 1, .init(frame))
                    }
                    vDSP_vclrD(z.imagp, 1, .init(count * frame))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &z, 1, frame,
                                    &w,
                                    .init(log2n), .init(count),
                                    .init(kFFTDirection_Forward))
                    vDSP_zvabsD(&z, 1, λ, 1, .init(count * frame))
                    
                    // radian
                    o.copy(cursor: cursor, length: frame, target: z.realp, stride: frame)
                    for r in stride(from: z.realp, to: z.realp.advanced(by: count * frame), by: frame) {
                        vDSP_vmulD(r, 1, window, 1, r, 1, .init(frame))
                    }
                    vDSP_vclrD(z.imagp, 1, .init(count * frame))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &z, 1, frame,
                                    &w,
                                    .init(log2n), .init(count),
                                    .init(kFFTDirection_Forward))
                    vDSP_zvphasD(&z, 1, z.imagp, 1, .init(count * frame))
                    
                    // synth
                    vvsincos(z.imagp, z.realp, z.imagp, withUnsafePointer(to: Int32(count * frame), \.self))
                    vDSP_vmulD(λ, 1, z.realp, 1, z.realp, 1, .init(count * frame))
                    vDSP_vmulD(λ, 1, z.imagp, 1, z.imagp, 1, .init(count * frame))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &z, 1, frame,
                                    &w,
                                    .init(log2n), .init(count),
                                    .init(kFFTDirection_Inverse))
                    vDSP_vsdivD(z.realp, 1,
                                withUnsafePointer(to: Float64(frame), \.self),
                                z.realp, 1,
                                .init(count * frame))
                    o.blend(cursor: cursor, length: frame, weight: window, source: z.realp, stride: frame)
                }
            }
            o.copy(cursor: offset, length: $1, target: $2, stride: $3)
            o.flush(cursor: offset, length: $1)
        }
    }
    @inlinable
    func callAsFunction0(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let stream = count
        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        let log2n = 12
        let period = 1 << ( log2n - 0 )
        let hoplen = 1 << ( log2n - 4 )
        let window = Array<Float64>(unsafeUninitializedCapacity: period) {
            $1 = $0.count
//            vDSP.formWindow(usingSequence: .hanningDenormalized, result: &$0, isHalfWindow: false)
            vDSP.clear(&$0)
            vDSP.formWindow(usingSequence: .hanningDenormalized, result: &$0[0..<$1/2], isHalfWindow: false)
        }
        let dft = Autorelease.Opaque(pointer: vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped) {
            vDSP_destroy_fftsetupD($0)
        }
        let i = Buffer(stream: stream, period: capacity + 2 * period)
        let o = Buffer(stream: stream, period: capacity + 2 * period)
        let factor = Mutex<(Array<Float64>, Array<Float64>)>((.init(repeating: .zero, count: period), .init(repeating: .zero, count: period)))
        let cancel = rate.sink {
            let ω = max(0.5, min(2.0, $0))
            factor.withLock {
                vDSP.formRamp(withInitialValue: 0, increment: ω, result: &$0.0)
                vDSP.divide($0.0, .init(period) / 4.0, result: &$0.1)
                vDSP.clip($0.1, to: 0.0 ... 2.0, result: &$0.1)
                vForce.cosPi($0.1, result: &$0.1)
                vDSP.add(multiplication: ($0.1, -0.5), 0.5, result: &$0.1)
            }
        }
        return {
            let (phasor, weight) = withExtendedLifetime(cancel) { factor.withLock(\.self) }
            let offset = $0.samples(for: interval)
            let remain = offset - offset.quotientAndRemainder(dividingBy: hoplen).remainder
            let cursor = stride(from: remain, to: remain + $1, by: hoplen)
            kernel($0, $1, $2, $3)
            i.copy(cursor: offset + period, length: $1, source: $2, stride: $3)
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( 3 * stream + 4 ) * period) {
                var z = DSPDoubleSplitComplex(realp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 0 * stream + 0 ) * period),
                                              imagp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 1 * stream + 0 ) * period))
                var w = DSPDoubleSplitComplex(realp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * stream + 0 ) * period),
                                              imagp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * stream + 2 ) * period))
                let λ = $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 2 * stream + 0 ) * period)
                for cursor in cursor {
                    //
                    vDSP_vsaddD(phasor, 1, withUnsafePointer(to: Float64(cursor), \.self), z.realp, 1, .init(period))
                    
                    // radius
                    i.read(cursor: z.realp, length: period, target: z.realp, stride: period)
                    for r in stride(from: z.realp, to: z.realp.advanced(by: stream * period), by: period) {
                        vDSP_vmulD(r, 1, window, 1, r, 1, .init(period))
                    }
                    vDSP_vclrD(z.imagp, 1, .init(stream * period))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &z, 1, period,
                                    &w,
                                    .init(log2n), .init(stream),
                                    .init(kFFTDirection_Forward))
                    vDSP_zvabsD(&z, 1, λ, 1, .init(stream * period))
                    
                    // radian
                    o.copy(cursor: cursor, length: period, target: z.realp, stride: period)
                    for r in stride(from: z.realp, to: z.realp.advanced(by: stream * period), by: period) {
                        vDSP_vmulD(r, 1, window, 1, r, 1, .init(period))
                    }
                    vDSP_vclrD(z.imagp, 1, .init(stream * period))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &z, 1, period,
                                    &w,
                                    .init(log2n), .init(stream),
                                    .init(kFFTDirection_Forward))
                    vDSP_zvphasD(&z, 1, z.imagp, 1, .init(stream * period))
                    
                    // synth
                    vvsincos(z.imagp, z.realp, z.imagp, withUnsafePointer(to: Int32(stream * period), \.self))
                    vDSP_vmulD(λ, 1, z.realp, 1, z.realp, 1, .init(stream * period))
                    vDSP_vmulD(λ, 1, z.imagp, 1, z.imagp, 1, .init(stream * period))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &z, 1, period,
                                    &w,
                                    .init(log2n), .init(stream),
                                    .init(kFFTDirection_Inverse))
                    vDSP_vsdivD(z.realp, 1,
                                withUnsafePointer(to: Float64(period), \.self),
                                z.realp, 1,
                                .init(stream * period))
                    o.blend(cursor: cursor, length: period, weight: window, source: z.realp, stride: period)
                }
            }
            o.copy(cursor: offset, length: $1, target: $2, stride: $3)
            o.flush(cursor: offset, length: $1)
        }
    }
    @inlinable
    func callAsFunction1(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let stream = count
        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        let log2n = 11
        let period = 1 << log2n
        let hoplen = 1 << ( log2n - 3 )
        let window = vDSP.window(ofType: Float64.self, usingSequence: .hanningDenormalized, count: period, isHalfWindow: false)
        let dft = Autorelease.Opaque(pointer: vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped) {
            vDSP_destroy_fftsetupD($0)
        }
        let i = Buffer(stream: stream, period: 3 * capacity + 3 * period)
        let o = Buffer(stream: stream, period: 3 * capacity + 3 * period)
        let factor = Atomic<Float64>(1)
        let cancel = rate.sink {
            factor.store($0, ordering: .releasing)
        }
        return {
            let factor = withExtendedLifetime(cancel) { factor.load(ordering: .acquiring) }
            let offset = $0.samples(for: interval)
            let remain = offset.quotientAndRemainder(dividingBy: hoplen).remainder
            let cursor = stride(from: offset - remain, to: offset + $1 - remain, by: hoplen)
            kernel($0, $1, $2, $3)
            i.copy(cursor: offset + period, length: $1, source: $2, stride: $3)
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( 3 * stream + 4 ) * period) {
                var a = DSPDoubleSplitComplex(realp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 0 * stream + 0 ) * period),
                                              imagp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 1 * stream + 0 ) * period))
                var b = DSPDoubleSplitComplex(realp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * stream + 0 ) * period),
                                              imagp: $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 3 * stream + 2 ) * period))
                let memory = $0.baseAddress.unsafelyUnwrapped.advanced(by: ( 2 * stream + 0 ) * period)
                for cursor in cursor {
                    //
                    vDSP_vrampD(withUnsafePointer(to: Float64(cursor), \.self),
                                withUnsafePointer(to: factor, \.self),
                                a.realp, 1, .init(period))
                    // radius
                    i.read(cursor: a.realp, length: period, target: a.realp, stride: period)
                    vDSP_vclrD(memory, 1, .init(period))
                    vDSP_hann_windowD(memory, .init(Float64(period) / max(1, factor)), .init(vDSP_HANN_DENORM))
                    for r in Swift.stride(from: a.realp, to: a.realp.advanced(by: stream * period), by: period) {
                        vDSP_vmulD(r, 1, memory, 1, r, 1, .init(period))
                    }
                    vDSP_vclrD(a.imagp, 1, .init(stream * period))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &a, 1, period,
                                    &b,
                                    .init(log2n), .init(stream),
                                    .init(kFFTDirection_Forward))
                    vDSP_zvabsD(&a, 1, memory, 1, .init(stream * period))
                    
                    // radian
                    o.copy(cursor: cursor, length: period, target: a.realp, stride: period)
                    for r in Swift.stride(from: a.realp, to: a.realp.advanced(by: stream * period), by: period) {
                        vDSP_vmulD(r, 1, window, 1, r, 1, .init(period))
                    }
                    vDSP_vclrD(a.imagp, 1, .init(stream * period))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &a, 1, period,
                                    &b,
                                    .init(log2n), .init(stream),
                                    .init(kFFTDirection_Forward))
                    vDSP_zvphasD(&a, 1, a.imagp, 1, .init(stream * period))
                    
                    // synth
                    vvsincos(a.imagp, a.realp, a.imagp, withUnsafePointer(to: Int32(stream * period), \.self))
                    vDSP_vmulD(memory, 1, a.realp, 1, a.realp, 1, .init(stream * period))
                    vDSP_vmulD(memory, 1, a.imagp, 1, a.imagp, 1, .init(stream * period))
                    vDSP_fftm_ziptD(dft.pointer,
                                    &a, 1, period,
                                    &b,
                                    .init(log2n), .init(stream),
                                    .init(kFFTDirection_Inverse))
                    vDSP_vsdivD(a.realp, 1,
                                withUnsafePointer(to: Float64(period), \.self),
                                a.realp, 1,
                                .init(stream * period))
//                    o.merge(cursor: cursor, length: period, window: window, source: a.realp, stride: period)
                    o.blend(cursor: cursor, length: period, weight: window, source: a.realp, stride: period)
                }
            }
            o.copy(cursor: offset, length: $1, target: $2, stride: $3)
            o.flush(cursor: offset, length: $1)
        }
    }
//    @inlinable
//    func callAsFunction3(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//        let stream = count
//        let window = window.coefficients(for: interval)
//        let masker = Array<Float64>(unsafeUninitializedCapacity: window.count) {
//            vDSP.add(multiplication: (window, -1), 1, result: &$0)
//            $1 = $0.count
//        }
//        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
//        let i = Buffer(stream: stream, period: 2 * (capacity + window.count))
//        let o = Buffer(stream: stream, period: 2 * (capacity + window.count))
//        let dft = Autorelease.Object(object: bdft_create(window.count)) {
//            bdft_destroy($0)
//        }
//        let factor = Atomic<Float64>(1)
//        let cancel = rate.sink {
//            factor.store($0, ordering: .releasing)
//        }
//        return { moment, length, target, stride in
//            let rate = withExtendedLifetime(cancel) { factor.load(ordering: .acquiring) }
//            i.copy(cursor: moment.samples(for: interval) + window.count, length: length) {
//                kernel(moment, length, $0, $1)
//            }
//            withUnsafeTemporaryAllocation(byteCount: stream * window.count * 4 * MemoryLayout<Complex128>.stride,
//                                          alignment: MemoryLayout<Complex128>.alignment) {
//                let source = $0.baseAddress.unsafelyUnwrapped.advanced(by: 0 * stream * window.count * MemoryLayout<Float64>.stride)
//                    .assumingMemoryBound(to: Float64.self)
//                let target = $0.baseAddress.unsafelyUnwrapped.advanced(by: 1 * stream * window.count * MemoryLayout<Float64>.stride)
//                    .assumingMemoryBound(to: Float64.self)
//                let time = $0.baseAddress.unsafelyUnwrapped.advanced(by: 2 * stream * window.count * MemoryLayout<Float64>.stride)
//                    .assumingMemoryBound(to: Complex128.self)
//                let freq = $0.baseAddress.unsafelyUnwrapped.advanced(by: 4 * stream * window.count * MemoryLayout<Float64>.stride)
//                    .assumingMemoryBound(to: Complex128.self)
//                var offset = moment
//                while offset < CMTimeAdd(moment, CMTimeMultiply(interval, multiplier: .init(length))) {
//                    let revise = CMTimeMultiplyByFloat64(offset, multiplier: rate)
//                    i.copy(cursor: offset.samples(for: interval), length: window.count, target: source, stride: window.count)
//                    o.copy(cursor: revise.samples(for: interval), length: window.count, target: target, stride: window.count)
//                    for cursor in Swift.stride(from: 0, to: stream * window.count, by: window.count) {
//                        PitchShift.PV(length: window.count,
//                                      object: dft.reference,
//                                      window: window,
//                                      masker: masker,
//                                      source: source.advanced(by: cursor),
//                                      target: target.advanced(by: cursor),
//                                      memory: source.advanced(by: cursor),
//                                      time: time,
//                                      freq: freq)
//                    }
//                    o.copy(cursor: revise.samples(for: interval), length: window.count, source: target, stride: window.count)
//                    offset = CMTimeAdd(offset, CMTimeMultiply(interval, multiplier: .init(window.count / 4)))
//                }
//            }
//            vDSP_vrampD(withUnsafePointer(to: CMTimeMultiplyByFloat64(moment, multiplier: rate).seconds / interval.seconds, \.self),
//                        withUnsafePointer(to: rate, \.self),
//                        target, 1,
//                        .init(length))
//            o.feed(cursor: target, length: length, target: target, stride: stride)
//            o.flush(cursor: CMTimeMultiplyByFloat64(moment, multiplier: rate).samples(for: interval),
//                    length: CMTimeMultiplyByFloat64(CMTimeMultiply(interval, multiplier: .init(length)), multiplier: rate).samples(for: interval))
//        }
//    }
}
public func pitchshift(_ source: Stream, rate: some Publisher<Float64, Never> & Sendable) -> some Stream {
    PitchShift.Kr(source: source, window: .hanning(4096 as Samples), span: 1, rate: rate)
}
public func pitchshift(_ source: Stream, rate: Float64) -> some Stream {
    pitchshift(source, rate: Just(rate))
}
extension Buffer {
    public func pitchshift() {
        
    }
}
