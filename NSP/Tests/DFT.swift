//
//  DFT.swift
//  MUTE
//
//  Created by Kota on 8/28/R7.
//
import Testing
import Numerics
@testable import NSP
@Suite
struct DFTTestCase {
	@Test(arguments: [
		4096,
		1024,
		128 * 3,
		128 * 5,
		64 * 15,
	])
	func ddft_vs_vDSP_acc(count: Int) throws {
		let x = repeatElement(-1.0 ... 1.0, count: count).map {
			DSPDoubleComplex(real: .random(in: $0), imag: .random(in: $0))
		}
		let source = Array<DSPDoubleComplex>(unsafeUninitializedCapacity: count) {
			let object = ddft_create(count)
			defer { ddft_destroy(object) }
			ddft_forward(object, .init(x), .init($0.baseAddress.unsafelyUnwrapped))
			$1 = $0.count
		}
		let target = try vDSP.DiscreteFourierTransform(count: count, direction: .forward, transformType: .complexComplex, ofType: DSPDoubleComplex.self)
			.transform(input: x)
		let Δ = zip(source, target).map {
            (unsafeBitCast($0, to: Complex128.self) - unsafeBitCast($1, to: Complex128.self)).magnitude
		}
		let EΔ = vDSP.maximum(Δ)
		#expect(EΔ < 1e-3)
	}
	@Test(arguments: [
		2,
		2*3,
		2*3*5,
		2*3*5*7,
		2*3*5*7*11
	])
	func ddft_vs_dfft_acc(count: Int) throws {
		let x = repeatElement(-1.0 ... 1.0, count: count).map {
			DSPDoubleComplex(real: .random(in: $0), imag: .random(in: $0))
		}
		let source = Array<DSPDoubleComplex>(unsafeUninitializedCapacity: count) {
			let object = ddft_create(count)
			defer { ddft_destroy(object) }
			ddft_forward(object, .init(x), .init($0.baseAddress.unsafelyUnwrapped))
			$1 = $0.count
		}
		let target = Array<DSPDoubleComplex>(unsafeUninitializedCapacity: count) {
			let object = ddft_create([count, 1]) // just dft
			defer { ddft_destroy(object) }
			ddft_forward(object, .init(x), .init($0.baseAddress.unsafelyUnwrapped))
			$1 = $0.count
		}
		let Δ = zip(source, target).map {
            (unsafeBitCast($0, to: Complex128.self) - unsafeBitCast($1, to: Complex128.self)).magnitude
		}
		let EΔ = vDSP.maximum(Δ)
		#expect(EΔ < 1e-3)
	}
    @Test(arguments: [
        2,
        2*3,
        2*3*5,
        2*3*5*7,
        2*3*5*7*11,
    ])
    func bdft_vs_dfft_acc(count: Int) throws {
        let x = repeatElement(-1.0 ... 1.0, count: count).map {
            Complex128(real: .random(in: $0), imag: .zero)
        } as Array
        let source = Array<Complex128>(unsafeUninitializedCapacity: count) {
            let object = bdft_create(count)
            defer { bdft_destroy(object) }
//            bdft_dump(object)
            bdft_forward(object, .init(x), .init($0.baseAddress.unsafelyUnwrapped))
            $1 = $0.count
        }
        let target = Array<Complex128>(unsafeUninitializedCapacity: count) {
            let object = ddft_create([count, 1]) // just dft
            defer { ddft_destroy(object) }
            ddft_forward(object, .init(x), .init($0.baseAddress.unsafelyUnwrapped))
            $1 = $0.count
        }
        let Δ = zip(source, target).map(-).map(\.magnitude)
        let EΔ = vDSP.maximum(Δ)
        #expect(EΔ < 1e-3)
    }
	@Test(arguments: [
		Array<Int>(repeating: 2, count: 16),
		Array<Int>(repeating: 3, count: 13),
		Array<Int>(repeating: 5, count: 10),
		[2],
		[2,3],
		[2,3,5],
		[2,3,5,7],
		[2,3,5,7,11],
		[2,3,5,7,11,13],
		[2,3,5,7,11,13,17],
		[2,3,5,7,11,13,17,19],
		[2,3,5,7,11,13,17,19,23],
	])
	func prime_factorisation(primes: Array<Int>) {
		let answer = primes.reversed().reduce(into: [1]) {
			$0.append($0.last.unsafelyUnwrapped * $1)
		}
		#expect(Array<Int>(unsafeUninitializedCapacity: 64) {
			$1 = pd(answer.last.unsafelyUnwrapped, $0.baseAddress.unsafelyUnwrapped)
		} == answer.reversed())
	}
    @Test(arguments: [
        21
    ])
    func `do`(count: Int) {
        let x = Array<Int>(unsafeUninitializedCapacity: count) {
            $1 = pd(count, $0.baseAddress.unsafelyUnwrapped)
        }
        print(x)
        let dft = bdft_create([6,2,1])
        bdft_dump(dft)
        bdft_destroy(dft)
    }
    @Test(arguments: [
        3*5*4096,
//        1<<18,
//        1<<16,
//        4096,
//        1024,
//        3*5*64,
//        2*3*4*5
    ])
    func elapse(count: Int) throws {
        let x = repeatElement(-1.0 ... 1.0, count: count).map {
            Complex128(real: .random(in: $0), imag: .zero)
        }
        let part = try Array<Float64>(unsafeUninitializedCapacity: 2 * count) {
            $1 = $0.count
            let object = try vDSP.DiscreteFourierTransform(count: count, direction: .forward, transformType: .complexComplex, ofType: Float64.self)
            let r = x.map(\.real)
            let i = x.map(\.imag)
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "vdsp: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            object.transform(inputReal: r, inputImaginary: i,
                             outputReal: &$0[0*count..<1*count],
                             outputImaginary: &$0[1*count..<2*count])
        }
        #expect(part.count == 2 * count)
        let vdsp = zip(part.prefix(count), part.suffix(count)).map(Complex128.init(real:imag:))
        let ddft = Array<Complex128>(unsafeUninitializedCapacity: count) {
            $1 = $0.count
            let object = ddft_create(count)
            defer { ddft_destroy(object) }
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "ddft: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            ddft_forward(object, .init(x), .init($0.baseAddress.unsafelyUnwrapped))
        }
        let bdft = Array<Complex128>(unsafeUninitializedCapacity: count) {
            $1 = $0.count
            let object = bdft_create(count)
            defer { bdft_destroy(object) }
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "bdft: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            bdft_forward(object, .init(x), .init($0.baseAddress.unsafelyUnwrapped))
        }
