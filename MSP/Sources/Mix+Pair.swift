//
//  Mix+Pair.swift
//  MUTE
//
//  Created by Kota on 6/5/R7.
//
import typealias Synchronization.Mutex
import func Layout.broadcast
@preconcurrency import protocol Combine.Publisher
import typealias Accelerate.vDSP
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import func simd.simd_clamp
import func simd.__sincospi_stret
public enum Pair {
	public enum Mode: Sendable {
		case linear
		case trigonometric
	}
	@usableFromInline
	struct Kr<Weight: Publisher<(Int, Float64), Never> & Sendable> {
		@usableFromInline let x: Stream
		@usableFromInline let y: Stream
		@usableFromInline let z: Weight
		@usableFromInline let w: Mode
	}
	@usableFromInline
	struct Ar {
		@usableFromInline let x: Stream
		@usableFromInline let y: Stream
		@usableFromInline let z: Stream
		@usableFromInline let w: Mode
	}
}
extension Pair.Mode {
	@inlinable @inline(__always)
	func callAsFunction(a: some AccelerateBuffer<Float64>, b: some AccelerateBuffer<Float64>, c: Float64, d: inout some AccelerateMutableBuffer<Float64>) {
		switch self {
		case.linear:
			vDSP.linearInterpolate(a, b, using: c, result: &d)
		case.trigonometric:
			let r = __sincospi_stret(simd_clamp(c, 0, 1) * 0.5)
			vDSP.add(multiplication: (a, r.__cosval), multiplication: (b, r.__sinval), result: &d)
		}
	}
	@inlinable @inline(__always)
	func callAsFunction(a: some AccelerateBuffer<Float64>, b: some AccelerateBuffer<Float64>, c: some AccelerateBuffer<Float64>, d: inout some AccelerateMutableBuffer<Float64>) {
		switch self {
		case.linear:
			break
		case.trigonometric:
			break
		}
	}
}
extension Pair.Kr: Stream {
	@inlinable
	var count: Int {
		broadcast(x: x.count, y: y.count)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try x(interval: interval, capacity: capacity, resource: &resource)
		let yk = try y(interval: interval, capacity: capacity, resource: &resource)
		let xc = x.count
		let yc = y.count
		switch broadcast(x: xc, y: yc) {
		case xc:
			let weight = Mutex<Array<Float64>>(.init(repeating: .zero, count: xc))
			let cancel = z.sink { index, value in
				weight.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, target, stride in
				let weight = withExtendedLifetime(cancel) { weight.withLock(\.self) }
				let ys = broadcast(target: xc, source: yc, stride: length)
				xk(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: yc * length) {
					guard let source = $0.baseAddress else { return }
					yk(moment, length, source, length)
					for (offset, weight) in weight.enumerated() {
						var result = UnsafeMutableBufferPointer(start: target.advanced(by: offset * stride), count: length)
						w(a: result,
						  b: UnsafeMutableBufferPointer(start: source.advanced(by: offset * ys), count: length),
						  c: weight,
						  d: &result)
					}
				}
			}
		case yc:
			let weight = Mutex<Array<Float64>>(.init(repeating: .zero, count: yc))
			let cancel = z.sink { index, value in
				weight.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, target, stride in
				let weight = withExtendedLifetime(cancel) { weight.withLock(\.self) }
				let xs = broadcast(target: yc, source: xc, stride: length)
				yk(moment, length, target, stride)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: xc * length) {
					guard let source = $0.baseAddress else { return }
					xk(moment, length, source, length)
					for (offset, weight) in weight.enumerated() {
						var result = UnsafeMutableBufferPointer(start: target.advanced(by: offset * stride), count: length)
						w(a: UnsafeMutableBufferPointer(start: source.advanced(by: offset * xs), count: length),
						  b: result,
						  c: weight,
						  d: &result)
					}
				}
			}
		case let zc:
			let weight = Mutex<Array<Float64>>(.init(repeating: .zero, count: zc))
			let cancel = z.sink { index, value in
				weight.withLock {
					switch index {
					case $0.indices:
						$0[index] = value
					default:
						assertionFailure("out of range")
					}
				}
			}
			return { moment, length, target, stride in
				let weight = withExtendedLifetime(cancel) { weight.withLock(\.self) }
				let xs = broadcast(target: zc, source: xc, stride: length)
				let ys = broadcast(target: zc, source: yc, stride: length)
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: ( xc + yc ) * length) {
					guard let source = $0.baseAddress else { return }
					let x = source
					let y = source.advanced(by: xc * length)
					xk(moment, length, x, length)
					yk(moment, length, y, length)
					for (offset, weight) in weight.enumerated() {
						var result = UnsafeMutableBufferPointer(start: target.advanced(by: offset * stride), count: length)
						w(a: UnsafeMutableBufferPointer(start: source.advanced(by: offset * xs), count: length),
						  b: UnsafeMutableBufferPointer(start: source.advanced(by: offset * ys), count: length),
						  c: weight,
						  d: &result)
					}
				}
			}
		}
	}
}
public func mix(_ a: Stream, _ b: Stream, ratio z: some Publisher<(Int, Float64), Never> & Sendable, mode: Pair.Mode = .linear) -> some Stream {
	Pair.Kr(x: a, y: b, z: z, w: mode)
}
public func mix(_ a: Stream, _ b: Stream, ratio z: some Publisher<Float64, Never> & Sendable, mode: Pair.Mode = .linear) -> some Stream {
	Pair.Kr(x: a, y: b, z: z.repeat(count: broadcast(x: a.count, y: b.count)), w: mode)
}
public func mix(_ a: Stream, _ b: Stream, ratio z: Float64, mode: Pair.Mode = .linear) -> some Stream {
	Pair.Kr(x: a, y: b, z: `repeat`(z, count: broadcast(x: a.count, y: b.count)), w: mode)
}
