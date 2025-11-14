//
//  Adaptive+VAR.swift
//  MUTE
//
//  Created by Kota on 11/14/25.
//
import typealias CoreMedia.CMTime
import typealias Auxiliary.Autorelease
import protocol DSP.Stream
import typealias DSP.Instance
import typealias Synchronization.Mutex
import NSP
import Numerics
@preconcurrency import typealias Combine.Just
@usableFromInline
enum VAR {
    @usableFromInline
    struct Residual<Signal: Publisher<Float64, Never> & Sendable> {
        @usableFromInline let y: Stream
        @usableFromInline let λ: Signal
        @usableFromInline let stage: Int
    }
    @usableFromInline
    struct Kernel<Signal: Publisher<Float64, Never> & Sendable> {
        @usableFromInline let y: Stream
        @usableFromInline let λ: Signal
        @usableFromInline let stage: Int
    }
    @usableFromInline
    struct Filter {
        @usableFromInline let x: Stream
        @usableFromInline let y: Stream
    }
}
extension VAR.Residual: Stream {
    @inlinable
    var count: Int {
        y.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try y(interval: interval, capacity: capacity, instance: &instance)
        switch y.count {
        case 1:
            let filter = Autorelease.Object(object: lsl_create(stage)) {
                lsl_destroy($0)
            }
            let cancel = λ.sink {
                lsl_lambda(filter.reference, $0)
            }
            return { [cancel] in
                kernel($0, $1, $2, $3)
                lsl_r(filter.reference,
                      $2, $2,
                      $1)
            }
        case 2:
            let filter = Autorelease.Object(object: var2_create(stage)) {
                var2_destroy($0)
            }
            let cancel = λ.sink {
                var2_lambda(filter.reference, $0)
            }
            return { [cancel] in
                kernel($0, $1, $2, $3)
                var2_r(filter.reference,
                       $2, $3,
                       $2, $3,
                       $1)
            }
        case 3:
            let filter = Autorelease.Object(object: var3_create(stage)) {
                var3_destroy($0)
            }
            let cancel = λ.sink {
                var3_lambda(filter.reference, $0)
            }
            return { [cancel] in
                kernel($0, $1, $2, $3)
                var3_r(filter.reference,
                       $2, $3,
                       $2, $3,
                       $1)
            }
        case 4:
            let filter = Autorelease.Object(object: var4_create(stage)) {
                var4_destroy($0)
            }
            let cancel = λ.sink {
                var4_lambda(filter.reference, $0)
            }
            return { [cancel] in
                kernel($0, $1, $2, $3)
                var4_r(filter.reference,
                       $2, $3,
                       $2, $3,
                       $1)
            }
        case let count: assert(0 < count)
            let filter = Autorelease.Object(object: var_create(count, stage)) {
                var_destroy($0)
            }
            let cancel = λ.sink {
                var_lambda(filter.reference, $0)
            }
            return { [cancel] in
                kernel($0, $1, $2, $3)
                var_r(filter.reference,
                      $2, $3,
                      $2, $3,
                      $1)
            }
        }
    }
}
extension VAR.Kernel: Stream {
    @inlinable
    var count: Int {
        2 * stage * y.count * y.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try y(interval: interval, capacity: capacity, instance: &instance)
        switch y.count {
        case 1:
            fatalError()
        case 2:
            let filter = Autorelease.Object(object: var2_create(stage)) {
                var2_destroy($0)
            }
            let cancel = λ.sink {
                var2_lambda(filter.reference, $0)
            }
            return { [cancel, stage] in
                kernel($0, $1, $2, $3)
                var2_p(filter.reference,
                       $2, $3,
                       $2.advanced(by: 0 * $3 * stage), $3,
                       $2.advanced(by: 4 * $3 * stage), $3,
                       $1)
            }
        case 3:
            fatalError()
        case 4:
            fatalError()
        case let count: assert(0 < count)
            fatalError()
        }
    }
}
extension VAR.Filter: Stream {
    @usableFromInline
    enum Error: Swift.Error {
        case unmatch
    }
    @inlinable
    var count: Int {
        x.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let source = try x(interval: interval, capacity: capacity, instance: &instance)
        let kernel = try y(interval: interval, capacity: capacity, instance: &instance)
        let yc = y.count
        switch x.count {
        case 1:
            fatalError()
        case 2:
            let stage = switch yc.quotientAndRemainder(dividingBy: 2 * 4) {
            case let answer where answer.remainder == .zero:
                answer.quotient
            default:
                throw Error.unmatch
            }
            let state = Mutex<Array<SIMD2<Float64>>>(.init(repeating: .zero, count: stage + 1))
            return { moment, length, target, stride in
                source(moment, length, target, stride)
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * 4 * stage * length) {
                    let memory = $0.baseAddress.unsafelyUnwrapped
                    kernel(moment, length, memory, length)
                    state.withLock {
                        var2(target, stride,
                             target, stride,
                             memory.advanced(by: 0 * stage * length), length,
                             memory.advanced(by: 4 * stage * length), length,
                             &$0,
                             stage, length)
                    }
                }
            }
        case 3:
            fatalError()
        case 4:
            fatalError()
        case let xc:
            fatalError()
        }
    }
}
public func residual(target: Stream, `var` stage: Int, λ: some Publisher<Float64, Never> & Sendable) -> some Stream {
    VAR.Residual(y: target, λ: λ, stage: stage)
}
public func residual(target: Stream, `var` stage: Int, λ: Float64) -> some Stream {
    residual(target: target, var: stage, λ: Just(λ))
}
public func kernel(target: Stream, `var` stage: Int, λ: some Publisher<Float64, Never> & Sendable) -> some Stream {
    VAR.Kernel(y: target, λ: λ, stage: stage)
}
public func kernel(target: Stream, `var` stage: Int, λ: Float64) -> some Stream {
    kernel(target: target, var: stage, λ: Just(λ))
}
public func filter(_ x: Stream, `var` y: Stream) -> some Stream {
    VAR.Filter(x: x, y: y)
}
