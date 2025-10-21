//
//  Filter+Differential.swift
//  MUTE
//
//  Created by Kota on 6/4/R7.
//
import struct Synchronization.Mutex
import func Layout.broadcast
prefix operator ∂
prefix func ∂(x: Stream) -> some Stream { // diff(f(t)) without reset trigger
	filter(x, cascade: .raw(b₀: 1, b₁: 0, b₂: -1, a₁: 1, a₂: 0))
}
@usableFromInline
enum Differentiation {
	@usableFromInline
	struct Ar {
		@usableFromInline let operand: Stream
		@usableFromInline let reset: Stream
	}
}
extension Differentiation.Ar: Stream {
	@inlinable
	var count: Int {
		broadcast(x: operand.count, y: reset.count)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xc = operand.count
		let yc = reset.count
		let xk = try operand(interval: interval, capacity: capacity, resource: &resource)
		let yk = try operand(interval: interval, capacity: capacity, resource: &resource)
		switch broadcast(x: xc, y: yc) {
		case xc:
			let status = Mutex<Array<SIMD2<Float64>>>(.init(repeating: .zero, count: xc))
			return { moment, length, result, stride in
				xk(moment, length, result, stride)
				let ys = broadcast(target: xc, source: yc, stride: length)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: yc * length) {
					guard let source = $0.baseAddress else { return }
					yk(moment, length, source, length)
					status.withLock {
						for offset in $0.indices {
							assert(0..<xc ~= offset)
							calculus_differentiation(result.advanced(by: offset * stride),
													 source.advanced(by: offset * ys),
													 result.advanced(by: offset * stride),
													 &$0[offset], length)
						}
					}
				}
			}
		case yc:
			let status = Mutex<Array<SIMD2<Float64>>>(.init(repeating: .zero, count: yc))
			return { moment, length, result, stride in
				yk(moment, length, result, stride)
				let xs = broadcast(target: yc, source: xc, stride: length)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length) {
					guard let source = $0.baseAddress else { return }
					xk(moment, length, source, length)
					status.withLock {
						for offset in $0.indices {
							assert(0..<yc ~= offset)
							calculus_differentiation(source.advanced(by: offset * xs),
													 result.advanced(by: offset * stride),
													 result.advanced(by: offset * stride),
													 &$0[offset], length)
						}
					}
				}
			}
		case let zc:
			let status = Mutex<Array<SIMD2<Float64>>>(.init(repeating: .zero, count: zc))
			return { moment, length, result, stride in
				let xs = broadcast(target: zc, source: xc, stride: length)
				let ys = broadcast(target: zc, source: yc, stride: length)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( xc + yc ) * length) {
					guard let x = $0.baseAddress else { return }
					let y = x.advanced(by: xc * length)
					xk(moment, length, x, length)
					yk(moment, length, y, length)
					status.withLock {
						for offset in $0.indices {
							assert(0..<zc ~= offset)
							calculus_differentiation(x.advanced(by: offset * xs),
													 y.advanced(by: offset * ys),
													 result.advanced(by: offset * stride),
													 &$0[offset], length)
						}
					}
				}
			}
		}
	}
}
public func Δₜ(_ x: Stream, reset: Stream = φ(count: 1)) -> some Stream {
	Differentiation.Ar(operand: x, reset: reset)
}
