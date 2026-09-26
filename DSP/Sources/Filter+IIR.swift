//
//  Filter+IIR.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Accelerate.AccelerateBuffer
@preconcurrency import protocol Combine.Publisher
import func NSP.transversal_filter_create
import func NSP.transversal_filter_destroy
import func NSP.transversal_filter_active
import func NSP.transversal_filter_static
import typealias Synchronization.Mutex
import func simd.simd_max
import typealias Auxiliary.Autorelease
extension Filter {
    @usableFromInline
    enum IIR {
        @usableFromInline
        struct Kr<Signal: Publisher<(Int, Design), Never> & Sendable, Design: Filter.TransferFunction<Float64>> {
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
            let system = Mutex<(Array<Float64>, Array<Float64>)>((
                .init(repeating: 0, count: b),
                .init(repeating: 0, count: a))
            )
            let cancel = z.sink { k, zp in
                switch k {
                case 0:
                    let (B, A) = zp.coefficients(for: interval)
                    system.withLock {
                        $0.0.replaceSubrange(0..<B.count, with: B)
                        $0.1.replaceSubrange(0..<A.count, with: A)
                    }
                default:
                    assertionFailure("out of range")
                }
            }
            let object = Autorelease.Object(object: transversal_filter_create(b, a)) {
                transversal_filter_destroy($0)
            }
            return { [cancel, object] in
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
            let system = Mutex<(Array<Float64>, Array<Float64>)>((
                .init(repeating: 0, count: b * c),
                .init(repeating: 0, count: a * c))
            )
            let cancel = z.sink { k, zp in
                switch k {
                case 0..<c:
                    let (B, A) = zp.coefficients(for: interval)
                    system.withLock {
                        $0.0.replaceSubrange(b*k..<b*k+B.count, with: B)
                        $0.1.replaceSubrange(a*k..<a*k+A.count, with: A)
                    }
                default:
                    assertionFailure("out of range")
                }
            }
            let object = Autorelease.Object(object: transversal_filter_create(b, a, c)) {
                transversal_filter_destroy($0)
            }
            return { [object, cancel, b, a] in
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
public func filter(_ source: Stream, iir design: some Publisher<(Int, some Filter.TransferFunction<Float64>), Never> & Sendable, counts: SIMD2<Int>) -> some Stream {
    Filter.IIR.Kr(x: source, z: design, b: counts.x, a: counts.y)
}
@inlinable
public func filter(_ source: Stream, iir design: some Publisher<some Filter.TransferFunction<Float64>, Never>, counts: SIMD2<Int>) -> some Stream {
	filter(source, iir: design.repeat(count: source.count), counts: counts)
}
@inlinable
public func filter(_ source: Stream, iir design: some Sequence<some Filter.TransferFunction<Float64>>) -> some Stream{
    filter(source, iir: design.prefix(count: source.count), counts: design.map(\.counts).reduce(SIMD2<Int>(repeating: 0), simd_max))
}
@inlinable
public func filter(_ source: Stream, iir design: some Filter.TransferFunction<Float64>) -> some Stream {
    filter(source, iir: `repeat`(design, count: source.count), counts: design.counts)
}
@_disfavoredOverload
public func filter(_ source: Stream, iir design: Stream, counts: SIMD2<Int>) -> some Stream {
    Filter.IIR.Ar(x: source, z: design, b: counts.x, a: counts.y)
}
@inlinable
public func filter(_ source: Stream, iir design: (b: Stream, a: Stream)) -> some Stream {
    filter(source, iir: stack(design.b, design.a), counts: .init(design.b.count, design.a.count))
}
