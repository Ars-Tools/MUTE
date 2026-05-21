//
//  Filter+Spectral.swift
//  MUTE
//
//  Created by CodingAssistant on 5/21/26.
//
@preconcurrency import protocol Combine.Publisher
import protocol Accelerate.AccelerateBuffer
import struct Synchronization.Mutex
import func Layout.broadcast
import Accelerate.vecLib
import typealias Auxiliary.Autorelease
import typealias Numerics.Complex128

public enum SpectralFilter {
    @usableFromInline
    struct Kr<Spectrum: AccelerateBuffer & Collection & Sendable, Updates: Publisher<(Int, Spectrum), Never> & Sendable> where Spectrum.Element == Complex128 {
        @usableFromInline let stream: Stream
        @usableFromInline let spectrum: Updates
        @usableFromInline let extent: SIMD2<Int>
    }
}

extension SpectralFilter.Kr: Stream {
    @inlinable
    var count: Int {
        broadcast(x: stream.count, y: extent.x)
    }

    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let source = try stream(interval: interval, capacity: capacity, instance: &instance)
        let fr = extent.x
        let fc = extent.y
        let sr = stream.count
        let log2n = MemoryLayout<Int>.size * 8 - (capacity + fc - 2).leadingZeroBitCount
        let frame = 1 << log2n
        let setup = Autorelease.Opaque(pointer: vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped) { vDSP_destroy_fftsetupD($0) }
        let rr = broadcast(x: sr, y: fr)
        let fs = broadcast(x: rr, y: fr, z: frame)
        let ss = broadcast(x: rr, y: sr, z: frame)
        let rs = frame
        let nyquist = frame / 2
        let scale = 1 / Float64(frame)
        // [Work Real]
        // [Work Imag]
        // [Time Real] [0 ch] [1 ch] [2 ch] ...
        // [Time Imag] [0 ch] [1 ch] [2 ch] ...
        // [Task Real] [0] [1] ...
        // [Task Imag] [0] [1] ...
        // [Freq Real] [0 ch] [1 ch] [2 ch] ... [broadcast(S, F)]
        // [Freq Imag] [0 ch] [1 ch] [2 ch] ... [broadcast(S, F)]
        let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: (1 + sr + fr + rr) * 2 * frame))
        let cancel = spectrum.sink { index, value in
            switch index {
            case 0..<fr:
                buffer.withLock {
                    $0.withUnsafeMutablePointer {
                        var work = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (0)),
                                                         imagp: $0.advanced(by: frame * (1)))
                        var task = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 2 * sr + index)),
                                                         imagp: $0.advanced(by: frame * (2 + 2 * sr + fr + index)))
                        vDSP_vclrD(task.realp, 1, .init(frame))
                        vDSP_vclrD(task.imagp, 1, .init(frame))
                        let positive = nyquist + 1
                        let negative = Swift.max(0, nyquist - 1)
                        let length = Swift.min(value.count, positive)
                        value.withUnsafeBufferPointer {
                            guard let source = $0.baseAddress else { return }
                            source.withMemoryRebound(to: DSPDoubleComplex.self, capacity: $0.count) {
                                vDSP_ctozD($0, 1, &task, 1, .init(length))
                            }
                        }
                        work.realp.pointee = scale
                        work.imagp.pointee = .zero
                        vDSP_zvzsmlD(&task, 1, &work, &task, 1, .init(length))
                        task.imagp.pointee = .zero
                        task.imagp.advanced(by: nyquist).pointee = .zero
                        let mirror = Swift.max(0, nyquist - 1)
                        var source = DSPDoubleSplitComplex(realp: task.realp.advanced(by: mirror),
                                                           imagp: task.imagp.advanced(by: mirror))
                        var target = DSPDoubleSplitComplex(realp: task.realp.advanced(by: positive),
                                                           imagp: task.imagp.advanced(by: positive))
                        vDSP_zvconjD(&source, -1, &target, 1, .init(negative))
                    }
                }
            default:
                assertionFailure("out of range")
            }
        }
        return { moment, length, memory, stride in
            withExtendedLifetime(cancel) {
                buffer.withLock {
                    $0.withUnsafeMutablePointer {
                        var work = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (0)),
                                                         imagp: $0.advanced(by: frame * (1)))
                        var time = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 0 * sr)),
                                                         imagp: $0.advanced(by: frame * (2 + 1 * sr)))
                        let task = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 2 * sr + 0 * fr)),
                                                         imagp: $0.advanced(by: frame * (2 + 2 * sr + 1 * fr)))
                        var freq = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 2 * sr + 2 * fr + 0 * rr)),
                                                         imagp: $0.advanced(by: frame * (2 + 2 * sr + 2 * fr + 1 * rr)))
                        source(moment, length, time.realp.advanced(by: fc - 1), stride)
                        assert(vDSP.sumOfMagnitudes(UnsafeBufferPointer(start: time.imagp, count: frame * sr)) == 0)
                        vDSP_fftm_zoptD(setup.pointer,
                                        &time, 1, frame,
                                        &freq, 1, frame,
                                        &work,
                                        .init(log2n), .init(sr), .init(kFFTDirection_Forward))
                        copy(x: time.realp, ldx: frame,
                             y: time.realp.advanced(by: length), ldy: frame,
                             rows: sr, cols: fc - 1)
                        for offset in (0..<rr).reversed() {
                            var x = DSPDoubleSplitComplex(realp: freq.realp.advanced(by: offset * ss),
                                                          imagp: freq.imagp.advanced(by: offset * ss))
                            var f = DSPDoubleSplitComplex(realp: task.realp.advanced(by: offset * fs),
                                                          imagp: task.imagp.advanced(by: offset * fs))
                            var y = DSPDoubleSplitComplex(realp: freq.realp.advanced(by: offset * rs),
                                                          imagp: freq.imagp.advanced(by: offset * rs))
                            vDSP_zvmulD(&x, 1, &f, 1, &y, 1, .init(frame), 0)
                        }
                        vDSP_fftm_ziptD(setup.pointer,
                                        &freq, 1, frame,
                                        &work,
                                        .init(log2n), .init(rr), .init(kFFTDirection_Inverse))
                        copy(x: freq.realp.advanced(by: fc - 1), ldx: frame,
                             y: memory, ldy: stride,
                             rows: rr, cols: length)
                    }
                }
            }
        }
    }
}

public func filter<Spectrum, Updates>(_ source: Stream, spectrum: Updates, extent: SIMD2<Int>) -> some Stream where Spectrum: AccelerateBuffer & Collection & Sendable, Spectrum.Element == Complex128, Updates: Publisher<(Int, Spectrum), Never> & Sendable {
    SpectralFilter.Kr(stream: source, spectrum: spectrum, extent: extent)
}

public func filter<Spectra, Spectrum>(_ source: Stream, spectrum: Spectra, length: Int) -> some Stream where Spectra: Collection & Sendable, Spectra.Element == Spectrum, Spectrum: AccelerateBuffer & Collection & Sendable, Spectrum.Element == Complex128 {
    filter(source, spectrum: spectrum.enumerated().publisher.map(\.self), extent: .init(spectrum.count, length))
}

public func filter<Spectrum>(_ source: Stream, spectrum: Spectrum, length: Int) -> some Stream where Spectrum: AccelerateBuffer & Collection & Sendable, Spectrum.Element == Complex128 {
    filter(source, spectrum: CollectionOfOne(spectrum), length: length)
}
