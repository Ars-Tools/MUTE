//
//  CTF+Controller.swift
//  MUTE
//
//  Created by Kota on 9/14/26.
//
import Darwin
import DSP
import ESP
import Synchronization
import typealias Accelerate.vDSP
import typealias Numerics.Complex128
@preconcurrency import typealias Dispatch.DispatchSource
@preconcurrency import protocol Dispatch.DispatchSourceUserDataReplace
extension Int {
    @inlinable@inline(__always)@_transparent
    func align(up size: Int) -> Int {
        (((self - 1) / size) + 1) * size
    }
}
extension CTF {
    /**
     Estimate Y(ω)=G(ω)X(ω)+N(ω) for a channel (SISO)
     **/
    public final class SISOController<Exciter: Exciters.`Protocol`, Estimator: SISO.`Protocol`>: Sendable {
        @usableFromInline
        let buffer: Mutex<Buffer>
        @usableFromInline
        let window: Array<Float64>
        @usableFromInline
        let stride: Int // hop size
        @usableFromInline
        let signal: DispatchSourceUserDataReplace
        @usableFromInline
        let exciter: Exciter
        @usableFromInline
        let estimator: Estimator
        @usableFromInline
        let snapshot: Mutex<CTF.Snapshot>
        @inlinable
        public init(window: Array<Float64>, stride: Int, capacity: Int, exciter: Exciter, estimator: Estimator) {
            self.window = window
            self.stride = stride
            self.exciter = exciter
            self.estimator = estimator
            snapshot = .init(estimator.snapshot)
            buffer = .init(.init(stream: 2, period: (window.count + capacity).align(up: stride)))
            signal = DispatchSource.makeUserDataReplaceSource(queue: .init(label: "tools.ars.mute.isp.ctf.siso.controller", qos: .userInitiated)) // serial queue
            signal.setEventHandler { [unowned self] in
                self.process(cursor: .init(self.signal.data))
            }
            signal.resume()
        }
        deinit {
            signal.cancel()
        }
    }
}
extension CTF.SISOController {
    @inlinable
    func process(cursor pos: Int) { // pass endIndex of written buffer
        let cursor = pos - window.count
        let oi = Array<Float64>(unsafeUninitializedCapacity: 2 * window.count) {
            guard case.some(let target) = $0.baseAddress else { return }
            $1 = $0.count
            buffer.withLock {
                $0.fetch(cursor: ( cursor + $0.period ) % $0.period,
                         length: window.count,
                         window: window,
                         target: target,
                         stride: window.count)
            }
        }
        do {
            try estimator.update(sample: cursor,
                                 x: oi.prefix(window.count)/* Loudspeaker output */,
                                 y: oi.suffix(window.count)/* Microphone Input */)
            snapshot.withLock {
                $0 = estimator.snapshot
            }
        } catch {
            
        }
    }
}
extension CTF.SISOController {
    @inlinable
    func generate(sample: Int, length: Int, target: UnsafeMutablePointer<Float64>) {
        exciter.generate(sample: sample,
                         length: length,
                         target: target,
                         stride: length,
                         snapshot: snapshot.withLock(\.self))
    }
}
extension CTF.SISOController {
    @inlinable
    func dsp(sample: Int,
             length: Int,
             memory: UnsafeMutablePointer<Float64>, // o-i, row-major, [2][count]
             stride: Int) {
        generate(sample: sample,
                 length: length,
                 target: memory)
        assert(memory == memory.advanced(by: 0 * stride))
        assert(0 <= sample)
        defer {
            let lower = (sample + 1         ).align(up: stride)
            let upper = (sample + 1 + length).align(up: stride)
//            for cursor in Swift.stride(from: lower, to: upper, by: stride).suffix(1) {
//                signal.replace(data: .init(cursor))
//            }
            for cursor in Swift.stride(from: lower, to: upper, by: stride) {
                process(cursor: cursor)
            }
        }
        buffer.withLock {
            $0.copy(cursor: sample + window.count,
                    length: length,
                    source: memory,
                    stride: stride)
        }
    }
    @inlinable
    public func dsp(sample: Int, signal: some Collection<Float64>) -> Array<Float64> {
        .init(unsafeUninitializedCapacity: 2 * signal.count) {
            $1 = signal.count
            switch $0.dropFirst($1).update(fromContentsOf: signal) {
            case let eof:
                assert(eof == $0.endIndex)
            }
            dsp(sample: sample, length: $1, memory: $0.baseAddress.unsafelyUnwrapped, stride: $1)
        }
    }
}

