//
//  CTF.swift
//  MUTE
//
//  Created by Kota on 9/10/26.
//
import Testing
import typealias Numerics.Complex128
@testable import NSP

@Suite(.serialized)
struct CTFTestCases {
    private struct Generator {
        var state: UInt64 = 0x243f_6a88_85a3_08d3

        mutating func scalar() -> Float64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return 2 * Float64(state >> 11) / 9_007_199_254_740_992 - 1
        }

        mutating func complex() -> Complex128 {
            .init(real: scalar(), imag: scalar())
        }
    }

    @Test
    func rls() {
        let bins = 5
        let order = 3
        let frames = 4_096
        let object = ctf_create_rls(1, 1, bins, order)
        defer { ctf_destroy(object) }

        #expect(object.pointee.i == 1)
        #expect(object.pointee.o == 1)
        #expect(object.pointee.b == bins)
        #expect(object.pointee.order == order)
        #expect(object.pointee.dimension == order)

        ctf_rls_lambda(object, 0.995)

        let kernel = (0..<(bins * order)).map { index in
            let bin = index / order
            let lag = index % order
            let scale = 0.65 / Float64(lag + 1)
            return Complex128(
                real: scale * cos(Float64(bin + 1) * Float64(lag + 1)),
                imag: scale * sin(Float64(bin + 2) * Float64(lag + 1))
            )
        }

        var generator = Generator()
        let source = (0..<(frames * bins)).map { _ in generator.complex() }
        var target = Array(repeating: Complex128.zero, count: bins)
        var residual = Array(repeating: Complex128.zero, count: bins)

        for frame in 0..<frames {
            for bin in 0..<bins {
                target[bin] = (0..<order).reduce(into: Complex128.zero) { value, lag in
                    guard lag <= frame else { return }
                    value += kernel[bin * order + lag] * source[(frame - lag) * bins + bin]
                }
            }

            source.withUnsafeBufferPointer { source in
                target.withUnsafeBufferPointer { target in
                    residual.withUnsafeMutableBufferPointer { residual in
                        ctf_rls_update(
                            object,
                            frame % order,
                            .init(source.baseAddress.unsafelyUnwrapped.advanced(by: frame * bins)),
                            bins,
                            .init(target.baseAddress.unsafelyUnwrapped),
                            bins,
                            .init(residual.baseAddress.unsafelyUnwrapped),
                            bins
                        )
                    }
                }
            }
        }

        let estimate = UnsafeRawPointer(object.pointee.weight)
            .assumingMemoryBound(to: Complex128.self)
        for index in kernel.indices {
            #expect((estimate[index] - kernel[index]).magnitude < 1e-7)
        }
        #expect(residual.allSatisfy { $0.magnitude < 1e-7 })

        ctf_rls_reset(object, 1)
        #expect((0..<(bins * order)).allSatisfy { estimate[$0] == .zero })
    }
}
