//
//  Filter+FIR.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
import struct Synchronization.Mutex
import func Layout.broadcast
import Accelerate.vecLib
import typealias Auxiliary.Autorelease
public enum FIR {
	public enum Domain: Sendable {
		case time
		case freq
	}
	@usableFromInline
	struct Kr<Kernel: DSP.Kernel<Float64>, Filter: Publisher<(Int, Kernel), Never> & Sendable> {
		@usableFromInline let stream: Stream
		@usableFromInline let filter: Filter
		@usableFromInline let extent: SIMD2<Int>
		@usableFromInline let domain: Domain
	}
}
extension FIR.Kr: Stream {
	@inlinable
	var count: Int {
		broadcast(x: stream.count, y: extent.x)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let source = try stream(interval: interval, capacity: capacity, instance: &instance)
		let fr = extent.x
		let fc = extent.y
		let sr = stream.count
		switch domain {
		case.time:
			let sc = capacity + fc - 1
			let rr = broadcast(x: sr, y: fr)
			let fs = broadcast(target: rr, source: fr, stride: fc)
			let ss = broadcast(target: rr, source: sr, stride: sc)
			let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: sr * sc + fr * fc))
			let cancel = filter.sink {
				let value = $1.coefficients(for: interval).prefix(fc)
				let start = sr * sc + $0 * fc
				let head = start..<start+value.count
				let tail = head.upperBound..<start+fc
				buffer.withLock {
					$0.replaceSubrange(head, with: value.reversed())
					$0.replaceSubrange(tail, with: repeatElement(.zero, count: tail.count))
				}
			}
			return { moment, length, memory, stride in
				withExtendedLifetime(cancel) {
					buffer.withLock {
						$0.withUnsafeMutablePointer { signal in
							let filter = signal.advanced(by: sr * sc)
							source(moment, length, signal.advanced(by: fc - 1), sc)
							for offset in 0..<rr {
								vDSP_convD(signal.advanced(by: offset * ss), 1,
										   filter.advanced(by: offset * fs), 1,
										   memory.advanced(by: offset * stride), 1,
										   .init(length), .init(fc))
							}
							copy(x: signal.advanced(by: length), ldx: sc,
								 y: signal, ldy: sc,
								 rows: sr, cols: fc - 1)
						}
					}
				}
			}
		case.freq:
			let source = try stream(interval: interval, capacity: capacity, instance: &instance)
			let log2n = MemoryLayout<Int>.size * 8 - (capacity + fc - 2).leadingZeroBitCount
			let frame = 1 << log2n
			let setup = Autorelease.Opaque(pointer: vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped) { vDSP_destroy_fftsetupD($0) }
			let rr = broadcast(x: sr, y: fr)
			let fs = broadcast(x: rr, y: fr, z: frame)
			let ss = broadcast(x: rr, y: sr, z: frame)
			let rs = frame
			// [Work Real]
			// [Work Imag]
			// [Time Real] [0 ch] [1 ch] [2 ch] …
			// [Time Imag] [0 ch] [1 ch] [2 ch] …
			// [Task Real] [0] [1] …
			// [Task Imag] [0] [1] …
			// [Freq Real] [0 ch] [1 ch] [2 ch] … [broadcast(S, F)]
			// [Freq Imag] [0 ch] [1 ch] [2 ch] … [broadcast(S, F)]
			let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: ( 1 + sr + fr + rr ) * 2 * frame))
			let cancel = filter.sink { index, value in
				switch index {
				case 0..<fr:
					buffer.withLock {
						$0.withUnsafeMutablePointer {
							var work = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (0)),
															 imagp: $0.advanced(by: frame * (1)))
							var task = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 2 * sr + index)),
															 imagp: $0.advanced(by: frame * (2 + 2 * sr + fr)))
							vDSP_vclrD(task.imagp, 1, .init(frame))
							let buff = UnsafeMutableBufferPointer(start: task.realp, count: frame)
							buff[buff.update(fromContentsOf: value.coefficients(for: interval))...].update(repeating: .zero)
							work.realp.pointee = .init(frame)
							vDSP_vsdivD(task.realp, 1, work.realp, task.realp, 1, .init(fc))
							vDSP_fft_ziptD(setup.pointer, &task, 1, &work, .init(log2n), .init(kFFTDirection_Forward))
						}
					}
				default:
					assertionFailure("out of range")
				}
			}
			return { moment, length, memory, stride in
				withExtendedLifetime(cancel) {
					buffer.withLock {
						$0.withUnsafeMutablePointer {
							var work = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (0)),
															 imagp: $0.advanced(by: frame * (1)))
							var time = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 0 * sr)),
															 imagp: $0.advanced(by: frame * (2 + 1 * sr)))
							let task = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 2 * sr + 0 * fr)),
															 imagp: $0.advanced(by: frame * (2 + 2 * sr + 1 * fr)))
							var freq = DSPDoubleSplitComplex(realp: $0.advanced(by: frame * (2 + 2 * sr + 2 * fr + 0 * rr)),
															 imagp: $0.advanced(by: frame * (2 + 2 * sr + 2 * fr + 1 * rr)))
							source(moment, length, time.realp.advanced(by: fc - 1), stride)
							assert(vDSP.sumOfMagnitudes(UnsafeBufferPointer(start: time.imagp, count: frame * sr)) == 0)
							vDSP_fftm_zoptD(setup.pointer,
											&time, 1, frame,
											&freq, 1, frame,
											&work,
											.init(log2n), .init(sr), .init(kFFTDirection_Forward))
							copy(x: time.realp, ldx: frame,
								 y: time.realp.advanced(by: length), ldy: frame,
								 rows: sr, cols: fc - 1)
							for offset in (0..<rr).reversed() {
								var x = DSPDoubleSplitComplex(realp: freq.realp.advanced(by: offset * ss),
															  imagp: freq.imagp.advanced(by: offset * ss))
								var f = DSPDoubleSplitComplex(realp: task.realp.advanced(by: offset * fs),
															  imagp: task.imagp.advanced(by: offset * fs))
								var y = DSPDoubleSplitComplex(realp: freq.realp.advanced(by: offset * rs),
															  imagp: freq.imagp.advanced(by: offset * rs))
								vDSP_zvmulD(&x, 1, &f, 1, &y, 1, .init(frame), 0)
							}
							vDSP_fftm_ziptD(setup.pointer,
											&freq, 1, frame,
											&work,
											.init(log2n), .init(rr), .init(kFFTDirection_Inverse))
							copy(x: freq.realp.advanced(by: fc - 1), ldx: frame,
								 y: memory, ldy: stride,
								 rows: rr, cols: length)
						}
					}
				}
			}
		}
	}
}
public func filter(_ source: Stream, with kernel: some Publisher<(Int, some Kernel<Float64>), Never> & Sendable, extent: SIMD2<Int>, domain: FIR.Domain = .time) -> some Stream {
	FIR.Kr(stream: source, filter: kernel, extent: extent, domain: domain)
}
public func filter(_ source: Stream, with kernel: some Collection<some Kernel<Float64>>, domain: FIR.Domain = .time) -> some Stream {
	filter(source, with: kernel.enumerated().publisher.map(\.self), extent: .init(kernel.count, kernel.map(\.count).max() ?? 1), domain: domain)
}
public func filter(_ source: Stream, with kernel: some Kernel<Float64>, domain: FIR.Domain = .time) -> some Stream {
	filter(source, with: CollectionOfOne(kernel), domain: domain)
}
//public func filter(_ source: Stream, with kernel: Buffer, domain: FIR.Domain = .time) -> some Stream {
//	filter(source, with: kernel.unsafeMutableBufferPointer, domain: domain)
//}
