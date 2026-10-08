//
//  Generator+TTS.swift
//  MUTE
//
//  Created by Kota on 10/2/26.
//
import typealias Synchronization.Mutex
@preconcurrency import typealias AVFoundation.AVAudioConverter
@preconcurrency import typealias AVFoundation.AVSpeechSynthesizer
@preconcurrency import typealias AVFoundation.AVSpeechUtterance
@preconcurrency import typealias AVFoundation.AVSpeechSynthesisVoice
@preconcurrency import typealias AVFoundation.AVAudioBuffer
@preconcurrency import typealias AVFoundation.AVAudioPCMBuffer
@preconcurrency import typealias AVFoundation.AVAudioConverterOutputStatus
@preconcurrency import typealias AVFoundation.AVSpeechSynthesisVoice
@preconcurrency import protocol Combine.Publisher
@preconcurrency import typealias Combine.Just
@preconcurrency import typealias Foundation.NSError
import typealias CLK.CMTime
import protocol DSP.Stream
import typealias DSP.Instance
import os.log
@usableFromInline
enum TTS {
    @usableFromInline
    struct Kr<Signal: Publisher<AVSpeechUtterance, Never> & Sendable> {
        @usableFromInline
        let signal: Signal
    }
}
extension TTS {
    @usableFromInline
    static let subsystem = OSLog(subsystem: String(describing: TTS.self), category: .pointsOfInterest)
}
extension TTS {
    @usableFromInline
    final class Bridge {
        @usableFromInline
        let converter: AVAudioConverter
        @usableFromInline
        var queue: ArraySlice<AVAudioBuffer>
        @inlinable
        init(from: AVAudioFormat, to: AVAudioFormat) throws {
            converter = switch AVAudioConverter(from: from, to: to) {
            case.some(let x):
                x
            case.none:
                throw Error.converterNotAllocated
            }
            queue = .init()
        }
    }
}
extension TTS.Bridge {
    @inlinable
    func render(to buffer: AVAudioPCMBuffer) {
        var error: NSError?
        let status = converter.convert(to: buffer, error: &error) { [unowned self] in
            if queue.isEmpty {
                $1.pointee = .noDataNow
                return.none
            } else {
                $1.pointee = .haveData
                return queue.popFirst()
            }
        }
        let handle = if case.some = error {
            .error
        } else {
            status
        } as AVAudioConverterOutputStatus
        switch handle {
        case.haveData:
//            os_log(.error, log: TTS.subsystem, "AVConverter Status: OK")
            break
        case.inputRanDry:
//            os_log(.error, log: TTS.subsystem, "AVConverter Status: DRY")
            break
        case.endOfStream:
            os_log(.error, log: TTS.subsystem, "AVConverter Status: EOF")
        case.error:
            os_log(.error, log: TTS.subsystem, "AVConverter Status: ERR, \(error)")
        @unknown default:
            assertionFailure("not implemented for \(String(reflecting: handle))")
        }
    }
    @inlinable
    var isEmpty: Bool {
        queue.isEmpty
    }
    @inlinable
    func append(_ buffer: AVAudioBuffer) {
        queue.append(buffer)
    }
    @inlinable
    func popFirst() -> Optional<AVAudioBuffer> {
        queue.popFirst()
    }
}
extension TTS.Kr: Stream {
    @inlinable
    var count: Int {
        1
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        guard case.some(let format) = AVAudioFormat(commonFormat: .pcmFormatFloat64, sampleRate: .init(interval.timescale) / .init(interval.value), discreteChannels: count, interleaved: false) else {
            throw Error.unsupportedFormat
        }
        let handler = try Mutex<TTS.Bridge>(.init(from: format, to: format))
        let core = AVSpeechSynthesizer()
        let sink = signal.sink { [core] in
            core.write($0) { packet in
                handler.withLock {
                    if $0.converter.inputFormat != packet.format {
                        do {
                            $0 = try.init(from: packet.format, to: format)
                        } catch {
                            return os_log(.error, log: TTS.subsystem, "no converter allocated")
                        }
                    }
                    $0.queue.append(packet)
                }
            }
        }
        instance.store(core, interval: interval, capacity: capacity)
        instance.store(sink, interval: interval, capacity: capacity)
        return {
            guard case.some(let target) = AVAudioPCMBuffer(pcmFormat: format, length: $1, target: $2, stride: $3) else {
                return os_log(.error, log: TTS.subsystem, "no buffer allocated")
            }
            target.frameLength = .init($1)
            handler.withLock {
                $0.render(to: target)
            }
        }
    }
}
public func tts(text signal: some Publisher<AVSpeechUtterance, Never> & Sendable) -> some Stream {
    TTS.Kr(signal: signal)
}
@inlinable
public func tts(text signal: some Publisher<String, Never>, voice: Optional<AVSpeechSynthesisVoice> = .none) -> some Stream {
    tts(text: signal.map {
        let utterance = AVSpeechUtterance(string: $0)
        utterance.voice = voice
        return utterance
    })
}
@inlinable
public func tts(text string: String) -> some Stream {
    tts(text: Just(string))
}
