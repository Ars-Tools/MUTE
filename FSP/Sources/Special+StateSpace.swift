//
//  Special+StateSpace.swift
//  MUTE
//
//  Created by Kota on 5/12/26.
//
import func Layout.broadcast
import typealias CoreMedia.CMTime
import typealias DSP.Instance
import protocol DSP.Stream
import typealias Synchronization.Mutex
extension Special {
    @usableFromInline
    enum StateSparse {
        
    }
}
//extension StateSpace.Kr: Stream {
//    @inlinable
//    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//        let kernel = try x(interval: interval, capacity: capacity, instance: &instance)
//        return switch x.count {
//        case ...count:
//            { moment, length, result, stride in
//                kernel(moment, length, result, stride)
//                
//            }
//        case let input:
//            { moment, length, result, stride in
//                kernel(moment, length, result, stride)
//                
//            }
//        }
//    }
//}

//public enum StateSpace {
//    public struct Discrete: Sendable {
//        public let order: Int
//        public let A: Array<Float64>
//        public let B: Array<Float64>
//        public let C: Array<Float64>
//        public let D: Float64
//
//        @inlinable
//        public init(order: Int, A: Array<Float64>, B: Array<Float64>, C: Array<Float64>, D: Float64) {
//            precondition(order > 0)
//            precondition(A.count == order * order)
//            precondition(B.count == order)
//            precondition(C.count == order)
//            self.order = order
//            self.A = A
//            self.B = B
//            self.C = C
//            self.D = D
//        }
//
//        @inlinable
//        public init(A: Array<Float64>, B: Array<Float64>, C: Array<Float64>, D: Float64) {
//            let order = B.count
//            self.init(order: order, A: A, B: B, C: C, D: D)
//        }
//    }
//
//    public final class Filter: @unchecked Sendable {
//        struct Storage: Sendable {
//            var model: Array<Discrete>
//            var state: Array<Float64>
//        }
//
//        public let count: Int
//        private let storage: Mutex<Storage>
//
//        public init(model: Discrete, count: Int = 1) {
//            precondition(count > 0)
//            self.count = count
//            self.storage = .init(.init(
//                model: .init(repeating: model, count: count),
//                state: .init(repeating: 0, count: count * model.order)
//            ))
//        }
//
//        public init(model: some Sequence<Discrete>) {
//            let model = Array(model)
//            precondition(!model.isEmpty)
//            let order = model[0].order
//            precondition(model.allSatisfy { $0.order == order })
//            self.count = model.count
//            self.storage = .init(.init(
//                model: model,
//                state: .init(repeating: 0, count: model.count * order)
//            ))
//        }
//
//        public func reset() {
//            storage.withLock {
//                $0.state.replaceSubrange($0.state.indices, with: repeatElement(0, count: $0.state.count))
//            }
//        }
//
//        public func setModel(_ model: Discrete, at channel: Int) {
//            storage.withLock {
//                precondition(channel >= 0 && channel < $0.model.count)
//                precondition(model.order == $0.model[channel].order)
//                $0.model[channel] = model
//            }
//        }
//
//        public func process(
//            channel: Int,
//            input: UnsafePointer<Float64>,
//            output: UnsafeMutablePointer<Float64>,
//            length: Int
//        ) {
//            storage.withLock { storage in
//                precondition(channel >= 0 && channel < storage.model.count)
//                let model = storage.model[channel]
//                let order = model.order
//                let offset = channel * order
//                var x = Array(storage.state[offset..<offset + order])
//                var next = Array<Float64>(repeating: 0, count: order)
//
//                for sample in 0..<length {
//                    let u = input[sample]
//                    output[sample] = zip(model.C, x).reduce(model.D * u) { $0 + $1.0 * $1.1 }
//
//                    for row in 0..<order {
//                        let base = row * order
//                        next[row] = zip(model.A[base..<base + order], x).reduce(model.B[row] * u) { $0 + $1.0 * $1.1 }
//                    }
//
//                    swap(&x, &next)
//                }
//
//                storage.state.replaceSubrange(offset..<offset + order, with: x)
//            }
//        }
//    }
//
//    @usableFromInline
//    struct Kr {
//        @usableFromInline let source: Stream
//        @usableFromInline let model: Array<Discrete>
//    }
//}
//
//extension StateSpace.Kr: Stream {
//    @inlinable
//    public var count: Int {
//        source.count
//    }
//
//    @inlinable
//    public func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
//        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
//        let filter = StateSpace.Filter(model: model)
//        let channel = count
//        return { moment, length, target, stride in
//            kernel(moment, length, target, stride)
//            for c in 0..<channel {
//                let pointer = target.advanced(by: c * stride)
//                filter.process(channel: c, input: .init(pointer), output: pointer, length: length)
//            }
//        }
//    }
//}
//
//public func filter(_ source: Stream, with model: StateSpace.Discrete) -> some Stream {
//    StateSpace.Kr(source: source, model: .init(repeating: model, count: source.count))
//}
//
//public func filter(_ source: Stream, with model: some Sequence<StateSpace.Discrete>) -> some Stream {
//    let model = Array(model)
//    precondition(model.count == source.count)
//    return StateSpace.Kr(source: source, model: model)
//}
