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
            @usableFromInline let b: Stream
            @usableFromInline let a: Stream
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
		let bc = b.count
		let ac = a.count
		let bk = try b(interval: interval, capacity: capacity, instance: &instance)
		let ak = try a(interval: interval, capacity: capacity, instance: &instance)
        let xk = try x(interval: interval, capacity: capacity, instance: &instance)
        switch x.count {
        case 1:
            let object = Autorelease.Object(object: transversal_filter_create(bc, ac)) {
                transversal_filter_destroy($0)
            }
            return { [object] moment, length, target, stride in
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( bc + ac ) * length) {
                    let b = UnsafeMutableBufferPointer(rebasing: $0.prefix(bc * length))
                    let a = UnsafeMutableBufferPointer(rebasing: $0.suffix(ac * length))
                    xk(moment, length, target, stride)
                    bk(moment, length, b.baseAddress.unsafelyUnwrapped, length)
                    ak(moment, length, a.baseAddress.unsafelyUnwrapped, length)
                    transversal_filter_active(object.reference,
                                              b.baseAddress.unsafelyUnwrapped, length,
                                              a.baseAddress.unsafelyUnwrapped, length,
                                              target,
                                              target,
                                              length)
                }
            }
        case let xc:
            assert(1 < xc)
            let object = Autorelease.Object(object: transversal_filter_create(bc, ac, xc)) {
                transversal_filter_destroy($0)
            }
            return { [object] moment, length, target, stride in
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( bc + ac ) * length) {
                    guard let b = $0.baseAddress else { return }
                    let a = b.advanced(by: bc * length)
                    xk(moment, length, target, stride)
                    bk(moment, length, b, length)
                    ak(moment, length, a, length)
                    transversal_filter_active(object.reference,
                                              b, length,
                                              a, length,
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
public func filter(_ source: Stream, iir kernel: (Stream, Stream)) -> some Stream {
    Filter.IIR.Ar(x: source, b: kernel.0, a: kernel.1)
}