//        let xdft = Array<Complex128>(unsafeUninitializedCapacity: count) {
//            $1 = $0.count
//            let object = xdft_create(count)
//            defer { xdft_destroy(object) }
//            print("xdft ready")
//            let s = CFAbsoluteTimeGetCurrent()
//            defer {
//                print("xdft", CFAbsoluteTimeGetCurrent() - s)
//            }
//            xdft_inverse(object, .init(x), .init($0.baseAddress.unsafelyUnwrapped))
//        }
//        print(x, vdsp, ddft, bdft, xdft, separator: "\r\n")
        #expect(vDSP.maximum(zip(vdsp, ddft).map(-).map(\.magnitude)) < 1e-6)
        #expect(vDSP.maximum(zip(vdsp, bdft).map(-).map(\.magnitude)) < 1e-6)
//        #expect(vDSP.maximum(zip(vdsp, xdft).map(-).map(\.magnitude)) < 1e-6)
    }
    @Test
    func bdft_vs_fftm() throws {
        let log2n = 8
        let count = 1 << log2n
        let fftm = vDSP_create_fftsetupD(.init(log2n), .init(kFFTRadix2)).unsafelyUnwrapped
        defer { vDSP_destroy_fftsetupD(fftm) }
        let bdft = bdft_create(count)
        defer { bdft_destroy(bdft) }
        let x = UnsafeMutablePointer<Complex128>.allocate(capacity: 2 * count)
        defer { x.deallocate() }
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: 2 * count)
        defer { y.deallocate() }
        for k in 0..<2 * count {
            x[k] = .init(real: .init(Int.random(in: -6 ... 6)),
                         imag: .zero)
        }
        var z = DSPDoubleSplitComplex(realp: .init(.init(x)).advanced(by: 0),
                                      imagp: .init(.init(x)).advanced(by: 1))
//        print(Array(UnsafeBufferPointer(start: x, count: 2 * count)))
        do {
            let start = CFAbsoluteTimeGetCurrent()
            defer {
                print("bdft", CFAbsoluteTimeGetCurrent() - start)
            }
            bdft_forward(bdft, 2,
                         .init(x), count,
                         .init(y), count)
        }
        do {
            let start = CFAbsoluteTimeGetCurrent()
            defer {
                print("fftm", CFAbsoluteTimeGetCurrent() - start)
            }
            vDSP_fftm_zipD(fftm, &z, 2, 2 * count, .init(log2n), 2, .init(kFFTDirection_Forward))
        }
//        print(Array(UnsafeBufferPointer(start: x, count: 2 * count)))
//        print(Array(UnsafeBufferPointer(start: y, count: 2 * count)))
    }
    @Test
    func bdft_qr() throws {
        let count = 16
        let bdft = bdft_create(count)
        defer { bdft_destroy(bdft) }
        
        let x = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:)).map(Complex128.init(floatLiteral:))
        let X = Array<Complex128>(unsafeUninitializedCapacity: x.count) {
            bdft_forward(bdft, .init(x), .init($0.baseAddress.unsafelyUnwrapped))
            $1 = $0.count
        }
//        SparseMatrix_Complex_Double x = SparseConvertFromOpaque(object->prime[0]);
//        SparseOpaqueFactorization_Complex_Double const qr = SparseFactor(SparseFactorizationQR, x);
//        SparseOpaqueSubfactor_Complex_Double const l = SparseCreateSubfactor(SparseSubfactorQ, qr);
//        SparseOpaqueSubfactor_Complex_Double const u = SparseCreateSubfactor(SparseSubfactorR, qr);
//        SparseMultiply(l, (DenseVector_Complex_Double const) {
//            .data = 0L,
//            .count = 100
//        });
    }
}
