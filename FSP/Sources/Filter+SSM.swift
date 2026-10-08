//
//  Filter+SSM.swift
//  MUTE
//
//  Created by Kota on 10/8/26.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Combine.Subscriber
@preconcurrency import typealias Combine.Just
@preconcurrency import typealias Combine.Future
@preconcurrency import typealias Combine.AnyCancellable
import func Layout.broadcast
import protocol Dense.Matrix
import typealias CoreMedia.CMTime
import typealias DSP.Instance
import protocol DSP.Stream
import typealias DSP.Filter
import typealias Synchronization.Mutex
import typealias Auxiliary.Autorelease
import func KSP.ssm_filter_create
import func KSP.ssm_filter_destroy
import func KSP.ssm_filter_input
import func KSP.ssm_filter_output
import func KSP.ssm_filter_set
import func KSP.ssm_filter_state
import func KSP.ssm_filter
extension Filter {
    @usableFromInline
    enum StateSparse {
        @usableFromInline
        struct Kr<
            A: Publisher<((Int, Int), Float64), Never> & Sendable,
            B: Publisher<((Int, Int), Float64), Never> & Sendable,
            C: Publisher<((Int, Int), Float64), Never> & Sendable,
            D: Publisher<((Int, Int), Float64), Never> & Sendable>: Sendable {
            @usableFromInline let input: Stream
            @usableFromInline let state: Int
            @usableFromInline let count: Int
            @usableFromInline let a: A
            @usableFromInline let b: B
            @usableFromInline let c: C
            @usableFromInline let d: D
        }
    }
}
extension Filter.StateSparse.Kr: Stream {
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try input(interval: interval, capacity: capacity, instance: &instance)
        let source = input.count
        let object = Autorelease.Object(object: ssm_filter_create(input.count, count, state)) { ssm_filter_destroy($0) }
        var cancel = Set<AnyCancellable>()
        a.sink {
            switch $0 {
            case (0..<ssm_filter_state(object.reference), 0..<ssm_filter_state(object.reference)):
                ssm_filter_set(object.reference, .A, $0.0, $0.1, $1)
            default:
                break
            }
        }.store(in: &cancel)
        b.sink {
            switch $0 {
            case (0..<ssm_filter_state(object.reference), 0..<ssm_filter_input(object.reference)):
                ssm_filter_set(object.reference, .B, $0.0, $0.1, $1)
            default:
                break
            }
        }.store(in: &cancel)
        c.sink {
            switch $0 {
            case (0..<ssm_filter_output(object.reference), 0..<ssm_filter_input(object.reference)):
                ssm_filter_set(object.reference, .C, $0.0, $0.1, $1)
            default:
                break
            }
        }.store(in: &cancel)
        d.sink {
            switch $0 {
            case (0..<ssm_filter_output(object.reference), 0..<ssm_filter_input(object.reference)):
                ssm_filter_set(object.reference, .D, $0.0, $0.1, $1)
            default:
                break
            }
        }.store(in: &cancel)
        return { [cancel] moment, length, result, stride in
            withUnsafeTemporaryAllocation(of: Float64.self, capacity: source * length) {
                guard case.some(let memory) = $0.baseAddress else { return }
                kernel(moment, length, memory, length)
                ssm_filter(object.reference,
                           memory, length,
                           result, stride,
                           length)
            }
        }
    }
}
public func filter(_ input: Stream,
                   state: Int,
                   count: Int,
                   A: some Publisher<((Int, Int), Float64), Never> & Sendable,
                   B: some Publisher<((Int, Int), Float64), Never> & Sendable,
                   C: some Publisher<((Int, Int), Float64), Never> & Sendable,
                   D: some Publisher<((Int, Int), Float64), Never> & Sendable) -> some Stream {
    Filter.StateSparse.Kr(input: input,
                          state: state,
                          count: count,
                          a: A,
                          b: B,
                          c: C,
                          d: D)
}
public func filter(_ input: Stream,
                   A: some Matrix<Float64>,
                   B: some Matrix<Float64>,
                   C: some Matrix<Float64>,
                   D: some Matrix<Float64>) throws -> some Stream {
    let (As, Ak) = try A.evaluation(for: .rowMajor)
    let (Bs, Bk) = try B.evaluation(for: .rowMajor)
    let (Cs, Ck) = try A.evaluation(for: .rowMajor)
    let (Ds, Dk) = try B.evaluation(for: .rowMajor)
    return filter(input,
                  state: broadcast(x: A.rows, y: B.rows),
                  count: broadcast(x: C.rows, y: D.rows),
                  A: Future<((Int, Int), Float64), Never> { reply in
        Task {
            _ = await Ak()
        }
    },
                  B: Future<((Int, Int), Float64), Never> { reply in
        Task {
            _ = await Bk()
        }
    },
                  C: Future<((Int, Int), Float64), Never> { reply in
        Task {
            _ = await Ck()
        }
    },
                  D: Future<((Int, Int), Float64), Never> { reply in
        Task {
            _ = await Dk()
        }
    }
    )
}
