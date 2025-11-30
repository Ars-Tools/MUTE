//
//  Filter+Linkwitz-Riley.swift
//  MUTE
//
//  Created by Kota on 11/27/25.
//
@preconcurrency import protocol Combine.Publisher
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias Accelerate.vDSP
import typealias CoreMedia.CMTime
import func Layout.broadcast
import protocol DSP.Frequency
import protocol DSP.Stream
import typealias DSP.Instance
import typealias DSP.BiquadFilter
import typealias Accelerate.vDSP_biquadm_SetupD
import func Accelerate.vDSP_biquadm_CreateSetupD
import func Accelerate.vDSP_biquadm_DestroySetupD
import func Accelerate.vDSP_biquadm_SetCoefficientsDoubleD
import func Accelerate.vDSP_biquadmD
import typealias Auxiliary.Autorelease
@usableFromInline
enum CrossoverFilter {
    @usableFromInline
    struct Kr<Cutoff: Publisher<(Int, Frequency), Never> & Sendable> {
        @usableFromInline let source: Stream
        @usableFromInline let length: Int
        @usableFromInline let cutoff: Cutoff
    }
}
extension CrossoverFilter.Kr: Stream {
    @inlinable
    var count: Int {
        length
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        guard 1 == source.count, 1 <= length else { throw Error.invalidChannel }
        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        let object = switch vDSP_biquadm_CreateSetupD(repeatElement([1,0,0,0,0], count: (length &- 1) * length).flatMap(\.self), .init(length-1), .init(length)) {
        case.some(let opaque):
            Autorelease.Opaque(pointer: opaque) {
                vDSP_biquadm_DestroySetupD($0)
            }
        case.none:
            throw Error.failedToAllocate(vDSP_biquadm_SetupD.self)
        }
        let factor = 0.5.squareRoot()
        let cancel = cutoff.sink { [length] in
            if (0..<length).contains($0) {
                for cursor in 0..<length {
                    let design = if cursor < $0 {
                        .apf(ω₀: $1, quality: factor)
                    } else if cursor > $0 {
                        .hpf(ω₀: $1, quality: factor)
                    } else {
                        .lpf(ω₀: $1, quality: factor)
                    } as BiquadFilter.Design
                    vDSP_biquadm_SetCoefficientsDoubleD(object.pointer,
                                                        withUnsafeBytes(of: design.coefficients(for: interval)) {
                        $0.withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)
                    },
                                                        .init($0),
                                                        .init(cursor),
                                                        1, 1)
                }
            }
        }
        return { [length, cancel] in
            kernel($0, $1, $2, $3)
            var x = Array<UnsafePointer<Float64>>(repeating: .init($2), count: length)
            var y = stride(from: 0, to: length * $3, by: $3).map($2.advanced(by:))
            vDSP_biquadmD(object.pointer,
                          &x, 1,
                          &y, 1,
                          .init($1))
        }
    }
}
public func filter(_ source: Stream, xof: Array<Frequency>) -> some Stream {
    CrossoverFilter.Kr(source: source, length: xof.count, cutoff: xof.enumerated().publisher.map(\.self))
}
