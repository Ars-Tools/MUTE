//
//  Special+Linkwitz-Riley.swift
//  MUTE
//
//  Created by Kota on 5/11/26.
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
extension Special {
    @usableFromInline
    enum Crossover {
        @usableFromInline
        struct Kr<Cutoff: Publisher<(Int, Frequency), Never> & Sendable> {
            @usableFromInline let source: Stream
            @usableFromInline let length: Int
            @usableFromInline let cutoff: Cutoff
        }
    }
}
extension Special.Crossover.Kr: Stream {
    @inlinable
    var count: Int {
        length + 1
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        guard 1 == source.count, 1 <= length else { throw Error.invalidChannel }
        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        let object = switch vDSP_biquadm_CreateSetupD(repeatElement([1,0,0,0,0], count: ( 2 * length ) * ( length + 1 )).flatMap(\.self), .init(2 * length), .init(length + 1)) {
        case.some(let opaque):
            Autorelease.Opaque(pointer: opaque, release: vDSP_biquadm_DestroySetupD)
        case.none:
            throw Error.failedToAllocate(vDSP_biquadm_SetupD.self)
        }
        let factor = 0.5.squareRoot()
        let cancel = cutoff.sink { [length] in
            if (0..<length).contains($0) {
                for cursor in 0...length {
                    let design = if cursor < $0 {[
                        .apf(ω₀: $1, quality: factor),
                        .raw(b₀: 1, b₁: 0, b₂: 0, a₁: 0, a₂: 0)
                    ]} else if cursor > $0 {[
                        .hpf(ω₀: $1, quality: factor),
                        .hpf(ω₀: $1, quality: factor)
                    ]} else {[
                        .lpf(ω₀: $1, quality: factor),
                        .lpf(ω₀: $1, quality: factor)
                    ]} as Array<BiquadFilter.Design>
                    let coefficients = design.flatMap {
                        withUnsafeBytes(of: $0.coefficients(for: interval)) {
                            $0.withMemoryRebound(to: Float64.self, Array.init)
                        }
                    }
                    assert(coefficients.count == 10)
                    vDSP_biquadm_SetCoefficientsDoubleD(object.pointer,
                                                        coefficients,
                                                        .init(2 * $0),
                                                        .init(cursor),
                                                        2, 1)
                }
            }
        }
        return { [length, cancel] in
            kernel($0, $1, $2.advanced(by: length * $3), $3)
            var x = Array<UnsafePointer<Float64>>(repeating: .init($2.advanced(by: length * $3)), count: length + 1)
            var y = stride(from: 0, to: length * $3 + $3, by: $3).map($2.advanced(by:))
            vDSP_biquadmD(object.pointer,
                          &x, 1,
                          &y, 1,
                          .init($1))
        }
    }
}
public func filter(_ source: Stream, xof: Array<Frequency>) -> some Stream {
    Special.Crossover.Kr(source: source, length: xof.count, cutoff: xof.enumerated().publisher.map(\.self))
}