//
//extension CTF {
//    /// SISO online probe/observation controller.
//    ///
//    /// Channel 0 of `buffer` is X (including pending overlap-add output) and
//    /// channel 1 is Y. Both therefore share one sample clock and one cursor.
//    public final class Controller<Transform: ESP.DFT.`Protocol`,
//                                  Estimator: Estimators.`Protocol`,
//                                  Generator: Exciters.`Protocol` >: @unchecked Sendable {
//        public let sampleRate: Float64
//        public let maximumCallbackFrameCount: Int
//        public let hopCount: Int
//
//        @usableFromInline let frameCount: Int
//        @usableFromInline let interval: CMTime
//        @usableFromInline let window: Array<Float64>
//        @usableFromInline let dft: Transform
//        @usableFromInline let estimator: Estimator
//        @usableFromInline let exciter: Generator
//        @usableFromInline let buffer: DSP.Buffer
//        @usableFromInline let frequency: Array<Float64>
//
//        @usableFromInline var analysisFrame: Array<Float64>
//        @usableFromInline var synthesisFrame: Array<Float64>
//        @usableFromInline var xTime: Array<Complex128>
//        @usableFromInline var yTime: Array<Complex128>
//        @usableFromInline var xSpectrum: Array<Complex128>
//        @usableFromInline var ySpectrum: Array<Complex128>
//
//        @usableFromInline var origin: CMTime?
//        @usableFromInline var cursor = 0
//        @usableFromInline var nextAnalysisStart = 0
//        @usableFromInline var nextSynthesisStart = 0
//        @usableFromInline var clearedUntil = 0
//
//        @inlinable
//        public init(sampleRate: Float64,
//                    maximumCallbackFrameCount: Int,
//                    hopCount: Int,
//                    window: Array<Float64>,
//                    dft: Transform,
//                    estimator: Estimator,
//                    exciter: Generator) {
//            precondition(sampleRate.isFinite && 0 < sampleRate)
//            precondition(0 < maximumCallbackFrameCount)
//            precondition(0 < hopCount)
//            precondition(!window.isEmpty)
//            precondition(dft.count == window.count)
//            precondition(sampleRate.rounded() == sampleRate)
//            precondition(sampleRate <= Float64(Int32.max))
//
//            self.sampleRate = sampleRate
//            self.maximumCallbackFrameCount = maximumCallbackFrameCount
//            self.hopCount = hopCount
//            self.frameCount = window.count
//            self.interval = .init(value: 1, timescale: .init(sampleRate))
//            self.window = window
//            self.dft = dft
//            self.estimator = estimator
//            self.exciter = exciter
//
//            // Retain one complete analyzable frame while a callback schedules
//            // up to one complete future synthesis frame into the same ring.
//            self.buffer = .init(stream: 2,
//                                period: 2 * window.count + maximumCallbackFrameCount)
//            self.frequency = (0..<window.count).map {
//                2 * .pi * sampleRate * Float64($0) / Float64(window.count)
//            }
//            self.analysisFrame = .init(repeating: 0, count: 2 * window.count)
//            self.synthesisFrame = .init(repeating: 0, count: 2 * window.count)
//            self.xTime = .init(repeating: .zero, count: window.count)
//            self.yTime = .init(repeating: .zero, count: window.count)
//            self.xSpectrum = .init(repeating: .zero, count: window.count)
//            self.ySpectrum = .init(repeating: .zero, count: window.count)
//        }
//
//        @inlinable
//        public func callAsFunction(at time: CMTime,
//                                   count: Int,
//                                   input: UnsafePointer<Float64>,
//                                   inputLeadingDimension: Int,
//                                   output: UnsafeMutablePointer<Float64>,
//                                   outputLeadingDimension: Int) {
//            precondition(0 <= count && count <= maximumCallbackFrameCount)
//            precondition(count <= inputLeadingDimension)
//            precondition(count <= outputLeadingDimension)
//            guard 0 < count else { return }
//
//            if origin == nil || CMTimeCompare(time, self.time(at: cursor)) != 0 {
//                reset(at: time)
//            }
//            let upper = cursor + count
//
//            copyToRing(input,
//                       ring: buffer.start.advanced(by: buffer.period),
//                       cursor: cursor,
//                       count: count)
//
//            while nextSynthesisStart < upper {
//                synthesize(at: nextSynthesisStart)
//                nextSynthesisStart += hopCount
//            }
//
//            copyFromRing(buffer.start,
//                         cursor: cursor,
//                         target: output,
//                         count: count)
//
//            while nextAnalysisStart + frameCount <= upper {
//                analyse(at: nextAnalysisStart)
//                nextAnalysisStart += hopCount
//            }
//            if clearedUntil < nextAnalysisStart {
//                buffer.flush(cursor: clearedUntil,
//                             length: nextAnalysisStart - clearedUntil)
//            }
//            clearedUntil = nextAnalysisStart
//            cursor = upper
//        }
//
//        @inlinable
//        public var callback: Callback {
//            { [self] in
//                callAsFunction(at: $0, count: $1,
//                               input: $2, inputLeadingDimension: $3,
//                               output: $4, outputLeadingDimension: $5)
//            }
//        }
//
//        @inlinable
//        public var snapshot: Snapshot { estimator.snapshot }
//
//        @usableFromInline
//        func reset(at time: CMTime) {
//            buffer.flush(cursor: 0, length: buffer.period)
//            estimator.reset()
//            origin = time
//            cursor = 0
//            nextAnalysisStart = 0
//            nextSynthesisStart = 0
//            clearedUntil = 0
//        }
//
//        @usableFromInline
//        func time(at sample: Int) -> CMTime {
//            guard let origin else { return .invalid }
//            return CMTimeAdd(origin,
//                             CMTimeMultiply(interval, multiplier: .init(sample)))
//        }
//
//        @usableFromInline
//        func synthesize(at start: Int) {
//            synthesisFrame.withUnsafeMutableBufferPointer { frame in
//                frame.update(repeating: 0)
//                exciter.generate(at: time(at: start),
//                                 count: frameCount,
//                                 output: frame.baseAddress.unsafelyUnwrapped,
//                                 outputLeadingDimension: frameCount,
//                                 snapshot: estimator.snapshot)
//                window.withUnsafeBufferPointer { window in
//                    buffer.merge(cursor: start,
//                                 length: frameCount,
//                                 window: window.baseAddress.unsafelyUnwrapped,
//                                 source: frame.baseAddress.unsafelyUnwrapped,
//                                 stride: frameCount)
//                }
//            }
//        }
//
//        @usableFromInline
//        func analyse(at start: Int) {
//            analysisFrame.withUnsafeMutableBufferPointer { frame in
//                window.withUnsafeBufferPointer { window in
//                    buffer.fetch(cursor: start,
//                                 length: frameCount,
//                                 window: window.baseAddress.unsafelyUnwrapped,
//                                 target: frame.baseAddress.unsafelyUnwrapped,
//                                 stride: frameCount)
//                }
//                for index in 0..<frameCount {
//                    xTime[index] = .init(real: frame[index], imag: 0)
//                    yTime[index] = .init(real: frame[frameCount + index], imag: 0)
//                }
//            }
//            xTime.withUnsafeBufferPointer { x in
//                xSpectrum.withUnsafeMutableBufferPointer { X in
//                    dft.forward(x: x.baseAddress.unsafelyUnwrapped,
//                                y: X.baseAddress.unsafelyUnwrapped)
//                }
//            }
//            yTime.withUnsafeBufferPointer { y in
//                ySpectrum.withUnsafeMutableBufferPointer { Y in
//                    dft.forward(x: y.baseAddress.unsafelyUnwrapped,
//                                y: Y.baseAddress.unsafelyUnwrapped)
//                }
//            }
//            estimator.update(.init(time: time(at: start),
//                                   frequency: frequency,
//                                   X: xSpectrum,
//                                   Y: ySpectrum))
//        }
//
//        @usableFromInline
//        func copyToRing(_ source: UnsafePointer<Float64>,
//                        ring: UnsafeMutablePointer<Float64>,
//                        cursor: Int,
//                        count: Int) {
//            let base = cursor % buffer.period
//            let head = Swift.min(count, buffer.period - base)
//            memmove(ring.advanced(by: base), source,
//                    head * MemoryLayout<Float64>.stride)
//            let tail = count - head
//            if 0 < tail {
//                memmove(ring, source.advanced(by: head),
//                        tail * MemoryLayout<Float64>.stride)
//            }
//        }
//
//        @usableFromInline
//        func copyFromRing(_ ring: UnsafePointer<Float64>,
//                          cursor: Int,
//                          target: UnsafeMutablePointer<Float64>,
//                          count: Int) {
//            let base = cursor % buffer.period
//            let head = Swift.min(count, buffer.period - base)
//            memmove(target, ring.advanced(by: base),
//                    head * MemoryLayout<Float64>.stride)
//            let tail = count - head
//            if 0 < tail {
//                memmove(target.advanced(by: head), ring,
//                        tail * MemoryLayout<Float64>.stride)
//            }
//        }
//
//    }
//}
