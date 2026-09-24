//
//  Filter+FIR.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
import struct Synchronization.Mutex
import typealias Accelerate.vDSP
import typealias Accelerate.DSPDoubleSplitComplex
import func Accelerate.vDSP_vclrD
import func Accelerate.vDSP_convD
import func Accelerate.vDSP_create_fftsetupD
import func Accelerate.vDSP_destroy_fftsetupD
import func Accelerate.vDSP_fftm_zoptD
import func Accelerate.vDSP_fftm_ziptD
import func Accelerate.vDSP_fft_ziptD
import func Accelerate.vDSP_zvmulD
import let Accelerate.kFFTRadix2
import let Accelerate.kFFTDirection_Forward
import let Accelerate.kFFTDirection_Inverse
import func NSP.transversal_filter_create
import func NSP.transversal_filter_destroy
import func NSP.transversal_filter_active
import typealias Auxiliary.Autorelease
extension Filter {
    public enum FIR {
        public enum Domain: Sendable {
            case time
            case freq
        }
        @usableFromInline
        struct Kr<Signal: Publisher<(Int, Kernel), Never> & Sendable, Kernel: Filter.Kernel<Float64>> {
            @usableFromInline let x: Stream
            @usableFromInline let z: Signal
            @usableFromInline let b: Int // length of kernel
            @usableFromInline let d: Domain
        }
        @usableFromInline
        struct Ar {
            @usableFromInline let x: Stream
            @usableFromInline let b: Stream
        }
    }
}
extension Filter.FIR.Kr: Stream {
	@inlinable
	var count: Int {
        x.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let source = try x(interval: interval, capacity: capacity, instance: &instance)
        let xs = capacity + b - 1
        switch (d, x.count) {
        case(.time, let xc):
            let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: xc * xs + xc * b))
            let cancel = z.sink {
                switch $0 {
                case 0..<xc:
                    let kernel = $1.coefficients(for: interval).prefix(b)
                    let base = xc * xs + $0 * b
                    let head = base..<base+kernel.count
                    let tail = head.upperBound..<base+b
                    buffer.withLock {
                        $0.replaceSubrange(head, with: kernel.reversed())
                        $0.replaceSubrange(tail, with: repeatElement(.zero, count: tail.count))
                    }
                default:
                    assertionFailure("out of range")
                }
            }
            return { [cancel, b, xc, xs] moment, length, memory, stride in
                buffer.withLock {
                    $0.withUnsafeMutablePointer { signal in
                        let filter = signal.advanced(by: xc * xs)
                        source(moment, length, signal.advanced(by: b - 1), xs)
                        for c in 0..<xc {
                            vDSP_convD(signal.advanced(by: c * xs), 1,
                                       filter.advanced(by: c * b), 1,
                                       memory.advanced(by: c * stride), 1,
                                       .init(length), .init(b))
                        }
                        copy(x: signal.advanced(by: length), ldx: xs,
                             y: signal, ldy: xs,
                             rows: xc, cols: b - 1)
                    }
                }
            }
        case(.freq, let xc):
            let log2n = Int.bitWidth - (xs - 1).leadingZeroBitCount
            let frame = 1 << log2n
            let setup = Autorelease.Opaque(pointer: vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped) {
                vDSP_destroy_fftsetupD($0)
            }
            // [Work Real] mutual exclusive by mutex
            // [Work Imag]
            // [Task Real] [0 ch] [1 ch] [2 ch] …
            // [Task Imag] [0 ch] [1 ch] [2 ch] …
            // [Time Real] [0 ch] [1 ch] [2 ch] …
            // [Time Imag] [0 ch] [1 ch] [2 ch] …
            // [Freq Real] [0 ch] [1 ch] [2 ch] …
            // [Freq Imag] [0 ch] [1 ch] [2 ch] …
            let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: frame * ( 6 * xc + 2 ) ))
            let cancel = z.sink { index, value in
                switch index {
                case 0..<xc:
                    let kernel = value.coefficients(for: interval).prefix(b)
                    buffer.withLock {
                        $0.withUnsafeMutablePointer {
                            var w = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * 0),
                                                          imagp: $0.advanced(by: frame * 1))
                            var k = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 0 * xc + index)),
                                                          imagp: $0.advanced(by: frame * (2 + 1 * xc + index)))
                            let r = UnsafeMutableBufferPointer(start: k.realp, count: frame)
                            let i = UnsafeMutableBufferPointer(start: k.imagp, count: frame)
                            switch r.update(fromContentsOf: kernel) {
                            case let eof:
                                vDSP.divide(r[0..<eof], .init(frame), result: &r[0..<eof])
                                vDSP.clear(&r[eof..<r.endIndex])
                            }
                            vDSP.clear(&i[0..<i.count])
                            vDSP_fft_ziptD(setup.pointer, &k, 1, &w, .init(log2n), .init(kFFTDirection_Forward))
                        }
                    }
                default:
                    assertionFailure("out of range")
                }
            }
            return { [cancel, b] moment, length, memory, stride in
                withExtendedLifetime(cancel) {
                    buffer.withLock {
                        $0.withUnsafeMutablePointer {
                            var w = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * 0),
                                                          imagp: $0.advanced(by: frame * 1))
                            var k = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 0 * xc)),
                                                          imagp: $0.advanced(by: frame * (2 + 1 * xc)))
                            var t = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 2 * xc)),
                                                          imagp: $0.advanced(by: frame * (2 + 3 * xc)))
                            var f = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 4 * xc)),
                                                          imagp: $0.advanced(by: frame * (2 + 5 * xc)))
                            source(moment, length, t.realp.advanced(by: b - 1), frame)
                            for p in Swift.stride(from: length + b - 1, to: length + b - 1 + xc * frame, by: frame).map(t.realp.advanced(by:)) {
                                vDSP_vclrD(p, 1, .init(frame - length - b + 1))
                            }
                            assert(vDSP.sumOfSquares(UnsafeMutableBufferPointer(start: t.imagp, count: frame * xc)).isZero)
                            vDSP_fftm_zoptD(setup.pointer,
                                            &t, 1, frame,
                                            &f, 1, frame,
                                            &w,
                                            .init(log2n),
                                            .init(xc),
                                            .init(kFFTDirection_Forward))
                            vDSP_zvmulD(&f, 1, &k, 1, &f, 1, .init(frame * xc), 1)
                            vDSP_fftm_ziptD(setup.pointer,
                                            &f, 1, frame,
                                            &w,
                                            .init(log2n),
                                            .init(xc),
                                            .init(kFFTDirection_Inverse))
                            copy(x: f.realp.advanced(by: b - 1), ldx: frame,
                                 y: memory, ldy: stride,
                                 rows: xc, cols: length)
                            copy(x: t.realp, ldx: frame,
                                 y: t.realp.advanced(by: length), ldy: frame,
                                 rows: xc, cols: b - 1)
                        }
                    }
                }
            }
        }
	}
}
extension Filter.FIR.Ar: Stream {
    @inlinable
    var count: Int {
        x.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let bc = b.count
        let bk = try b(interval: interval, capacity: capacity, instance: &instance)
        let xk = try x(interval: interval, capacity: capacity, instance: &instance)
        switch x.count {
        case 1:
            let object = Autorelease.Object(object: transversal_filter_create(bc, 1)) {
                transversal_filter_destroy($0)
            }
            return { [object] moment, length, target, stride in
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: bc * length + length) {
                    let b = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(length))
                    vDSP.fill(&$0[0..<length], with: 1)
                    xk(moment, length, target, stride)
                    bk(moment, length, b.baseAddress.unsafelyUnwrapped, length)
                    transversal_filter_active(object.reference,
                                              b.baseAddress.unsafelyUnwrapped, length,
                                              $0.baseAddress.unsafelyUnwrapped, length,
                                              target,
                                              target,
                                              length)
                }
            }
        case let xc:
            let object = Autorelease.Object(object: transversal_filter_create(bc, 1, xc)) {
                transversal_filter_destroy($0)
            }
            return { [object] moment, length, target, stride in
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: bc * length + length) {
                    let b = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(length))
                    vDSP.fill(&$0[0..<length], with: 1)
                    xk(moment, length, target, stride)
                    bk(moment, length, b.baseAddress.unsafelyUnwrapped, length)
                    transversal_filter_active(object.reference,
                                              b.baseAddress.unsafelyUnwrapped, length,
                                              $0.baseAddress.unsafelyUnwrapped, length,
                                              target, stride,
                                              target, stride,
                                              length)
                }
            }
        }
    }
}
@_disfavoredOverload
public func filter(_ source: Stream, fir kernel: some Publisher<(Int, some Filter.Kernel<Float64>), Never> & Sendable, count: Int, domain: Optional<Filter.FIR.Domain> = .none) -> some Stream {
    Filter.FIR.Kr(x: source, z: kernel, b: count, d: domain ?? .time)
}
@inlinable
public func filter(_ source: Stream, fir kernel: some Publisher<some Filter.Kernel<Float64>, Never>, count: Int) -> some Stream {
    filter(source, fir: kernel.repeat(count: source.count), count: count)
}
@inlinable
public func filter(_ source: Stream, fir kernel: some Sequence<some Filter.Kernel<Float64>>) -> some Stream {
    filter(source, fir: kernel.prefix(count: source.count), count: .init(kernel.map(\.count).max() ?? 0))
}
@inlinable
public func filter(_ source: Stream, fir kernel: some Filter.Kernel<Float64>) -> some Stream {
    filter(source, fir: `repeat`(kernel, count: source.count), count: .init(kernel.count))
}
@_disfavoredOverload
public func filter(_ source: Stream, fir kernel: Stream) -> some Stream {
    Filter.FIR.Ar(x: source, b: kernel)
}
//extension Filter {
//    public enum FIR {
//        public enum Domain: Sendable {
//            case time
//            case freq
//        }
//        @usableFromInline
//        struct Kr<Signal: Publisher<(Int, Kernel), Never> & Sendable, Kernel: Filter.Kernel<Float64>> {
//            @usableFromInline let stream: Stream
//            @usableFromInline let kernel: Signal
//            @usableFromInline let extent: SIMD2<Int> // [channel][coefficients]
//            @usableFromInline let domain: Domain
//        }
//    }
//}
//extension Filter.FIR.Kr: Stream {
//    @inlinable
//    var count: Int {
//        broadcast(x: stream.count, y: extent.x)
//    }
//    @inlinable
//    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//        let source = try stream(interval: interval, capacity: capacity, instance: &instance)
//        let fr = extent.x
//        let fc = extent.y
//        let sr = stream.count
//        switch domain {
//        case.time:
//            let sc = capacity + fc - 1
//            let rr = broadcast(x: sr, y: fr)
//            let fs = broadcast(target: rr, source: fr, stride: fc)
//            let ss = broadcast(target: rr, source: sr, stride: sc)
//            let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: sr * sc + fr * fc))
//            let cancel = kernel.sink {
//                let value = $1.coefficients(for: interval).prefix(fc)
//                let start = sr * sc + $0 * fc
//                let head = start..<start+value.count
//                let tail = head.upperBound..<start+fc
//                buffer.withLock {
//                    $0.replaceSubrange(head, with: value.reversed())
//                    $0.replaceSubrange(tail, with: repeatElement(.zero, count: tail.count))
//                }
//            }
//            return { [cancel] moment, length, memory, stride in
//                buffer.withLock {
//                    $0.withUnsafeMutablePointer { signal in
//                        let filter = signal.advanced(by: sr * sc)
//                        source(moment, length, signal.advanced(by: fc - 1), sc)
//                        for offset in 0..<rr {
//                            vDSP_convD(signal.advanced(by: offset * ss), 1,
//                                       filter.advanced(by: offset * fs), 1,
//                                       memory.advanced(by: offset * stride), 1,
//                                       .init(length), .init(fc))
//                        }
//                        copy(x: signal.advanced(by: length), ldx: sc,
//                             y: signal, ldy: sc,
//                             rows: sr, cols: fc - 1)
//                    }
//                }
//            }
//        case.freq:
//            let source = try stream(interval: interval, capacity: capacity, instance: &instance)
//            let log2n = MemoryLayout<Int>.size * 8 - (capacity + fc - 2).leadingZeroBitCount
//            let frame = 1 << log2n
//            let setup = Autorelease.Opaque(pointer: vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped) { vDSP_destroy_fftsetupD($0) }
//            let rr = broadcast(x: sr, y: fr)
//            let fs = broadcast(x: rr, y: fr, z: frame)
//            let ss = broadcast(x: rr, y: sr, z: frame)
//            let rs = frame
//            // [Work Real]
//            // [Work Imag]
//            // [Time Real] [0 ch] [1 ch] [2 ch] …
//            // [Time Imag] [0 ch] [1 ch] [2 ch] …
//            // [Task Real] [0] [1] …
//            // [Task Imag] [0] [1] …
//            // [Freq Real] [0 ch] [1 ch] [2 ch] … [broadcast(S, F)]
//            // [Freq Imag] [0 ch] [1 ch] [2 ch] … [broadcast(S, F)]
//            let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: ( 1 + sr + fr + rr ) * 2 * frame))
//            let cancel = kernel.sink { index, value in
//                switch index {
//                case 0..<fr:
//                    buffer.withLock {
//                        $0.withUnsafeMutablePointer {
//                            var work = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (0)),
//                                                             imagp: $0.advanced(by: frame * (1)))
//                            var task = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 2 * sr + index)),
//                                                             imagp: $0.advanced(by: frame * (2 + 2 * sr + fr)))
//                            vDSP_vclrD(task.imagp, 1, .init(frame))
//                            let buff = UnsafeMutableBufferPointer(start: task.realp, count: frame)
//                            buff[buff.update(fromContentsOf: value.coefficients(for: interval))...].update(repeating: .zero)
//                            work.realp.pointee = .init(frame)
//                            vDSP_vsdivD(task.realp, 1, work.realp, task.realp, 1, .init(fc))
//                            vDSP_fft_ziptD(setup.pointer, &task, 1, &work, .init(log2n), .init(kFFTDirection_Forward))
//                        }
//                    }
//                default:
//                    assertionFailure("out of range")
//                }
//            }
//            return { moment, length, memory, stride in
//                withExtendedLifetime(cancel) {
//                    buffer.withLock {
//                        $0.withUnsafeMutablePointer {
//                            var work = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (0)),
//                                                             imagp: $0.advanced(by: frame * (1)))
//                            var time = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 0 * sr)),
//                                                             imagp: $0.advanced(by: frame * (2 + 1 * sr)))
//                            let task = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 2 * sr + 0 * fr)),
//                                                             imagp: $0.advanced(by: frame * (2 + 2 * sr + 1 * fr)))
//                            var freq = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 2 * sr + 2 * fr + 0 * rr)),
//                                                             imagp: $0.advanced(by: frame * (2 + 2 * sr + 2 * fr + 1 * rr)))
//                            source(moment, length, time.realp.advanced(by: fc - 1), stride)
//                            assert(vDSP.sumOfMagnitudes(UnsafeBufferPointer(start: time.imagp, count: frame * sr)) == 0)
//                            vDSP_fftm_zoptD(setup.pointer,
//                                            &time, 1, frame,
//                                            &freq, 1, frame,
//                                            &work,
//                                            .init(log2n), .init(sr), .init(kFFTDirection_Forward))
//                            copy(x: time.realp, ldx: frame,
//                                 y: time.realp.advanced(by: length), ldy: frame,
//                                 rows: sr, cols: fc - 1)
//                            for offset in (0..<rr).reversed() {
//                                var x = DSPDoubleSplitComplex(realp: freq.realp.advanced(by: offset * ss),
//                                                              imagp: freq.imagp.advanced(by: offset * ss))
//                                var f = DSPDoubleSplitComplex(realp: task.realp.advanced(by: offset * fs),
//                                                              imagp: task.imagp.advanced(by: offset * fs))
//                                var y = DSPDoubleSplitComplex(realp: freq.realp.advanced(by: offset * rs),
//                                                              imagp: freq.imagp.advanced(by: offset * rs))
//                                vDSP_zvmulD(&x, 1, &f, 1, &y, 1, .init(frame), 1)
//                            }
//                            vDSP_fftm_ziptD(setup.pointer,
//                                            &freq, 1, frame,
//                                            &work,
//                                            .init(log2n), .init(rr), .init(kFFTDirection_Inverse))
//                            copy(x: freq.realp.advanced(by: fc - 1), ldx: frame,
//                                 y: memory, ldy: stride,
//                                 rows: rr, cols: length)
//                        }
//                    }
//                }
//            }
//        }
//    }
//}
//@_disfavoredOverload
//public func filter(_ source: Stream, fir kernel: some Publisher<(Int, some Filter.Kernel<Float64>), Never> & Sendable, counts: SIMD2<Int>, domain: Filter.FIR.Domain = .time) -> some Stream {
//    Filter.FIR.Kr(stream: source, kernel: kernel, extent: counts, domain: domain)
//}
//@inlinable
//public func filter(_ source: Stream, fir kernel: some Publisher<some Filter.Kernel<Float64>, Never>, counts: SIMD2<Int>) -> some Stream {
//    filter(source, fir: kernel.repeat(count: source.count), counts: counts)
//}
//@inlinable
//public func filter(_ source: Stream, fir kernel: some Sequence<some Filter.Kernel<Float64>>) -> some Stream {
//    filter(source, fir: kernel.prefix(count: source.count), counts: .init(source.count, kernel.map(\.count).max() ?? 0))
//}
//@inlinable
//public func filter(_ source: Stream, fir kernel: some Filter.Kernel<Float64>) -> some Stream {
//    filter(source, fir: `repeat`(kernel, count: source.count), counts: .init(source.count, kernel.count))
//}
//@_disfavoredOverload
//public func filter(_ source: Stream, fir kernel: Stream) -> some Stream {
//    filter(source, iir: (kernel, const(1)))
//}
