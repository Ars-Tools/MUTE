//
//  Waveshape+Spline.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import protocol Combine.Publisher
import Accelerate.vecLib
import struct Synchronization.Mutex
import typealias NSP.spline_anchor_t
import func NSP.spline_interpolation
import func simd.fma
import func Layout.concat
public enum Spline {
	public enum Interpolation: Sendable {
		case linear
		case cubic
	}
	@usableFromInline
	struct Kr<Anchor: Publisher<(Int, Dictionary<Float64, Float64>), Never> & Sendable> {
		@usableFromInline let phasor: Stream
		@usableFromInline let anchor: Anchor
		@usableFromInline let engine: Interpolation
	}
}
extension spline_anchor_t {
	@inlinable @inline(__always)
	init(lower: SIMD2<Float64>, upper: SIMD2<Float64>) {
		let Δ = upper - lower
		let z = SIMD2<Float64>(1, -lower.x) / Δ.x
		self.init(x: .init(lower.x, upper.x, z.x, z.y), y: .init(lower.y, upper.y, 0, 0))
	}
	@inlinable @inline(__always)
	init(lower: SIMD2<Float64>, upper: SIMD2<Float64>, cubic: SIMD2<Float64>) {
		let Δ = upper - lower
		let z = SIMD2<Float64>(1, -lower.x) / Δ.x
		let w = fma(cubic, .init(repeating: Δ.x), .init(repeating: -Δ.y))
		self.init(x: .init(lower.x, upper.x, z.x, z.y), y: .init(lower.y, upper.y, w.x, -w.y))
	}
	@inlinable @inline(__always)
	func translate(Δx: Float64) -> Self {
		let x = SIMD2<Float64>(x.x, x.y) + Δx
		let z = SIMD2<Float64>(-1, x.x) / ( x.x - x.y )
		return .init(x: .init(x.x, x.y, z.x, z.y), y: y)
	}
}
extension Spline.Kr {
	@inlinable
	func solveCholesky(colStart: UnsafePointer<Int>,
					   rowIndex: UnsafePointer<Int32>,
					   valArray: UnsafePointer<Float64>,
					   b: UnsafePointer<Float64>,
					   n: Int) -> Array<Float64> {
		let factor = SparseFactor(SparseFactorizationCholesky,
								  .init(structure: .init(rowCount: .init(n), columnCount: .init(n), columnStarts: .init(mutating: colStart), rowIndices: .init(mutating: rowIndex), attributes: .init(transpose: false, triangle: SparseLowerTriangle, kind: SparseSymmetric, _reserved: 0, _allocatedBySparse: false), blockSize: 1),
										data: .init(mutating: valArray)))
		defer {
			SparseCleanup(factor)
		}
		return.init(unsafeUninitializedCapacity: n + (factor.solveWorkspaceRequiredStatic + factor.solveWorkspaceRequiredPerRHS - 1) / MemoryLayout<Float64>.stride + 1) {
			SparseSolve(factor,
						.init(count: .init(n), data: .init(mutating: b)),
						.init(count: .init(n), data: $0.baseAddress.unsafelyUnwrapped),
						$0.baseAddress.unsafelyUnwrapped.advanced(by: n))
			$1 = n
		}
	}
	@inlinable
	func solveCG(colStart: UnsafePointer<Int>,
				 rowIndex: UnsafePointer<Int32>,
				 valArray: UnsafePointer<Float64>,
				 b: UnsafePointer<Float64>,
				 n: Int) -> Array<Float64> {
		.init(unsafeUninitializedCapacity: n) {
			let scaling = SparseCreatePreconditioner(SparsePreconditionerDiagScaling, .init(structure: .init(rowCount: .init(n), columnCount: .init(n), columnStarts: .init(mutating: colStart), rowIndices: .init(mutating: rowIndex), attributes: .init(transpose: false, triangle: SparseLowerTriangle, kind: SparseSymmetric, _reserved: 0, _allocatedBySparse: false), blockSize: 1),
																							data: .init(mutating: valArray)))
			defer {
				SparseCleanup(scaling)
			}
			switch SparseSolve(.init(method: _SparseMethodCG.rawValue, options: .init(cg: .init())),
							   .init(structure: .init(rowCount: .init(n), columnCount: .init(n), columnStarts: .init(mutating: colStart), rowIndices: .init(mutating: rowIndex), attributes: .init(transpose: false, triangle: SparseLowerTriangle, kind: SparseSymmetric, _reserved: 0, _allocatedBySparse: false), blockSize: 1),
									 data: .init(mutating: valArray)),
							   .init(count: .init(n), data: .init(mutating: b)),
							   .init(count: .init(n), data: $0.baseAddress.unsafelyUnwrapped),
							   scaling) {
			case SparseIterativeConverged:
				$1 = $0.count
			default:
				break
			}
		}
	}
	@inlinable
	func solve(A: Array<Dictionary<Int, Float64>>, b: Array<Float64>, n: Int) -> Array<Float64> {
		let (colStart, rowIndex, valArray) = A.reduce(into: (Array<Int>(arrayLiteral: 0), Array<Int32>(), Array<Float64>())) {
			for (row, val) in $1 where val.isNormal {
				$0.2.append(val)
				$0.1.append(.init(row))
			}
			$0.0.append($0.1.count)
		}
		return solveCholesky(colStart: colStart, rowIndex: rowIndex, valArray: valArray, b: b, n: n)
	}
}
extension Spline.Kr {
	@inlinable
	func organise(anchor: Dictionary<Float64, Float64>) ->  Array<(SIMD2<Float64>, SIMD2<Float64>)> {
		let sorted = anchor.lazy.map {
			SIMD2<Float64>(($0.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1), $1)
		}.sorted(using: KeyPathComparator(\.x))
		return zip(sorted, concat(sorted.dropFirst(), sorted.prefix(1).map { $0 + .init(1, 0) })).map(\.self)
	}
}
extension Spline.Kr {
	@inlinable
	func solve(linear anchor: Dictionary<Float64, Float64>) ->  Array<spline_anchor_t> {
		let fragments = organise(anchor: anchor)
		let anchor = fragments.map(spline_anchor_t.init(lower:upper:))
		return anchor.suffix(1).map { $0.translate(Δx: -1) } + anchor
	}
}
extension Spline.Kr {
	@inlinable
	func solve(cubic anchor: Dictionary<Float64, Float64>) -> Array<spline_anchor_t> {
		let fragments = organise(anchor: anchor)
		let n = fragments.count
		let k = solve(A: fragments.enumerated().reduce(into: Array<Dictionary<Int, Float64>>(repeating: .init(), count: n)) {
			let (k, ƒ) = $1
			let Δ = ƒ.1.x - ƒ.0.x
			let p = ( k + 1 ) % n
			let ν = SIMD2<Float64>(2, 1) / Δ
			$0[k].merge([
				k:ν.x,
				p:ν.y
			], uniquingKeysWith: +)
			$0[p].merge([
//				k:ν.y, // unnecessary because of lower triangle
				p:ν.x,
			], uniquingKeysWith: +)
		}, b: fragments.enumerated().reduce(into: Array<Float64>(repeating: .zero, count: n)) {
			let (k, ƒ) = $1
			let Δ = ƒ.1 - ƒ.0
			let p = ( k + 1 ) % n
			let ν = 3 * Δ.y / Δ.x / Δ.x
			$0[k] += ν
			$0[p] += ν
		}, n: n)
		let anchor = zip(fragments, zip(k, k.roll(head: 1)).lazy.map(SIMD2<Float64>.init(x:y:))).map {
			spline_anchor_t(lower: $0.0, upper: $0.1, cubic: $1)
		}
		return anchor.suffix(1).map { $0.translate(Δx: -1) } + anchor
	}
}
extension Spline.Kr: Stream {
	@inlinable
	var count: Int {
		phasor.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try phasor(interval: interval, capacity: capacity, instance: &instance)
		let status = Mutex<Array<Array<spline_anchor_t>>>(.init(repeating: .init(), count: phasor.count))
		let cancel = switch engine {
		case.linear:
			anchor.sink { index, value in
				let answer = solve(linear: value)
				guard !answer.isEmpty else { return }
				status.withLock {
					switch index {
					case $0.indices:
						$0[index] = answer
					default:
						assertionFailure("out of range")
					}
				}
			}
		case.cubic:
			anchor.sink { index, value in
				let answer = solve(cubic: value)
				guard !answer.isEmpty else { return }
				status.withLock {
					switch index {
					case $0.indices:
						$0[index] = answer
					default:
						assertionFailure("out of range")
					}
				}
			}
		}
		return {
			kernel($0, $1, $2, $3)
			let status = withExtendedLifetime(cancel) { status.withLock(\.self) }
			for (offset, anchor) in status.enumerated() {
				spline_interpolation($2.advanced(by: offset * $3),
									 $2.advanced(by: offset * $3),
									 anchor,
									 anchor.count,
									 $1)
			}
		}
	}
}
public func spline(_ phasor: Stream, spline anchor: some Publisher<(Int, Dictionary<Float64, Float64>), Never> & Sendable, mode engine: Spline.Interpolation = .linear) -> some Stream {
	Spline.Kr(phasor: phasor, anchor: anchor, engine: engine)
}
public func spline(_ phasor: Stream, spline anchor: some Publisher<Dictionary<Float64, Float64>, Never>, mode: Spline.Interpolation = .linear) -> some Stream {
	spline(phasor, spline: anchor.repeat(count: phasor.count), mode: mode)
}
public func spline(_ phasor: Stream, spline anchor: Dictionary<Float64, Float64>, mode: Spline.Interpolation = .linear) -> some Stream {
	spline(phasor, spline: `repeat`(anchor, count: phasor.count), mode: mode)
}
