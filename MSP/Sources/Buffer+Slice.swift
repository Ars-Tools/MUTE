//
//  Buffer+Slice.swift
//  MUTE
//
//  Created by Kota on 5/22/R7.
//
import typealias Accelerate.vDSP
import func Layout.broadcast
import func NSP.periodic_lookup_with_static
@preconcurrency import protocol Combine.Publisher
extension Buffer {
	@usableFromInline
	struct Table<Buffer: Instance> {
		@usableFromInline let buffer: Buffer
		@usableFromInline let phasor: Stream
	}
	@usableFromInline
	struct Index<Buffer: Instance> {
		@usableFromInline let buffer: Buffer
		@usableFromInline let offset: Stream
	}
}
extension Buffer.Table: Stream {
	@usableFromInline
	var count: Int {
		broadcast(x: buffer.count, y: phasor.count)
	}
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let (object, ground) = try buffer(interval: interval, capacity: capacity, resource: &resource)
		let source = try phasor(interval: interval, capacity: capacity, resource: &resource)
		let period = object.period
		let factor = Float64(period)
		let xc = object.stream
		let yc = phasor.count
		switch broadcast(x: xc, y: yc) {
		case 1:
			return { moment, length, target, stride in
				var ground = ground(moment, length)
				source(moment, length, target, stride)
				object.withUnsafePointer {
					vDSP.add(multiplication: (UnsafeBufferPointer(start: target, count: length), factor), ground, result: &ground)
					periodic_lookup_with_static($0,
												ground,
												target,
												period, length)
				}
			}
		case xc:assert(xc == count)
			return { moment, length, target, zs in
				let ground = ground(moment, length)
				let xs = period
				let ys = broadcast(target: xc, source: yc, stride: zs)
				source(moment, length, target, zs)
				for offset in 0..<yc {
					var buffer = UnsafeMutableBufferPointer(start: target.advanced(by: offset * zs), count: length)
					vDSP.add(multiplication: (buffer, factor), ground, result: &buffer)
				}
				object.withUnsafePointer {
					for offset in (0..<xc).reversed() {
						periodic_lookup_with_static($0.advanced(by: offset * xs),
													target.advanced(by: offset * ys),
													target.advanced(by: offset * zs),
													period, length)
					}
				}
			}
		case yc:assert(yc == count)
			return { moment, length, target, zs in
				let ground = ground(moment, length)
				let xs = broadcast(target: yc, source: xc, stride: period)
				let ys = zs
				source(moment, length, target, zs)
				for offset in 0..<yc {
					var buffer = UnsafeMutableBufferPointer(start: target.advanced(by: offset * zs), count: length)
					vDSP.add(multiplication: (buffer, factor), ground, result: &buffer)
				}
				object.withUnsafePointer {
					for offset in (0..<yc).reversed() {
						periodic_lookup_with_static($0.advanced(by: offset * xs),
													target.advanced(by: offset * ys),
													target.advanced(by: offset * zs),
													period, length)
					}
				}
			}
		case let zc:assert(zc == count)
			throw Error.unmatchChannel
		}
	}
}
extension Buffer.Index: Stream {
	@usableFromInline
	var count: Int {
		broadcast(x: buffer.count, y: offset.count)
	}
	@usableFromInline
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let (object, ground) = try buffer(interval: interval, capacity: capacity, resource: &resource)
		let source = try offset(interval: interval, capacity: capacity, resource: &resource)
		let period = object.period
		let factor = Float64(interval.timescale) / Float64(interval.value)
		let xc = object.stream
		let yc = offset.count
		switch broadcast(x: xc, y: yc) {
		case 1:
			return { moment, length, target, stride in
				var ground = ground(moment, length)
				assert(ground.count == length)
				source(moment, length, target, stride)
				object.withUnsafePointer {
					vDSP.multiply(factor, UnsafeBufferPointer(start: target, count: length), result: &ground)
					periodic_lookup_with_static($0,
												ground,
												target,
												period, length)
				}
			}
		case xc:assert(xc == count)
			return { moment, length, target, zs in
				let ground = ground(moment, length)
				assert(ground.count == length)
				let xs = period
				let ys = broadcast(target: xc, source: yc, stride: zs)
				source(moment, length, target, zs)
				for offset in 0..<yc {
					var result = UnsafeMutableBufferPointer(start: target.advanced(by: offset * zs), count: length)
					vDSP.multiply(factor, result, result: &result)
				}
				object.withUnsafePointer {
					for offset in (0..<xc).reversed() {
						periodic_lookup_with_static($0.advanced(by: offset * xs),
													target.advanced(by: offset * ys),
													target.advanced(by: offset * zs),
													period, length)
					}
				}
			}
		case yc:assert(yc == count)
			return { moment, length, target, zs in
				let ground = ground(moment, length)
				assert(ground.count == length)
				let xs = broadcast(target: yc, source: xc, stride: period)
				let ys = zs
				source(moment, length, target, zs)
				for offset in 0..<yc {
					var result = UnsafeMutableBufferPointer(start: target.advanced(by: offset * zs), count: length)
					vDSP.multiply(factor, result, result: &result)
				}
				object.withUnsafePointer {
					for offset in (0..<yc).reversed() {
						periodic_lookup_with_static($0.advanced(by: offset * xs),
													target.advanced(by: offset * ys),
													target.advanced(by: offset * zs),
													period, length)
					}
				}
			}
		case let zc:assert(zc == count)
			throw Error.unmatchChannel
		}
	}
}
extension Buffer.Instance {
	public subscript(_ offset: Stream) -> some Stream {
		Buffer.Index(buffer: self, offset: offset)
	}
	public func callAsFunction(phase phasor: some Stream) -> some Stream {
		Buffer.Table(buffer: self, phasor: phasor)
	}
	public func callAsFunction(freqs: some Stream) -> some Stream {
		Buffer.Table(buffer: self, phasor: phasor(freqs: freqs))
	}
	public func callAsFunction(freqs: some Publisher<(Int, Frequency), Never> & Sendable, count: Int) -> some Stream {
		Buffer.Table(buffer: self, phasor: phasor(freqs: freqs, count: count))
	}
	public func callAsFunction(freqs: some Publisher<Frequency, Never> & Sendable) -> some Stream {
		Buffer.Table(buffer: self, phasor: phasor(freqs: freqs))
	}
	public func callAsFunction(freqs: some Collection<Frequency>) -> some Stream {
		Buffer.Table(buffer: self, phasor: phasor(freqs: freqs))
	}
	@_disfavoredOverload
	public func callAsFunction(freqs: Frequency...) -> some Stream {
		Buffer.Table(buffer: self, phasor: phasor(freqs: freqs))
	}
}
