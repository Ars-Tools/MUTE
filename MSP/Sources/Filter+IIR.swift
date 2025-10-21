//
//  Filter+IIR.swift
//  MUTE
//
//  Created by Kota on 6/4/R7.
//
//
import func NSP.universal_filter_create
import func NSP.universal_filter_destroy
import func NSP.universal_filter_execute
@usableFromInline
enum IIR {
	@usableFromInline
	struct Ar {
		@usableFromInline let x: Stream
		@usableFromInline let b: Stream
		@usableFromInline let a: Stream
	}
}
extension IIR.Ar: Stream {
	@inlinable @inline(__always)
	var count: Int {
		x.count
	}
	@inlinable @inline(__always)
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xc = x.count
		let bc = b.count
		let ac = a.count
		let xk = try x(interval: interval, capacity: capacity, resource: &resource)
		let bk = try b(interval: interval, capacity: capacity, resource: &resource)
		let ak = try a(interval: interval, capacity: capacity, resource: &resource)
		let object = Autorelease.Opaque(pointer: universal_filter_create(bc, ac, xc), release: universal_filter_destroy)
		return { moment, length, result, stride in
			withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( ac + bc ) * length) {
				guard let b = $0.baseAddress else { return }
				let a = b.advanced(by: bc * length)
				xk(moment, length, result, stride)
				bk(moment, length, b, length)
				ak(moment, length, a, length)
				universal_filter_execute(object.pointer,
										 b, 0, length,
										 a, 0, length,
										 result, stride,
										 result, stride,
										 length)
			}
		}
	}
}
public func filter(_ source: Stream, b: Stream, a: Stream = const(1)) -> some Stream {
	IIR.Ar(x: source, b: b, a: a)
}
