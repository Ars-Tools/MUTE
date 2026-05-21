//
//  Filter+Spectral.swift
//  MUTE
//
//  Created by CodingAssistant on 5/21/26.
//
@preconcurrency import protocol Combine.Publisher
import struct Synchronization.Mutex
import func Layout.broadcast
import Accelerate.vecLib
import typealias Auxiliary.Autorelease
import typealias Numerics.Complex128

public enum SpectralFilter {
    @usableFromInline
    struct Kr<Spectrum: Collection & Sendable, Updates: Publisher<(Int, Spectrum), Never> & Sendable> where Spectrum.Element == Complex128 {
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
                        let real = $0.advanced(by: frame * (2 + 2 * sr + index))
                        let imag = $0.advanced(by: frame * (2 + 2 * sr + fr + index))
                        vDSP_vclrD(real, 1, .init(frame))
                        vDSP_vclrD(imag, 1, .init(frame))
                        var offset = 0
                        for coefficient in value.prefix(nyquist + 1) {
                            let r = coefficient.real * scale
                            let i = coefficient.imag * scale
                            switch offset {
                            case 0:
                                real.pointee = r
                            case let bin where bin == nyquist:
                                real.advanced(by: nyquist).pointee = r
                            default:
                                real.advanced(by: offset).pointee = r
                                imag.advanced(by: offset).pointee = i
                                real.advanced(by: frame - offset).pointee = r
                                imag.advanced(by: frame - offset).pointee = -i
                            }
                            offset += 1
                        }
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

public func filter(_ source: Stream, spectrum: some Publisher<(Int, some Collection<Complex128> & Sendable), Never> & Sendable, extent: SIMD2<Int>) -> some Stream {
    SpectralFilter.Kr(stream: source, spectrum: spectrum, extent: extent)
}

public func filter(_ source: Stream, spectrum: some Collection<some Collection<Complex128> & Sendable>, length: Int) -> some Stream {
    filter(source, spectrum: spectrum.enumerated().publisher.map(\.self), extent: .init(spectrum.count, length))
}

public func filter(_ source: Stream, spectrum: some Collection<Complex128> & Sendable, length: Int) -> some Stream {
    filter(source, spectrum: CollectionOfOne(spectrum), length: length)
}
