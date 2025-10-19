//
//  Mix+Matrix.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
@preconcurrency import protocol Combine.Publisher
import typealias Synchronization.Mutex
import protocol Accelerate.AccelerateMatrixBuffer
import func Accelerate.SparseMultiply
import func Accelerate.cblas_dgemm
import let Accelerate.CblasRowMajor
import let Accelerate.CblasNoTrans
public enum Matrix {
	public enum Format: Sendable {
		case dense
		case sparse
	}
}
extension Matrix {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, Int, Float64), Never> & Sendable> {
		@usableFromInline let source: Stream
		@usableFromInline let weight: Signal
		@usableFromInline let format: Format
		@usableFromInline let output: Int
	}
}
extension Matrix.Kr {
    @inlinable@inline(__always)@_transparent
	func multiply(rows: Int, cols: Int, length: Int,
				  m: UnsafePointer<Float64>,
				  x: UnsafePointer<Float64>, ldx: Int,
				  y: UnsafeMutablePointer<Float64>, ldy: Int) {
		cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
					rows, length, cols,
					1,
					m, cols,
					x, ldx,
					0,
					y, ldy)
	}
	@inlinable@inline(__always)@_transparent
	func multiply(rows: Int, cols: Int, length: Int,
				  colStart: UnsafePointer<Int>, rowIndex: UnsafePointer<Int32>, elements: UnsafePointer<Float64>,
				  x: UnsafePointer<Float64>, ldx: Int,
				  y: UnsafeMutablePointer<Float64>, ldy: Int) {
		SparseMultiply(.init(structure: .init(rowCount: .init(rows),
											  columnCount: .init(cols),
											  columnStarts: .init(mutating: colStart),
											  rowIndices: .init(mutating: rowIndex),
											  attributes: .init(),
											  blockSize: 1),
							 data: .init(mutating: elements)),
					   .init(rowCount: .init(length),
							 columnCount: .init(cols),
							 columnStride: .init(ldx),
							 attributes: .init(transpose: true, triangle: .init(0), kind: .init(0), _reserved: 0, _allocatedBySparse: false),
							 data: .init(mutating: x)),
					   .init(rowCount: .init(length),
							 columnCount: .init(rows),
							 columnStride: .init(ldy),
							 attributes: .init(transpose: true, triangle: .init(0), kind: .init(0), _reserved: 0, _allocatedBySparse: false),
							 data: .init(mutating: y)))
	}
}
extension Matrix.Kr: Stream {
	@inlinable
	var count: Int {
		output
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let rows = output
		let cols = source.count
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		switch format {
		case.dense:
			let matrix = Mutex<Array<Float64>>(.init(repeating: .zero, count: rows * cols))
			let cancel = weight.sink { col, row, val in
				switch (row, col) {
				case (0..<rows, 0..<cols):
					matrix.withLock {
						$0[row*cols+col] = val
					}
				default:
					assertionFailure("out of range")
				}
			}
			return { moment, length, result, stride in
				let m = withExtendedLifetime(cancel) { matrix.withLock(\.self) }
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: cols * length) {
					guard let source = $0.baseAddress else { return }
					kernel(moment, length, source, length)
					multiply(rows: rows, cols: cols, length: length,
							 m: m,
							 x: source, ldx: length,
							 y: result, ldy: stride)
				}
			}
		case.sparse:
			let matrix = Mutex<(Array<Int>, Array<Int32>, Array<Float64>)>((.init(), .init(), .init()))
			let cancel = weight.scan(Array<Dictionary<Int, Float64>>(repeating: .init(), count: cols)) {
				var ccs = $0
				switch $1 {
				case (0..<rows, 0..<cols, .zero):
					ccs[$1.0].removeValue(forKey: $1.1)
				case (0..<rows, 0..<cols, let n):assert(n != .zero)
					ccs[$1.0].updateValue(n, forKey: $1.1)
				default:
					assertionFailure("out of range")
				}
				return ccs
			}.map {
				$0.reduce(into: (Array<Int>(arrayLiteral: 0), Array<Int32>(), Array<Float64>())) {
					$0.2.append(contentsOf: $1.values)
					$0.1.append(contentsOf: $1.keys.lazy.map(Int32.init))
					$0.0.append($0.2.count)
				}
			}.sink { sparse in
				matrix.withLock {
					$0 = sparse
				}
			}
			return { moment, length, result, stride in
				let (colStart, rowIndex, elements) = withExtendedLifetime(cancel) { matrix.withLock(\.self) }
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: cols * length) {
					guard let source = $0.baseAddress else { return }
					kernel(moment, length, source, length)
					multiply(rows: rows, cols: cols, length: length,
							 colStart: colStart, rowIndex: rowIndex, elements: elements,
							 x: source, ldx: length,
							 y: result, ldy: stride)
				}
			}
		}
	}
}
public func mix(_ source: Stream, weight matrix: some Publisher<(Int, Int, Float64), Never> & Sendable, output: Int, format: Matrix.Format = .sparse) -> some Stream {
	Matrix.Kr(source: source, weight: matrix, format: format, output: output)
}
public func mix(_ source: Stream, weight matrix: some Collection<some Sequence<Float64>>, format: Matrix.Format = .sparse) -> some Stream {
	Matrix.Kr(source: source, weight: matrix.enumerated().flatMap { row, col in col.enumerated().map { ($0, row, $1) } }.publisher, format: format, output: matrix.count)
}
public func mix(_ source: Stream, weight matrix: Dictionary<SIMD2<Int>, Float64>, output: Int, format: Matrix.Format = .sparse) -> some Stream {
	Matrix.Kr(source: source, weight: matrix.publisher.map { ($0.y, $0.x, $1) }, format: format, output: output)
}
public func mix(_ source: Stream, weight matrix: some AccelerateMatrixBuffer<Float64>, format: Matrix.Format = .sparse) -> some Stream {
	Matrix.Kr(source: source, weight: matrix.withUnsafeBufferPointer { buffer in
		switch matrix.accelerateMatrixOrder {
		case.rowMajor:
			(0..<matrix.rowCount).flatMap { row in
				let start = buffer.startIndex.advanced(by: row * matrix.leadingDimension)
				let end = start.advanced(by: matrix.columnCount)
				return buffer[start..<end].enumerated().map { ($0, row, $1) }
			}
		case.columnMajor:
			(0..<matrix.columnCount).flatMap { col in
				let start = buffer.startIndex.advanced(by: col * matrix.leadingDimension)
				let end = start.advanced(by: matrix.rowCount)
				return buffer[start..<end].enumerated().map { (col, $0, $1) }
			}
		}
	}.publisher, format: format, output: matrix.rowCount)
}
