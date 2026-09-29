//
//  DFT.swift
//  MUTE
//
//  Created by Kota on 8/28/R7.
//
import Testing
import Numerics
@testable import KSP
@Suite(.serialized)
struct DFTTestCase {
    @Test(
        arguments: [3, 5, 7, 11, 13, 17]
    )
    func jit_vec_acc(log2n: Int) {
        let count = 1 << log2n
        let x = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:)).map(Complex128.init)
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: 4 * count)
        let z = y.advanced(by: count)
        let w = z.advanced(by: count)
        defer { y.deallocate() }
        guard case.some(let dsp) = vDSP_create_fftsetupD(.init(log2n), .init(FFT_RADIX2)) else {
            Issue.record()
            return
        }
        var X = DSPDoubleSplitComplex(realp: .init(.init(x)).advanced(by: 0),
                                      imagp: .init(.init(x)).advanced(by: 1))
        var Y = DSPDoubleSplitComplex(realp: .init(.init(y)).advanced(by: 0),
                                      imagp: .init(.init(y)).advanced(by: 1))
        do {
            vDSP_fft_zopD(dsp,
                          &X, 2,
                          &Y, 2,
                          .init(log2n), .init(FFT_FORWARD))
            dft_forward(count,
                        .init(x), 1,
                        .init(z), 1,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: count),
                        UnsafeBufferPointer(start: z, count: count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
        do {
            vDSP_fft_zopD(dsp, &X, 2, &Y, 2, .init(log2n), .init(FFT_INVERSE))
            dft_inverse(count,
                        .init(x), 1,
                        .init(z), 1,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: count),
                        UnsafeBufferPointer(start: z, count: count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
    }
    @Test(
        arguments: [3, 5, 7, 11, 13, 17]
    )
    func jit_mat_acc(log2n: Int) {
        let nrhs = 5
        let count = 1 << log2n
        let x = UnsafeMutablePointer<Complex128>.allocate(capacity: 4 * nrhs * count)
        defer { x.deallocate() }
        let y = x.advanced(by: nrhs * count)
        let z = y.advanced(by: nrhs * count)
        let w = z.advanced(by: nrhs * count)
        let val = UnsafeMutableBufferPointer(start: x, count: nrhs * count)
            .initialize(fromContentsOf: repeatElement(-1.0 ... 1.0, count: nrhs * count).map(Float64.random(in:)).map(Complex128.init(floatLiteral:)))
        #expect(val == nrhs * count)
        guard case.some(let dsp) = vDSP_create_fftsetupD(.init(log2n), .init(FFT_RADIX2)) else {
            Issue.record()
            return
        }
        var X = DSPDoubleSplitComplex(realp: .init(.init(x)).advanced(by: 0),
                                      imagp: .init(.init(x)).advanced(by: 1))
        var Y = DSPDoubleSplitComplex(realp: .init(.init(y)).advanced(by: 0),
                                      imagp: .init(.init(y)).advanced(by: 1))
        do {
            vDSP_fftm_zopD(dsp,
                           &X, 2, 2 * count,
                           &Y, 2, 2 * count,
                           .init(log2n),
                           .init(nrhs),
                           .init(FFT_FORWARD))
            dft_forward(count, nrhs,
                        .init(x), count,
                        .init(z), count,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: nrhs * count),
                        UnsafeBufferPointer(start: z, count: nrhs * count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
        do {
            vDSP_fftm_zopD(dsp,
                           &X, 2, 2 * count,
                           &Y, 2, 2 * count,
                           .init(log2n),
                           .init(nrhs),
                           .init(FFT_INVERSE))
            dft_inverse(count, nrhs,
                        .init(x), count,
                        .init(z), count,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: nrhs * count),
                        UnsafeBufferPointer(start: z, count: nrhs * count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
    }
    @Test(
        arguments: [64, 128 * 35, 1023, 1024]
    )
    func dense_vec_acc(count: Int) {
        let x = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:)).map(Complex128.init)
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: 4 * count)
        defer { y.deallocate() }
        let z = y.advanced(by: count)
        let w = z.advanced(by: count)
        let dft = ddft_create([count, 1])
        defer {
            dft_destroy(dft)
        }
        do {
            dft_forward(count,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
            dft_forward(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(z), 1,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: count),
                        UnsafeBufferPointer(start: z, count: count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
        do {
            dft_inverse(count,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
            dft_inverse(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(z), 1,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: count),
                        UnsafeBufferPointer(start: z, count: count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
    }
    @Test(
        arguments: [64, 128 * 35, 1023, 1024]
    )
    func dense_mat_acc(count: Int) {
        let nrhs = 5
        let x = UnsafeMutablePointer<Complex128>.allocate(capacity: 3 * nrhs * count + count)
        defer { x.deallocate() }
        let y = x.advanced(by: nrhs * count)
        let z = y.advanced(by: nrhs * count)
        let w = z.advanced(by: nrhs * count)
        let val = UnsafeMutableBufferPointer(start: x, count: nrhs * count)
            .initialize(fromContentsOf: repeatElement(-1.0 ... 1.0, count: nrhs * count).map(Float64.random(in:)).map(Complex128.init(floatLiteral:)))
        #expect(val == nrhs * count)
        let dft = ddft_create([count, 1])
        defer {
            dft_destroy(dft)
        }
        do {
            dft_forward(count, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
            dft_forward(dft, .DFT_SCALE_ONE, nrhs,
                        .init(x), count,
                        .init(z), count,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: nrhs * count),
                        UnsafeBufferPointer(start: z, count: nrhs * count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
        do {
            dft_inverse(count, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
            dft_inverse(dft, .DFT_SCALE_ONE, nrhs,
                        .init(x), count,
                        .init(z), count,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: nrhs * count),
                        UnsafeBufferPointer(start: z, count: nrhs * count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
    }
    @Test(
        arguments: [64, 128 * 35, 1023, 1024]
    )
    func ddft_vec_acc(count: Int) {
        let x = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:)).map(Complex128.init)
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: 4 * count)
        defer { y.deallocate() }
        let z = y.advanced(by: count)
        let w = z.advanced(by: count)
        let dft = ddft_create(count)
        defer {
            dft_destroy(dft)
        }
        do {
            dft_forward(count,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
            dft_forward(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(z), 1,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: count),
                        UnsafeBufferPointer(start: z, count: count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
        do {
            dft_inverse(count,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
            dft_inverse(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(z), 1,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: count),
                        UnsafeBufferPointer(start: z, count: count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
    }
    @Test(
        arguments: [64, 128 * 35, 1023, 1024]
    )
    func ddft_mat_acc(count: Int) {
        let nrhs = 5
        let x = UnsafeMutablePointer<Complex128>.allocate(capacity: 4 * nrhs * count)
        defer { x.deallocate() }
        let y = x.advanced(by: nrhs * count)
        let z = y.advanced(by: nrhs * count)
        let w = z.advanced(by: nrhs * count)
        let val = UnsafeMutableBufferPointer(start: x, count: nrhs * count)
            .initialize(fromContentsOf: repeatElement(-1.0 ... 1.0, count: nrhs * count).map(Float64.random(in:)).map(Complex128.init(floatLiteral:)))
        #expect(val == nrhs * count)
        let dft = ddft_create(count)
        defer {
            dft_destroy(dft)
        }
        do {
            dft_forward(count, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
            dft_forward(dft, .DFT_SCALE_ONE, nrhs,
                        .init(x), count,
                        .init(z), count,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: nrhs * count),
                        UnsafeBufferPointer(start: z, count: nrhs * count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
        do {
            dft_inverse(count, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
            dft_inverse(dft, .DFT_SCALE_ONE, nrhs,
                        .init(x), count,
                        .init(z), count,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: nrhs * count),
                        UnsafeBufferPointer(start: z, count: nrhs * count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
    }
    @Test(
        arguments: [64, 128 * 35, 1023, 1024]
    )
    func bdft_vec_acc(count: Int) {
        let x = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:)).map(Complex128.init)
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: 4 * count)
        defer { y.deallocate() }
        let z = y.advanced(by: count)
        let w = z.advanced(by: count)
        let dft = bdft_create(count)
        defer {
            dft_destroy(dft)
        }
        do {
            dft_forward(count,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
            dft_forward(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(z), 1,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: count),
                        UnsafeBufferPointer(start: z, count: count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
        do {
            dft_inverse(count,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
            dft_inverse(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(z), 1,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: count),
                        UnsafeBufferPointer(start: z, count: count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
    }
    @Test(
        arguments: [64, 128 * 35, 1023, 1024]
    )
    func bdft_mat_acc(count: Int) {
        let nrhs = 5
        let x = UnsafeMutablePointer<Complex128>.allocate(capacity: 4 * nrhs * count)
        defer { x.deallocate() }
        let y = x.advanced(by: nrhs * count)
        let z = y.advanced(by: nrhs * count)
        let w = z.advanced(by: nrhs * count)
        let val = UnsafeMutableBufferPointer(start: x, count: nrhs * count)
            .initialize(fromContentsOf: repeatElement(-1.0 ... 1.0, count: nrhs * count).map(Float64.random(in:)).map(Complex128.init(floatLiteral:)))
        #expect(val == nrhs * count)
        let dft = bdft_create(count)
        defer {
            dft_destroy(dft)
        }
        do {
            dft_forward(count, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
            dft_forward(dft, .DFT_SCALE_ONE, nrhs,
                        .init(x), count,
                        .init(z), count,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: nrhs * count),
                        UnsafeBufferPointer(start: z, count: nrhs * count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
        do {
            dft_inverse(count, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
            dft_inverse(dft, .DFT_SCALE_ONE, nrhs,
                        .init(x), count,
                        .init(z), count,
                        .some(.init(w)))
            #expect(zip(UnsafeBufferPointer(start: y, count: nrhs * count),
                        UnsafeBufferPointer(start: z, count: nrhs * count)).map(-).map(\.magnitudeSquared).allSatisfy {
                $0.isLess(than: .ulpOfOne)
            })
        }
    }
    @Test(
        arguments: [64, 105, 127]
    )
    func bdft_split_vec_acc(count: Int) {
        let x = UnsafeMutablePointer<Complex128>.allocate(capacity: count)
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: count)
        let xr = UnsafeMutablePointer<Float64>.allocate(capacity: count)
        let xi = UnsafeMutablePointer<Float64>.allocate(capacity: count)
        let yr = UnsafeMutablePointer<Float64>.allocate(capacity: count)
        let yi = UnsafeMutablePointer<Float64>.allocate(capacity: count)
        let w = UnsafeMutablePointer<Complex128>.allocate(capacity: 2 * count)
        defer {
            x.deallocate()
            y.deallocate()
            xr.deallocate()
            xi.deallocate()
            yr.deallocate()
            yi.deallocate()
            w.deallocate()
        }
        for k in 0..<count {
            let real = Float64((17 * k + 3) % 31) / 15 - 1
            let imag = Float64((11 * k + 5) % 29) / 14 - 1
            x[k] = Complex128(real: real, imag: imag)
            xr[k] = real
            xi[k] = imag
        }
        let dft = bdft_create(count)
        defer { dft_destroy(dft) }
        do {
            dft_forward(dft, .DFT_SCALE_ONE,
                        .init(x),
                        .init(y),
                        .some(.init(w)))
            dft_forward(dft, .DFT_SCALE_ONE,
                        xr, xi,
                        yr, yi,
                        .some(.init(w)))
            #expect((0..<count).allSatisfy {
                (Complex128(real: yr[$0], imag: yi[$0]) - y[$0]).magnitudeSquared.isLess(than: .ulpOfOne)
            })
        }
        do {
            dft_inverse(dft, .DFT_SCALE_ONE,
                        .init(x),
                        .init(y),
                        .some(.init(w)))
            dft_inverse(dft, .DFT_SCALE_ONE,
                        xr, xi,
                        yr, yi,
                        .some(.init(w)))
            #expect((0..<count).allSatisfy {
                (Complex128(real: yr[$0], imag: yi[$0]) - y[$0]).magnitudeSquared.isLess(than: .ulpOfOne)
            })
        }
    }
    @Test(
        arguments: [64, 105, 127]
    )
    func bdft_split_strided_vec_acc(count: Int) {
        let incx = 2
        let incy = 3
        let x = UnsafeMutablePointer<Complex128>.allocate(capacity: count)
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: count)
        let xr = UnsafeMutablePointer<Float64>.allocate(capacity: count * incx)
        let xi = UnsafeMutablePointer<Float64>.allocate(capacity: count * incx)
        let yr = UnsafeMutablePointer<Float64>.allocate(capacity: count * incy)
        let yi = UnsafeMutablePointer<Float64>.allocate(capacity: count * incy)
        let w = UnsafeMutablePointer<Complex128>.allocate(capacity: 2 * count)
        defer {
            x.deallocate()
            y.deallocate()
            xr.deallocate()
            xi.deallocate()
            yr.deallocate()
            yi.deallocate()
            w.deallocate()
        }
        xr.initialize(repeating: .nan, count: count * incx)
        xi.initialize(repeating: .nan, count: count * incx)
        yr.initialize(repeating: .nan, count: count * incy)
        yi.initialize(repeating: .nan, count: count * incy)
        for k in 0..<count {
            let real = Float64((17 * k + 3) % 31) / 15 - 1
            let imag = Float64((11 * k + 5) % 29) / 14 - 1
            x[k] = Complex128(real: real, imag: imag)
            xr[k * incx] = real
            xi[k * incx] = imag
        }
        let dft = bdft_create(count)
        defer { dft_destroy(dft) }
        do {
            dft_forward(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
            dft_forward(dft, .DFT_SCALE_ONE,
                        xr, xi, incx,
                        yr, yi, incy,
                        .some(.init(w)))
            #expect((0..<count).allSatisfy {
                (Complex128(real: yr[$0 * incy], imag: yi[$0 * incy]) - y[$0]).magnitudeSquared.isLess(than: .ulpOfOne)
            })
        }
        do {
            dft_inverse(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
            dft_inverse(dft, .DFT_SCALE_ONE,
                        xr, xi, incx,
                        yr, yi, incy,
                        .some(.init(w)))
            #expect((0..<count).allSatisfy {
                (Complex128(real: yr[$0 * incy], imag: yi[$0 * incy]) - y[$0]).magnitudeSquared.isLess(than: .ulpOfOne)
            })
        }
    }
    @Test(
        arguments: [64, 105, 127]
    )
    func bdft_split_mat_acc(count: Int) {
        let nrhs = 3
        let ldx = count + 2
        let ldy = count + 3
        let x = UnsafeMutablePointer<Complex128>.allocate(capacity: nrhs * count)
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: nrhs * count)
        let xr = UnsafeMutablePointer<Float64>.allocate(capacity: nrhs * ldx)
        let xi = UnsafeMutablePointer<Float64>.allocate(capacity: nrhs * ldx)
        let yr = UnsafeMutablePointer<Float64>.allocate(capacity: nrhs * ldy)
        let yi = UnsafeMutablePointer<Float64>.allocate(capacity: nrhs * ldy)
        let w = UnsafeMutablePointer<Complex128>.allocate(capacity: 2 * nrhs * count)
        defer {
            x.deallocate()
            y.deallocate()
            xr.deallocate()
            xi.deallocate()
            yr.deallocate()
            yi.deallocate()
            w.deallocate()
        }
        xr.initialize(repeating: .nan, count: nrhs * ldx)
        xi.initialize(repeating: .nan, count: nrhs * ldx)
        yr.initialize(repeating: .nan, count: nrhs * ldy)
        yi.initialize(repeating: .nan, count: nrhs * ldy)
        for rhs in 0..<nrhs {
            for k in 0..<count {
                let real = Float64((17 * k + 7 * rhs + 3) % 31) / 15 - 1
                let imag = Float64((11 * k + 5 * rhs + 5) % 29) / 14 - 1
                x[rhs * count + k] = Complex128(real: real, imag: imag)
                xr[rhs * ldx + k] = real
                xi[rhs * ldx + k] = imag
            }
        }
        let dft = bdft_create(count)
        defer { dft_destroy(dft) }
        do {
            dft_forward(dft, .DFT_SCALE_ONE, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
            dft_forward(dft, .DFT_SCALE_ONE, nrhs,
                        xr, xi, ldx,
                        yr, yi, ldy,
                        .some(.init(w)))
            #expect((0..<nrhs).allSatisfy { rhs in
                (0..<count).allSatisfy { k in
                    let split = Complex128(real: yr[rhs * ldy + k], imag: yi[rhs * ldy + k])
                    return (split - y[rhs * count + k]).magnitudeSquared.isLess(than: .ulpOfOne)
                }
            })
        }
        do {
            dft_inverse(dft, .DFT_SCALE_ONE, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
            dft_inverse(dft, .DFT_SCALE_ONE, nrhs,
                        xr, xi, ldx,
                        yr, yi, ldy,
                        .some(.init(w)))
            #expect((0..<nrhs).allSatisfy { rhs in
                (0..<count).allSatisfy { k in
                    let split = Complex128(real: yr[rhs * ldy + k], imag: yi[rhs * ldy + k])
                    return (split - y[rhs * count + k]).magnitudeSquared.isLess(than: .ulpOfOne)
                }
            })
        }
    }
    // Measure prepare and operation
    @Test(
//        arguments: [1024, 1024 * 15, 5 * 7 * 11]
        arguments: [1024 * 7 * 5 * 3]
    )
    func compare_whole_time(count: Int) {
        let x = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:)).map(Complex128.init)
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: 3 * count)
        defer { y.deallocate() }
        let w = y.advanced(by: count)
        do {
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "dfs: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            let dft = ddft_create(count)
            defer { dft_destroy(dft) }
            dft_forward(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
        }
        do {
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "bfs: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            let dft = bdft_create(count)
            defer { dft_destroy(dft) }
            dft_forward(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
        }
        do {
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "jit: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            dft_forward(count,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
        }
    }
    // Measure operation only
    @Test(
        arguments: [16384, 1024 * 15, 5 * 7 * 11 * 13]
    )
    func compare_compute_time_vec(count: Int) {
        let x = repeatElement(-1.0 ... 1.0, count: count).map(Float64.random(in:)).map(Complex128.init)
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: 3 * count)
        defer { y.deallocate() }
        let w = y.advanced(by: count)
        do {
            let dft = ddft_create(count)
            defer { dft_destroy(dft) }
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "dfs: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            dft_forward(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
        }
        do {
            let dft = bdft_create(count)
            defer { dft_destroy(dft) }
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "bfs: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            dft_forward(dft, .DFT_SCALE_ONE,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
        }
        do {
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "jit: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            dft_forward(count,
                        .init(x), 1,
                        .init(y), 1,
                        .some(.init(w)))
        }
    }
    @Test(
        arguments: [1<<17,  3 * 5 * 7 * 1024, 5 * 7 * 11 * 13 * 17]
    )
    func compare_compute_time_mat(count: Int) {
        let nrhs = 11
        let x = repeatElement(-1.0 ... 1.0, count: count * nrhs).map(Float64.random(in:)).map(Complex128.init)
        let y = UnsafeMutablePointer<Complex128>.allocate(capacity: 3 * count * nrhs)
        defer { y.deallocate() }
        let w = y.advanced(by: count * nrhs)
        do {
            let dft = ddft_create(count)
            defer { dft_destroy(dft) }
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "dfs: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            dft_forward(dft, .DFT_SCALE_ONE, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
        }
        do {
            let dft = bdft_create(count)
            defer { dft_destroy(dft) }
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "bfs: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            dft_forward(dft, .DFT_SCALE_ONE, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
        }
        do {
            let s = CFAbsoluteTimeGetCurrent()
            defer {
                os_log(.debug, "jit: %lfs", CFAbsoluteTimeGetCurrent() - s)
            }
            dft_forward(count, nrhs,
                        .init(x), count,
                        .init(y), count,
                        .some(.init(w)))
        }
    }
}
