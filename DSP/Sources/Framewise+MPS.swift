//
//  Framewise+MPS.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
@preconcurrency import typealias Foundation.NSNumber
@preconcurrency import protocol Metal.MTLDevice
@preconcurrency import protocol Metal.MTLHeap
@preconcurrency import protocol Metal.MTLCommandQueue
@preconcurrency import typealias Metal.MTLHeapDescriptor
@preconcurrency import typealias MetalPerformanceShaders.MPSCommandBuffer
@preconcurrency import typealias MetalPerformanceShaders.MPSTemporaryNDArray
@preconcurrency import typealias MetalPerformanceShadersGraph.MPSGraph
@preconcurrency import typealias MetalPerformanceShadersGraph.MPSGraphExecutableExecutionDescriptor
@preconcurrency import typealias MetalPerformanceShadersGraph.MPSGraphTensor
@preconcurrency import typealias MetalPerformanceShadersGraph.MPSGraphTensorData
@preconcurrency import typealias MetalPerformanceShaders.MPSMatrix
@preconcurrency import typealias MetalPerformanceShaders.MPSMatrixCopy
@preconcurrency import typealias MetalPerformanceShaders.MPSMatrixDescriptor
@preconcurrency import typealias Dispatch.DispatchQueue
import typealias Accelerate.vDSP
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import func CoreMedia.CMTimeMultiply
import typealias Numerics.Rational64
import os.log
extension MTLDevice {
	@inlinable @inline(__always)
	func makeHeap(size: Int) throws -> MTLHeap {
		let descriptor = MTLHeapDescriptor()
		descriptor.storageMode = .shared
		descriptor.size = size
		return switch makeHeap(descriptor: descriptor) {
		case.some(let object):
			object
		case.none:
			throw Error.failedToAllocate(MTLHeap.self)
		}
	}
}
extension MPSGraphExecutableExecutionDescriptor {
	@inlinable @inline(__always)
	convenience init(complete task: @escaping(Optional<Swift.Error>) -> Void) {
		self.init()
		completionHandler = {task($1)}
	}
}
extension Framewise {
	@usableFromInline
	enum MPS {
		@usableFromInline
		struct Ne: Sendable {
			@usableFromInline let source: Stream
			@usableFromInline let window: Window
			@usableFromInline let stride: Stride
			@usableFromInline let output: Int
			@usableFromInline let device: MTLDevice
			@usableFromInline let ioproc: @Sendable (CMTime, MPSMatrixDescriptor, MPSMatrixDescriptor) throws -> @Sendable (CMTime, MPSMatrix, MPSMatrix, @escaping(Optional<Swift.Error>) -> Void) -> Void
		}
	}
}
extension Framewise.MPS.Ne {
	@usableFromInline
	static let subsystem = OSLog(subsystem: #file, category: .pointsOfInterest)
}
extension Framewise.MPS.Ne: Stream {
	@inlinable
	var count: Int {
		output
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let window = window.coefficients(for: interval)
		let stride = switch stride {
		case.absolute(let duration):
			duration.samples(for: interval)
		case.relative(let duration):
			(window.count * Int(duration.numerator) - 1) / Int(duration.denominator) + 1
		}
		let matrix = switch MPSMatrixDescriptor.rowBytes(forColumns: window.count, dataType: .float32) {
		case let rowBytes: (
			i: MPSMatrixDescriptor(rows: source.count, columns: window.count, rowBytes: rowBytes, dataType: .float32),
			o: MPSMatrixDescriptor(rows: output      , columns: window.count, rowBytes: rowBytes, dataType: .float32)
		)}
		let period = capacity * 2 + window.count
		let legacy = try device.makeHeap(size: (matrix.i.matrixBytes + matrix.o.matrixBytes) * ((period - 1) / stride + 2))
		let ioproc = try ioproc(interval, matrix.i, matrix.o)
		let buffer = Mutex<Array<Float64>>(.init(repeating: .zero, count: (matrix.i.rows + matrix.o.rows) * period))
		let throttle = DispatchSemaphore(value: 1)
		return { moment, length, target, bounds in
			let cursor = moment.samples(for: interval)
			let source = withUnsafeTemporaryAllocation(of: Float64.self, capacity: matrix.i.rows * length) {
				guard let source = $0.baseAddress else { fatalError() }
				kernel(moment, length, source, length)
				return buffer.withLock {
					$0.withUnsafeMutablePointer {
						let ib = $0
						let ob = $0.advanced(by: matrix.i.rows * period)
						let ic = switch ( cursor + window.count + capacity ) % period {
						case let index: (
							head: index..<min(index + length, period),
							tail: 0..<max(0, index + length - period)
						)}
						let oc = switch ( cursor                           ) % period {
						case let index: (
							head: index..<min(index + length, period),
							tail: 0..<max(0, index + length - period)
						)}
						copy(x: source, ldx: length,
							 y: ib.advanced(by: ic.head.lowerBound), ldy: period,
							 rows: matrix.i.rows, cols: ic.head.count)
						copy(x: source.advanced(by: ic.head.count), ldx: length,
							 y: ib, ldy: period,
							 rows: matrix.i.rows, cols: ic.tail.count)
						copy(x: ob.advanced(by: oc.head.lowerBound), ldx: period,
							 y: target, ldy: bounds,
							 rows: matrix.o.rows, cols: oc.head.count)
						copy(x: ob, ldx: period,
							 y: target.advanced(by: oc.head.count), ldy: bounds,
							 rows: matrix.o.rows, cols: oc.tail.count)
						for target in fold(start: ob, count: period, stream: matrix.o.rows, period: period) {
							vDSP.clear(&target[oc.head])
							vDSP.clear(&target[oc.tail])
						}
					}
					return $0
				}
			}
			let lower = ((cursor          - 1) / stride + 1) * stride
			let upper = ((cursor + length - 1) / stride + 1) * stride
			for offset in Swift.stride(from: lower, to: upper, by: stride) {
				guard
					let i = legacy.makeBuffer(length: matrix.i.matrixBytes),
					let o = legacy.makeBuffer(length: matrix.o.matrixBytes) else {
					os_log(.error, log: type(of: self).subsystem, "allocation failed for mpsmatrix")
					assertionFailure()
					continue
				}
				var memory = Array<Float64>(repeating: .zero, count: window.count)
				let value = CMTimeMultiply(interval, multiplier: .init(offset))
				let index = offset % period
				let head = index..<min(index + window.count, period)
				let tail = 0..<max(0, index + window.count - period)
				source.withUnsafePointer {
					for (cursor, target) in zip(
						Swift.stride(from: 0, to: matrix.i.rows * period, by: period).lazy.map($0.advanced(by:)),
						Swift.stride(from: 0, to: matrix.i.rows * matrix.i.rowBytes, by: matrix.i.rowBytes).lazy.map(i.contents().advanced(by:))) {
						let source = UnsafeBufferPointer(start: cursor, count: period)
						var target = UnsafeMutableBufferPointer(start: target.assumingMemoryBound(to: Float32.self), count: window.count)
						vDSP.multiply(window[..<head.count], source[head], result: &memory[..<head.count])
						vDSP.multiply(window[head.count...], source[tail], result: &memory[head.count...])
						vDSP.convertElements(of: memory, to: &target)
					}
				}
				throttle.wait()
				ioproc(value, .init(buffer: i, descriptor: matrix.i), .init(buffer: o, descriptor: matrix.o)) {
					defer {
						throttle.signal()
					}
					switch $0 {
					case.none:
						let index = ( offset + capacity ) % period
						let head = index..<min(index + window.count, period)
						let tail = 0..<max(0, index + window.count - period)
						buffer.withLock { $0.withUnsafeMutablePointer {
							for (source, target) in zip(Swift.stride(from: 0, to: matrix.o.rows * matrix.o.rowBytes, by: matrix.o.rowBytes).lazy.map(o.contents().advanced(by:)),
														Swift.stride(from: 0, to: matrix.o.rows * period, by: period).lazy.map($0.advanced(by: matrix.i.rows * period).advanced(by:))) {
								let source = UnsafeBufferPointer(start: source.assumingMemoryBound(to: Float32.self), count: window.count)
								let target = UnsafeMutableBufferPointer(start: target, count: period)
								vDSP.convertElements(of: source, to: &memory)
								vDSP.add(multiplication: (window[..<head.count], memory[..<head.count]), target[head], result: &target[head])
								vDSP.add(multiplication: (window[head.count...], memory[head.count...]), target[tail], result: &target[tail])
							}
						}}
					case.some(let error):
						os_log(.error, log: type(of: self).subsystem, "%{public}@", String(describing: $0))
						assertionFailure(error.localizedDescription)
					}
				}
			}
		}
	}
}
public func framewise(_ source: Stream, window: Framewise.Window, stride: Framewise.Stride, output: Int, device: MTLDevice, ioproc: @escaping@Sendable(CMTime, MPSMatrixDescriptor, MPSMatrixDescriptor) throws -> @Sendable (CMTime, MPSMatrix, MPSMatrix, @escaping(Optional<Swift.Error>) -> Void) -> Void) -> some Stream{
	Framewise.MPS.Ne(source: source, window: window, stride: stride, output: output, device: device, ioproc: ioproc)
}
public func framewise(_ source: Stream, window: Framewise.Window, stride: Framewise.Stride, output: Int, device: MTLDevice, ioproc: @escaping@Sendable(CMTime, MPSMatrix, MPSMatrix, (Optional<Swift.Error>) -> Void) -> Void) -> some Stream {
	Framewise.MPS.Ne(source: source, window: window, stride: stride, output: output, device: device) { _, _, _  in
		ioproc
	}
}
public func framewise(_ source: Stream, window: Framewise.Window, stride: Framewise.Stride, output: Int, thread: MTLCommandQueue, tensor: @escaping@Sendable(CMTime, MPSGraph, MPSGraphTensor, MPSGraphTensor) -> MPSGraphTensor) -> some Stream {
	Framewise.MPS.Ne(source: source, window: window, stride: stride, output: output, device: thread.device) {
		let g = MPSGraph()
		let t = g.placeholder(shape: .none, dataType: .float32, name: .none)
		let x = g.placeholder(shape: [$1.rows, $1.columns].map(NSNumber.init(integerLiteral:)), dataType: $1.dataType, name: .none)
		let y = tensor($0, g, t, x)
		guard case.some([$2.rows, $2.columns].map(NSNumber.init)) = y.shape else { throw Error.unmatchChannel }
		let z = g.compile(with: .init(mtlDevice: thread.device),
						  feeds: [
							t: .init(shape: t.shape, dataType: t.dataType),
							x: .init(shape: x.shape, dataType: x.dataType)
						  ],
						  targetTensors: [y],
						  targetOperations: .none,
						  compilationDescriptor: .none)
		return {
			let q = MPSCommandBuffer(from: thread)
			defer {
				q.commit()
			}
			let w = [
				t: MPSGraphTensorData(MPSTemporaryNDArray(device: q.device, scalar: $0.seconds)),
				x: MPSGraphTensorData($1 as MPSMatrix)
			]
			z.encode(to: q,
					 inputs: g.placeholderTensors.compactMap { w[$0] },
					 results: .some([MPSGraphTensorData($2 as MPSMatrix)]),
					 executionDescriptor: .some(.init(complete: $3)))
		}
	}
}
