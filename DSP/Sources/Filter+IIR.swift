//
//  Filter+IIR.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Accelerate.AccelerateBuffer
@preconcurrency import protocol Combine.Publisher
import func KSP.transversal_filter_create
import func KSP.transversal_filter_destroy
import func KSP.transversal_filter_active
import func KSP.transversal_filter_static
import typealias Synchronization.Mutex
import func simd.simd_max
import typealias Auxiliary.Autorelease
extension Filter {
    @usableFromInline
    enum IIR {
        @usableFromInline
        struct Kr<Signal: Publisher<(Int, System), Never> & Sendable, System: Filter.TransferFunction<Float64>> {
            @usableFromInline let x: Stream
            @usableFromInline let z: Signal
            @usableFromInline let b: Int
            @usableFromInline let a: Int
        }
        @usableFromInline
        struct Ar {
            @usableFromInline let x: Stream
            @usableFromInline let z: Stream
            @usableFromInline let b: Int
            @usableFromInline let a: Int
        }
    }
}
extension Filter.IIR.Kr: Stream {
	@inlinable
	var count: Int {
		x.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try x(interval: interval, capacity: capacity, instance: &instance)
        switch x.count {
        case 1:
            let object = Autorelease.Object(object: transversal_filter_create(b, a)) {
                transversal_filter_destroy($0)
            }
            let period = SIMD2<Int>(b, a)
            let system = Mutex<(Array<Float64>, Array<Float64>)>((
                .init(unsafeUninitializedCapacity: period.x) {
                    $1 = $0.count
                    $0.prefix(1).initialize(repeating: 1)
                    $0.dropFirst().initialize(repeating: .zero)
                },
                .init(unsafeUninitializedCapacity: period.y) {
                    $1 = $0.count
                    $0.prefix(1).initialize(repeating: 1)
                    $0.dropFirst().initialize(repeating: .zero)
                }
            ))
            let cancel = z.flatMap {
                assert($0 == 0)
                return $1.coefficients(for: interval)
            }.sink { [b, a] in
                let bc = $0.prefix(b)
                let ac = $1.prefix(a)
                system.withLock {
                    $0.0.replaceSubrange(0..<bc.count, with: bc)
                    $0.0.replaceSubrange(bc.count..<period.x, with: repeatElement(0, count: b - bc.count))
                    $0.1.replaceSubrange(0..<ac.count, with: ac)
                    $0.1.replaceSubrange(ac.count..<period.y, with: repeatElement(0, count: a - ac.count))
                }
            }
            instance.store(cancel, interval: interval, capacity: capacity)
            return {
                xk($0, $1, $2, $3)
                let (B, A) = system.withLock(\.self)
                transversal_filter_static(object.reference,
                                          B,
                                          A,
                                          $2,
                                          $2,
                                          $1)
            }
        case let c:
            assert(1 < c)
            let object = Autorelease.Object(object: transversal_filter_create(b, a, c)) {
                transversal_filter_destroy($0)
            }
            let period = SIMD2<Int>(b, a)
            let system = Mutex<(Array<Float64>, Array<Float64>)>((
                repeatElement(Array<Float64>(unsafeUninitializedCapacity: period.x) {
                    $1 = $0.count
                    $0.prefix(1).initialize(repeating: 1)
                    $0.dropFirst().initialize(repeating: .zero)
                }, count: c).flatMap(\.self),
                repeatElement(Array<Float64>(unsafeUninitializedCapacity: period.y) {
                    $1 = $0.count
                    $0.prefix(1).initialize(repeating: 1)
                    $0.dropFirst().initialize(repeating: .zero)
                }, count: c).flatMap(\.self),
            ))
            let cancel = z.flatMap {
                assert(0..<c ~= $0)
                let offset = period &* .init(repeating: $0)
                return $1.coefficients(for: interval).map { (offset, $0) }
            }.sink {
                let b = switch $1.b.prefix(period.x) {
                case let s:
                    ($0.x, s)
                }
                let a = switch $1.a.prefix(period.y) {
                case let s:
                    ($0.y, s)
                }
                system.withLock {
                    $0.0.replaceSubrange(b.0..<b.0+b.1.count, with: b.1)
                    $0.0.replaceSubrange(b.0+b.1.count..<b.0+period.x, with: repeatElement(0, count: period.x - b.1.count))
                    $0.1.replaceSubrange(a.0..<a.0+a.1.count, with: a.1)
                    $0.1.replaceSubrange(a.0+a.1.count..<a.0+period.y, with: repeatElement(0, count: period.y - a.1.count))
                }
            }
            instance.store(cancel, interval: interval, capacity: capacity)
            return { [object, b, a] in
                xk($0, $1, $2, $3)
                let (B, A) = system.withLock(\.self)
                transversal_filter_static(object.reference,
                                          B, b,
                                          A, a,
                                          $2, $3,
                                          $2, $3,
                                          $1)
            }
        }
	}
}
extension Filter.IIR.Ar: Stream {
	@inlinable @inline(__always)
	var count: Int {
		x.count
	}
	@inlinable @inline(__always)
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let xk = try x(interval: interval, capacity: capacity, instance: &instance)
        let zk = try z(interval: interval, capacity: capacity, instance: &instance)
        switch x.count {
        case 1:
            let object = Autorelease.Object(object: transversal_filter_create(b, a)) {
                transversal_filter_destroy($0)
            }
            return { [object, b, a] moment, length, target, stride in
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( b + a ) * length) {
                    guard case.some(let w) = $0.baseAddress else { return }
                    xk(moment, length, target, stride)
                    zk(moment, length, w, length)
                    transversal_filter_active(object.reference,
                                              w, length,
                                              w.advanced(by: b * length), length,
                                              target,
                                              target,
                                              length)
                }
            }
        case let xc:
            assert(1 < xc)
            let object = Autorelease.Object(object: transversal_filter_create(b, a, xc)) {
                transversal_filter_destroy($0)
            }
            return { [object, b, a] moment, length, target, stride in
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( b + a ) * length) {
                    guard case.some(let w) = $0.baseAddress else { return }
                    xk(moment, length, target, stride)
                    zk(moment, length, w, length)
                    transversal_filter_active(object.reference,
                                              w, length,
                                              w.advanced(by: b * length), length,
                                              target, stride,
                                              target, stride,
                                              length)
                }
            }
        }
	}
}
@_disfavoredOverload
public func filter(_ source: Stream, iir system: some Publisher<(Int, some Filter.TransferFunction<Float64>), Never> & Sendable, counts: SIMD2<Int>) -> some Stream {
    Filter.IIR.Kr(x: source, z: system, b: counts.x, a: counts.y)
}
@_disfavoredOverload
public func filter(_ source: Stream, iir system: some Publisher<some Filter.TransferFunction<Float64>, Never>, counts: SIMD2<Int>) -> some Stream {
    Filter.IIR.Kr(x: source, z: system.repeat(count: source.count), b: counts.x, a: counts.y)
}
@_disfavoredOverload
public func filter(_ source: Stream, iir system: some Sequence<some Filter.TransferFunction<Float64>> & Sendable, counts: Optional<SIMD2<Int>> = .none) -> some Stream {
    switch counts ?? system.lazy.map(\.counts).reduce(.init(repeating: 1), simd_max) {
    case let n:
        Filter.IIR.Kr(x: source, z: system.prefix(count: source.count), b: n.x, a: n.y)
    }
}
@_disfavoredOverload
public func filter(_ source: Stream, iir system: some Filter.TransferFunction<Float64>) -> some Stream {
    Filter.IIR.Kr(x: source, z: `repeat`(system, count: source.count), b: system.counts.x, a: system.counts.y)
}
@inlinable@_disfavoredOverload
public func filter<System: Filter.TransferFunction<Float64>>(_ source: Stream, iir system: System...) -> some Stream {
    filter(source, iir: system)
}
@_disfavoredOverload
public func filter(_ source: Stream, iir design: Stream, counts: SIMD2<Int>) -> some Stream {
    Filter.IIR.Ar(x: source, z: design, b: counts.x, a: counts.y)
}
@inlinable
public func filter(_ source: Stream, iir design: (b: Stream, a: Stream)) -> some Stream {
    filter(source, iir: stack(design.b, design.a, parallel: false), counts: .init(design.b.count, design.a.count))
}
