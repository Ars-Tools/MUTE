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
@preconcurrency import typealias Combine.Just
import NSP
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
            let filter = Autorelease.Object(object: var1_create(stage)) {
                var1_destroy($0)
            }
            let cancel = λ.sink {
                var1_lambda(filter.reference, $0)
            }
            return { [cancel] in
                kernel($0, $1, $2, $3)
                var1_r(filter.reference,
                       $2, $3,
                       $2, $3,
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
            let filter = Autorelease.Object(object: var1_create(stage)) {
                var1_destroy($0)
            }
            let cancel = λ.sink {
                var1_lambda(filter.reference, $0)
            }
            return { [cancel, stage] in
                kernel($0, $1, $2, $3)
                var1_p(filter.reference,
                       $2, $3,
                       $2.advanced(by: 0 * $3 * stage), $3,
                       $2.advanced(by: 1 * $3 * stage), $3,
                       $1)
            }
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
            let filter = Autorelease.Object(object: var3_create(stage)) {
                var3_destroy($0)
            }
            let cancel = λ.sink {
                var3_lambda(filter.reference, $0)
            }
            return { [cancel, stage] in
                kernel($0, $1, $2, $3)
                var3_p(filter.reference,
                       $2, $3,
                       $2.advanced(by: 0 * $3 * stage), $3,
                       $2.advanced(by: 9 * $3 * stage), $3,
                       $1)
            }
        case 4:
            let filter = Autorelease.Object(object: var4_create(stage)) {
                var4_destroy($0)
            }
            let cancel = λ.sink {
                var4_lambda(filter.reference, $0)
            }
            return { [cancel, stage] in
                kernel($0, $1, $2, $3)
                var4_p(filter.reference,
                       $2, $3,
                       $2.advanced(by: 0x00 * $3 * stage), $3,
                       $2.advanced(by: 0x10 * $3 * stage), $3,
                       $1)
            }
        case let count: assert(0 < count)
            let filter = Autorelease.Object(object: var_create(count, stage)) {
                var_destroy($0)
            }
            let cancel = λ.sink {
                var_lambda(filter.reference, $0)
            }
            return { [cancel, count, stage] in
                kernel($0, $1, $2, $3)
                var_p(filter.reference,
                      $2, $3,
                      $2.advanced(by: 0 * count * count * $3 * stage), $3,
                      $2.advanced(by: 1 * count * count * $3 * stage), $3,
                      $1)
            }
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
            let stage = switch yc.quotientAndRemainder(dividingBy: 2 * 1) {
            case let answer where answer.remainder == .zero:
                answer.quotient
            default:
                throw Error.unmatch
            }
            let state = Autorelease.Memory(repeating: Float64.zero, count: stage)
            return { moment, length, target, stride in
                source(moment, length, target, stride)
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * 1 * stage * length) {
                    let memory = $0.baseAddress.unsafelyUnwrapped
                    kernel(moment, length, memory, length)
                    var1(target, stride,
                         target, stride,
                         memory.advanced(by: 0 * stage * length), length,
                         memory.advanced(by: 1 * stage * length), length,
                         state.start.assumingMemoryBound(to: Float64.self),
                         stage, length)
                }
            }
        case 2:
            let stage = switch yc.quotientAndRemainder(dividingBy: 2 * 4) {
            case let answer where answer.remainder == .zero:
                answer.quotient
            default:
                throw Error.unmatch
            }
            let state = Autorelease.Memory(repeating: SIMD2<Float64>.zero, count: stage)
            return { moment, length, target, stride in
                source(moment, length, target, stride)
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * 4 * stage * length) {
                    let memory = $0.baseAddress.unsafelyUnwrapped
                    kernel(moment, length, memory, length)
                    var2(target, stride,
                         target, stride,
                         memory.advanced(by: 0 * stage * length), length,
                         memory.advanced(by: 4 * stage * length), length,
                         state.start.assumingMemoryBound(to: SIMD2<Float64>.self),
                         stage, length)
                }
            }
        case 3:
            let stage = switch yc.quotientAndRemainder(dividingBy: 2 * 9) {
            case let answer where answer.remainder == .zero:
                answer.quotient
            default:
                throw Error.unmatch
            }
            let state = Autorelease.Memory(repeating: SIMD3<Float64>.zero, count: stage)
            return { moment, length, target, stride in
                source(moment, length, target, stride)
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * 9 * stage * length) {
                    let memory = $0.baseAddress.unsafelyUnwrapped
                    kernel(moment, length, memory, length)
                    var3(target, stride,
                         target, stride,
                         memory.advanced(by: 0 * stage * length), length,
                         memory.advanced(by: 9 * stage * length), length,
                         state.start.assumingMemoryBound(to: SIMD3<Float64>.self),
                         stage, length)
                }
            }
        case 4:
            let stage = switch yc.quotientAndRemainder(dividingBy: 2 * 16) {
            case let answer where answer.remainder == .zero:
                answer.quotient
            default:
                throw Error.unmatch
            }
            let state = Autorelease.Memory(repeating: SIMD4<Float64>.zero, count: stage)
            return { moment, length, target, stride in
                source(moment, length, target, stride)
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * 16 * stage * length) {
                    let memory = $0.baseAddress.unsafelyUnwrapped
                    kernel(moment, length, memory, length)
                    var4(target, stride,
                         target, stride,
                         memory.advanced(by: 0x00 * stage * length), length,
                         memory.advanced(by: 0x10 * stage * length), length,
                         state.start.assumingMemoryBound(to: SIMD4<Float64>.self),
                         stage, length)
                }
            }
        case let count:assert(0 < count)
            let stage = switch yc.quotientAndRemainder(dividingBy: 2 * count * count) {
            case let answer where answer.remainder == .zero:
                answer.quotient
            default:
                throw Error.unmatch
            }
            let space = stage * count * count
            let state = Autorelease.Memory(repeating: Float64.zero, count: space)
            return { moment, length, target, stride in
                source(moment, length, target, stride)
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * space * length + count * count) {
                    let memory = $0.baseAddress.unsafelyUnwrapped
                    kernel(moment, length, memory, length)
                    `var`(target, stride,
                          target, stride,
                          memory.advanced(by: 0 * space * length), length,
                          memory.advanced(by: 1 * space * length), length,
                          state.start.assumingMemoryBound(to: Float64.self),
                          memory.advanced(by: 2 * space * length),
                          count, stage, length)
                }
            }
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
