//
//  Graph+Oversample.swift
//  MUTE
//
//  Created by Kota on 6/25/R7.
//
import func CoreMedia.memmove
import func CoreMedia.CMTimeMultiplyByRatio
import typealias Accelerate.vDSP
import typealias Synchronization.Mutex
@usableFromInline
enum Oversample {
	@usableFromInline
	struct Ne {
		@usableFromInline let stream: Stream
		@usableFromInline let factor: Int // decimation rate
		@usableFromInline let window: Array<Float64>
	}
}
extension Oversample.Ne: Stream {
	@inlinable
	var count: Int {
		stream.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let Δt = CMTimeMultiplyByRatio(interval, multiplier: 1, divisor: .init(factor))
		let bs = capacity * factor
		let ow = max(0, window.count - factor)
		let ls = bs + ow
		let number = stream.count
		let stream = try stream(interval: Δt, capacity: bs, resource: &resource)
		let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: number * ls))
		return { moment, length, result, stride in
			buffer.withLock { $0.withUnsafeMutablePointer {
				stream(moment, length * factor, $0.advanced(by: ow), ls)
				for number in 0..<number {
					let cursor = $0.advanced(by: number * ls)
					var result = UnsafeMutableBufferPointer(start: result.advanced(by: number * stride), count: length)
					vDSP.downsample(UnsafeBufferPointer(start: cursor, count: length * factor + ow),
									decimationFactor: factor,
									filter: window,
									result: &result)
					memmove(cursor, cursor.advanced(by: length * factor), ow * MemoryLayout<Float64>.stride)
				}
			}}
		}
	}
}
public func oversample(_ source: Stream, factor: Int, smooth window: some Collection<Float64>) -> some Stream {
	Oversample.Ne(stream: source, factor: factor, window: .init(window))
}
public func oversample(_ source: Stream, factor: Int, smooth window: SmoothWindowDesign) -> some Stream {
	oversample(source, factor: factor, smooth: window.coefficients)
}
