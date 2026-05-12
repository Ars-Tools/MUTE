//
//  Special+Lattice.swift
//  MUTE
//
//  Created by Kota on 5/11/26.
//
import typealias Accelerate.vDSP
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import func Accelerate.vDSP_wienerD
import typealias CoreMedia.CMTime
import protocol DSP.Stream
import protocol DSP.Kernel
import typealias DSP.Instance
import func NSP.lattice_filter_create
import func NSP.lattice_filter_destroy
import func NSP.lattice_filter_static
import func NSP.lattice_filter_active
import typealias Auxiliary.Autorelease
import typealias Synchronization.Mutex
import func simd.fma
@preconcurrency import protocol Combine.Publisher
extension Special {
    @usableFromInline
    enum Lattice {
        @usableFromInline
        struct Kr<Signal: Publisher<(Int, Kernel), Never> & Sendable, Kernel: DSP.Kernel<Float64>> {
            @usableFromInline let x₀: Stream
            @usableFromInline let p₀: Signal
            @usableFromInline let order: Int
        }
        @usableFromInline
        struct Ar {
            @usableFromInline let x₀: Stream
            @usableFromInline let p₀: Stream
        }
    }
}
extension Special.Lattice.Kr: Stream {
    @inlinable
    var count: Int {
        x₀.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let xₖ = try x₀(interval: interval, capacity: capacity, instance: &instance)
        let object = Autorelease.Object(object: lattice_filter_create(order, x₀.count)) {
            lattice_filter_destroy($0)
        }
        let parcor = Mutex<Array<Float64>>(.init(repeating: .zero, count: order * x₀.count))
        let cancel = p₀.sink {
            switch $0 {
            case 0..<object.reference.pointee.c:
                let value = $1.coefficients(for: interval)
                let range = $0 * object.reference.pointee.n ..< $0 * object.reference.pointee.n + value.count
                parcor.withLock {
                    $0.replaceSubrange(range, with: value)
                }
            default:
                assertionFailure("out of range")
            }
        }
        return {
            xₖ($0, $1, $2, $3)
            let object = withExtendedLifetime(cancel) { object }
            lattice_filter_static(object.reference,
                                  parcor.withLock(\.self), object.reference.pointee.n,
                                  $2, $3,
                                  $2, $3,
                                  $1)
        }
    }
}
extension Special.Lattice.Ar: Stream {
    @inlinable
    var count: Int {
        x₀.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let xₖ = try x₀(interval: interval, capacity: capacity, instance: &instance)
        let pₖ = try p₀(interval: interval, capacity: capacity, instance: &instance)
        let object = Autorelease.Object(object: lattice_filter_create(p₀.count, x₀.count)) {
            lattice_filter_destroy($0)
        }
        return { moment, length, target, stride in
            xₖ(moment, length, target, stride)
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: object.reference.pointee.n * length) {
                guard case.some(let source) = $0.baseAddress else { return }
                pₖ(moment, length, source, length)
                lattice_filter_active(object.reference,
                                      source, length,
                                      target, stride,
                                      target, stride,
                                      length)
            }
        }
    }
}
public func filter(_ source: Stream, stg pₙ: some Publisher<(Int, some Kernel<Float64>), Never> & Sendable, order: Int) -> some Stream {
    Special.Lattice.Kr(x₀: source, p₀: pₙ, order: order)
}
public func filter(_ source: Stream, stg pₙ: some Publisher<some Kernel<Float64>, Never>, order: Int) -> some Stream {
    filter(source, stg: pₙ.repeat(count: source.count), order: order)
}
public func filter(_ source: Stream, stg pₙ: some Sequence<some Kernel<Float64>>, order: Int) -> some Stream {
    filter(source, stg: pₙ.prefix(count: source.count), order: order)
}
public func filter(_ source: Stream, stg pₙ: some Kernel<Float64>) -> some Stream {
    filter(source, stg: `repeat`(pₙ, count: source.count), order: pₙ.count)
}
@_disfavoredOverload
public func filter(_ source: Stream, stg pₙ: Float64...) -> some Stream {
    filter(source, stg: pₙ)
}
public func filter(_ source: Stream, stg parcor: Stream) -> some Stream {
    Special.Lattice.Ar(x₀: source, p₀: parcor)
}

