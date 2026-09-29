//
//  Solvers.swift
//  MUTE
//
//  Created by Kota on 6/16/26.
//
import Testing
import Numerics
import Accelerate
@testable import Acoustica
//@Suite
//struct SolverTestCases {
//    @Test
//    func GL() {
//        guard let object = gl_quadrature_create(8) else {
//            Issue.record()
//            return
//        }
//        defer {
//            gl_quadrature_destroy(object)
//        }
//        let x = [1,2,3]
//        bem2_create(3.5, 3, 3) {
//            _ = $1
//            print(x)
//            return.init(position: .zero,
//                        gradient: .zero)
//        }
////        #expect(result == 72 - 9)
//        //SIMD2<Double>(-0.3825, -0.8249999999999998)
//    }
//    @Test
//    func lu() {
//        let solver = lu_solver_create(4, 4) {
//            for k in 0..<4 {
//                UnsafeMutablePointer<Complex128>($0)[k*$1+k] = .init(real: .init(k + 1), imag: .zero)
//            }
//        }
//        guard let solver else { fatalError() }
//        var x = Array<Complex128>(repeating: 1, count: 4)
//        lu_solver_solve(solver, 1,
//                 .init(x.withUnsafeBufferPointer(\.baseAddress.unsafelyUnwrapped)), 1,
//                 .init(x.withUnsafeMutableBufferPointer(\.baseAddress.unsafelyUnwrapped)), 1)
//        print(x)
//        lu_solver_multiply(solver, 1,
//                    .init(x.withUnsafeBufferPointer(\.baseAddress.unsafelyUnwrapped)), 1,
//                    .init(x.withUnsafeMutableBufferPointer(\.baseAddress.unsafelyUnwrapped)), 1)
//        print(x)
//    }
//}
