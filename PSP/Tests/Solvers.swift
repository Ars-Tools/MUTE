//
//  Solvers.swift
//  MUTE
//
//  Created by Kota on 6/8/26.
//
import Testing
import simd
import Numerics
import BLAS
import func Layout.product
@testable import PSP
@Suite
struct SolverTestCases {
//    @Test(arguments: [-4.0 ... 4.0])
//    func mv4(range: ClosedRange<Float64>) {
//        let Ar = matrix_double4x4(rows: repeatElement(range, count: 4).map(SIMD4<Float64>.random(in:)))
//        let Ai = matrix_double4x4(rows: repeatElement(range, count: 4).map(SIMD4<Float64>.random(in:)))
//        let xr = .random(in: range) as SIMD4<Float64>
//        let xi = .random(in: range) as SIMD4<Float64>
//        
//        let yr = Ar * xr - Ai * xi
//        let yi = Ar * xi + Ai * xr
//        
//        let A = product(0..<4, 0..<4).map {
//            Complex128(real: Ar[$0][$1], imag: Ai[$0][$1])
//        }
//        let x = (0..<4).map { Complex128(real: xr[$0], imag: xi[$0]) }
//        let y = (0..<4).map { Complex128(real: yr[$0], imag: yi[$0]) }
//        
//        let z = Array<Complex128>(unsafeUninitializedCapacity: 4) {
//            gmv(m: 4, n: 4,
//                A: A,
//                x: x,
//                y: $0.baseAddress.unsafelyUnwrapped)
//            $1 = $0.count
//        }
//        #expect(zip(y, z).lazy.map(-).map(\.magnitude).allSatisfy { $0 < .ulpOfOne.squareRoot() })
//    }
//    @Test(arguments: [-4.0 ... 4.0])
//    func mm4(range: ClosedRange<Float64>) {
//        let Ar = matrix_double4x4(rows: repeatElement(range, count: 4).map(SIMD4<Float64>.random(in:)))
//        let Ai = matrix_double4x4(rows: repeatElement(range, count: 4).map(SIMD4<Float64>.random(in:)))
//        
//        let Br = matrix_double4x4(rows: repeatElement(range, count: 4).map(SIMD4<Float64>.random(in:)))
//        let Bi = matrix_double4x4(rows: repeatElement(range, count: 4).map(SIMD4<Float64>.random(in:)))
//        
//        let Cr = Ar * Br - Ai * Bi
//        let Ci = Ar * Bi + Ai * Br
//
//        let A = product(0..<4, 0..<4).map {
//            Complex128(real: Ar[$0][$1], imag: Ai[$0][$1])
//        }
//        let B = product(0..<4, 0..<4).map {
//            Complex128(real: Br[$0][$1], imag: Bi[$0][$1])
//        }
//        let C = product(0..<4, 0..<4).map {
//            Complex128(real: Cr[$0][$1], imag: Ci[$0][$1])
//        }
//        let D = Array<Complex128>(unsafeUninitializedCapacity: 16) {
//            gmm(m: 4, n: 4, k: 4,
//                A: A,
//                B: B,
//                C: $0.baseAddress.unsafelyUnwrapped)
//            $1 = $0.count
//        }
//        #expect(zip(C, D).lazy.map(-).map(\.magnitude).allSatisfy { $0 < .ulpOfOne.squareRoot() })
//    }
    @Test
    func luSolve() throws {
        let Ar = matrix_double4x4(rows: repeatElement(-1.0 ... 1.0, count: 4).map(SIMD4<Float64>.random(in:)))
        let Ai = matrix_double4x4(rows: repeatElement(-1.0 ... 1.0, count: 4).map(SIMD4<Float64>.random(in:)))
        let br = .random(in: -1 ... 1) as SIMD4<Float64>
        let bi = .random(in: -1 ... 1) as SIMD4<Float64>
        let invAr =  simd_inverse(Ar + Ai * simd_inverse(Ar) * Ai)
        let invAi = -simd_inverse(Ai + Ar * simd_inverse(Ai) * Ar)
        
        let xr = invAr * br - invAi * bi
        let xi = invAr * bi + invAi * br
        
        let solver = try Solver.LU(count: 4, matrix: product(0..<4, 0..<4).map {
            .init(real: Ar[$0.x][$0.y], imag: Ai[$0.x][$0.y])
        })
        let result = try solver.solve(nrhs: 1, b: (0..<4).map { .init(real: br[$0], imag: bi[$0]) })
        let expect = (0..<4).map { Complex128(real: xr[$0], imag: xi[$0]) }
        #expect(zip(expect, result).lazy.map(-).map(\.magnitudeSquared).allSatisfy { $0 < .ulpOfOne })
    }
    @Test
    func luMultiply() throws {
        let Ar = matrix_double4x4(
            .init(4, 0, 0, 0),
            .init(0, 3, 0, 0),
            .init(0, 0, 2, 0),
            .init(0, 0, 0, 1)
        )
        let Ai = matrix_double4x4(
            .init(1, 0, 0, 0),
            .init(0, 2, 0, 0),
            .init(0, 0, 3, 0),
            .init(0, 0, 0, 4)
        )
        let xr = .random(in: -1 ... 1) as SIMD4<Float64>
        let xi = .random(in: -1 ... 1) as SIMD4<Float64>
        
        let yr = Ar * xr - Ai * xi
        let yi = Ar * xi + Ai * xr
        
        let solver = try Solver.LU(count: 4, matrix: product(0..<4, 0..<4).map {
            Complex128(real: Ar[$0.x][$0.y], imag: Ai[$0.x][$0.y])
        })
        let result = solver.multiply(X: (0..<4).map { .init(real: xr[$0], imag: xi[$0]) })
        let expect = (0..<4).map { Complex128(real: yr[$0], imag: yi[$0]) }
        #expect(zip(expect, result).lazy.map(-).map(\.magnitudeSquared).allSatisfy { $0 < .ulpOfOne })
    }
    @Test
    func gmresSolve() throws {
        let Ar = matrix_double4x4(rows: repeatElement(-1.0 ... 1.0, count: 4).map(SIMD4<Float64>.random(in:)))
        let Ai = matrix_double4x4(rows: repeatElement(-1.0 ... 1.0, count: 4).map(SIMD4<Float64>.random(in:)))
        let br = .random(in: -1 ... 1) as SIMD4<Float64>
        let bi = .random(in: -1 ... 1) as SIMD4<Float64>
        let invAr =  simd_inverse(Ar + Ai * simd_inverse(Ar) * Ai)
        let invAi = -simd_inverse(Ai + Ar * simd_inverse(Ai) * Ar)
        
        let xr = invAr * br - invAi * bi
        let xi = invAr * bi + invAi * br
        
        let solver = Solver.GMRES(count: 4, matrix: product(0..<4, 0..<4).map {
            .init(real: Ar[$0.x][$0.y], imag: Ai[$0.x][$0.y])
        })
        let result = try solver.solve(B: (0..<4).map { .init(real: br[$0], imag: bi[$0]) })
        let expect = (0..<4).map { Complex128(real: xr[$0], imag: xi[$0]) }
        #expect(zip(expect, result).lazy.map(-).map(\.magnitudeSquared).allSatisfy { $0 < .ulpOfOne })
    }
    @Test
    func gmresMultiply() throws {
        let Ar = matrix_double4x4(rows: repeatElement(-1.0 ... 1.0, count: 4).map(SIMD4<Float64>.random(in:)))
        let Ai = matrix_double4x4(rows: repeatElement(-1.0 ... 1.0, count: 4).map(SIMD4<Float64>.random(in:)))
        
        let xr = .random(in: -1 ... 1) as SIMD4<Float64>
        let xi = .random(in: -1 ... 1) as SIMD4<Float64>
        
        let yr = Ar * xr - Ai * xi
        let yi = Ar * xi + Ai * xr
        
        let solver = Solver.GMRES(count: 4, matrix: product(0..<4, 0..<4).map {
            .init(real: Ar[$0.x][$0.y], imag: Ai[$0.x][$0.y])
        })
        let result = solver.multiply(X: (0..<4).map { .init(real: xr[$0], imag: xi[$0]) })
        let expect = (0..<4).map { Complex128(real: yr[$0], imag: yi[$0]) }
        #expect(zip(expect, result).lazy.map(-).map(\.magnitudeSquared).allSatisfy { $0 < .ulpOfOne })
    }
    @Test
    func ldltSolve() throws {
        let Ar = matrix_double4x4(
            .init(4, 0, 0, 0),
            .init(0, 3, 0, 0),
            .init(0, 0, 2, 0),
            .init(0, 0, 0, 1)
        )
        let Ai = matrix_double4x4(
            .init(1, 0, 0, 0),
            .init(0, 2, 0, 0),
            .init(0, 0, 3, 0),
            .init(0, 0, 0, 4)
        )
        let br = .random(in: -1 ... 1) as SIMD4<Float64>
        let bi = .random(in: -1 ... 1) as SIMD4<Float64>
        let invAr =  simd_inverse(Ar + Ai * simd_inverse(Ar) * Ai)
        let invAi = -simd_inverse(Ai + Ar * simd_inverse(Ai) * Ar)
        
        let xr = invAr * br - invAi * bi
        let xi = invAr * bi + invAi * br
        
        let solver = Solver.LDLT(count: 4, matrix: .init(uniqueKeysWithValues: product(0..<4, 0..<4).lazy.map {
            (.init($0, $1), Complex128(real: Ar[$1][$0], imag: Ai[$1][$0]))
        }))
        let result = try solver.solve(nrhs: 1, B: (0..<4).map { .init(real: br[$0], imag: bi[$0]) })
        let expect = (0..<4).map { Complex128(real: xr[$0], imag: xi[$0]) }
        #expect(zip(expect, result).lazy.map(-).map(\.magnitudeSquared).allSatisfy { $0 < .ulpOfOne })
    }
    @Test
    func ldltMultiply() throws {
        let Ar = matrix_double4x4(
            .init(4, 0, 0, 0),
            .init(0, 3, 0, 0),
            .init(0, 0, 2, 0),
            .init(0, 0, 0, 1)
        )
        let Ai = matrix_double4x4(
            .init(1, 0, 0, 0),
            .init(0, 2, 0, 0),
            .init(0, 0, 3, 0),
            .init(0, 0, 0, 4)
        )
        let xr = .random(in: -1 ... 1) as SIMD4<Float64>
        let xi = .random(in: -1 ... 1) as SIMD4<Float64>
        
        let yr = Ar * xr - Ai * xi
        let yi = Ar * xi + Ai * xr
        
        let solver = Solver.LDLT(count: 4, matrix: .init(uniqueKeysWithValues: product(0..<4, 0..<4).lazy.map {
            (.init($0, $1), Complex128(real: Ar[$1][$0], imag: Ai[$1][$0]))
        }))
        let result = solver.multiply(X: (0..<4).map { .init(real: xr[$0], imag: xi[$0]) })
        let expect = (0..<4).map { Complex128(real: yr[$0], imag: yi[$0]) }
        #expect(zip(expect, result).lazy.map(-).map(\.magnitudeSquared).allSatisfy { $0 < .ulpOfOne })
    }
}
