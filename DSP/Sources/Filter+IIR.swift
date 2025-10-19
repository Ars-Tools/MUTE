//
//  Filter+IIR.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
import func NSP.universal_filter_create
import func NSP.universal_filter_destroy
import func NSP.universal_filter_active
import func NSP.universal_filter_static
import typealias Synchronization.Mutex
import func simd.simd_max
import typealias Auxiliary.Autorelease
@usableFromInline
enum IIR {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, (Zero, Pole)), Never> & Sendable, Zero: Kernel<Float64>, Pole: Kernel<Float64>> {
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
extension IIR.Kr: Stream {
	@inlinable @inline(__always)
	var count: Int {
		x.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try x(interval: interval, capacity: capacity, instance: &instance)
		let c = x.count
		let object = Autorelease.Opaque(pointer: universal_filter_create(b, a, c), release: universal_filter_destroy)
		let system = Mutex<(Array<Float64>, Array<Float64>)>((.init(repeating: 0, count: c * b), .init(repeating: 0, count: c * a)))
		let cancel = z.sink { k, zp in
			switch k {
			case 0..<c:
				system.withLock {
					$0.0.replaceSubrange(b*k..<b*k+zp.0.count, with: zp.0.coefficients(for: interval))
					$0.1.replaceSubrange(a*k..<a*k+zp.1.count, with: zp.1.coefficients(for: interval))
				}
			default:
				assertionFailure("out of range")
			}
		}
		return {
			xk($0, $1, $2, $3)
			let (B, A) = withExtendedLifetime(cancel) { system.withLock(\.self) }
			universal_filter_static(object.pointer,
									B, b,
									A, a,
									$2, $3,
									$2, $3,
									$1)
		}
	}
}
extension IIR.Ar: Stream {
	@inlinable @inline(__always)
	var count: Int {
		x.count
	}
	@inlinable @inline(__always)
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xc = x.count
		let bc = b.count
		let ac = a.count
		let xk = try x(interval: interval, capacity: capacity, instance: &instance)
		let bk = try b(interval: interval, capacity: capacity, instance: &instance)
		let ak = try a(interval: interval, capacity: capacity, instance: &instance)
		let object = Autorelease.Opaque(pointer: universal_filter_create(bc, ac, xc), release: universal_filter_destroy)
		return { moment, length, target, stride in
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( bc + ac ) * length) {
				guard let b = $0.baseAddress else { return }
				let a = b.advanced(by: bc * length)
				xk(moment, length, target, stride)
				bk(moment, length, b, length)
				ak(moment, length, a, length)
				universal_filter_active(object.pointer,
										b, length,
										a, length,
										target, stride,
										target, stride,
										length)
			}
		}
	}
}
public func filter(_ source: Stream, with kernel: some Publisher<(Int, (some Kernel<Float64>, some Kernel<Float64>)), Never> & Sendable, length: SIMD2<Int>) -> some Stream {
	IIR.Kr(x: source, z: kernel, b: length.x, a: length.y)
}
public func filter(_ source: Stream, with kernel: some Publisher<(some Kernel<Float64>, some Kernel<Float64>), Never>, length: SIMD2<Int>) -> some Stream {
	filter(source, with: kernel.repeat(count: source.count), length: length)
}
public func filter(_ source: Stream, with kernel: some Sequence<(some Kernel<Float64>, some Kernel<Float64>)>) -> some Stream{
	filter(source, with: kernel.prefix(count: source.count), length: kernel.reduce(SIMD2<Int>(repeating: 0)) {
		simd_max($0, .init($1.0.count, $1.1.count))
	})
}
public func filter(_ source: Stream, with kernel: (some Kernel<Float64>, some Kernel<Float64>)) -> some Stream {
	filter(source, with: `repeat`(kernel, count: source.count), length: .init(kernel.0.count, kernel.1.count))
}
public func filter(_ source: Stream, with kernel: (Stream, Stream)) -> some Stream {
	IIR.Ar(x: source, b: kernel.0, a: kernel.1)
}
public func filter(_ source: Stream, with kernel: Stream) -> some Stream {
	filter(source, with: (kernel, const(1)))
}
