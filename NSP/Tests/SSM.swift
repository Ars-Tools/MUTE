//
//  SSM.swift
//  MUTE
//
//  Created by Kota on 5/11/26.
//
import Testing
import simd
@testable import NSP
@Suite
struct SSMTestCases {
    @Test
    func lpf() {
        let object = ssm_filter_create(1, 1, 2)
        defer {
            ssm_filter_destroy(object)
        }
        ssm_filter_z_clear(object)
        let cutoff = 6000.0 as Float64
        let g = __tanpi(cutoff / 16000.0)
        let Δ = fma(g, g, g + 1)
        let A = [
            1 + g - g * g, 2 * g,
            -2 * g, 1 - g - g * g
        ]
        let B = [
            2 * g * g,
            2 * g
        ]
        let C = [
            1 + g, g
        ]
        let D = [
            g * g
        ]
        #expect(ssm_filter_set(object, .A, 0, 0, A[0] / Δ))
        #expect(ssm_filter_set(object, .A, 0, 1, A[1] / Δ))
        #expect(ssm_filter_set(object, .A, 1, 0, A[2] / Δ))
        #expect(ssm_filter_set(object, .A, 1, 1, A[3] / Δ))
        #expect(ssm_filter_set(object, .B, 0, 0, B[0] / Δ))
        #expect(ssm_filter_set(object, .B, 1, 0, B[1] / Δ))
        #expect(ssm_filter_set(object, .C, 0, 0, C[0] / Δ))
        #expect(ssm_filter_set(object, .C, 0, 1, C[1] / Δ))
        #expect(ssm_filter_set(object, .D, 0, 0, D[0] / Δ))
        let source = repeatElement(-1.0 ... 1.0, count: 1024).map(Float64.random(in:))
        let result = Array<Float64>(unsafeUninitializedCapacity: source.count) {
            ssm_filter(object, source, source.count, $0.baseAddress.unsafelyUnwrapped, $0.count, $0.count)
            $1 = $0.count
        }
        print(result)
    }
    @Test
    func hpf() {
        let object = ssm_filter_create(1, 1, 2)
        defer {
            ssm_filter_destroy(object)
        }
        ssm_filter_z_clear(object)
        let cutoff = 1000.0 as Float64
        let g = __tanpi(cutoff / 16000.0)
        let Δ = fma(g, g, g + 1)
        let A = [
            1 + g - g * g, 2 * g,
            -2 * g, 1 - g - g * g
        ]
        let B = [
            2 * g * g,
            2 * g
        ]
        let C = [
            -1, -1 - g
        ]
        let D = [
            1.0
        ]
        #expect(ssm_filter_set(object, .A, 0, 0, A[0] / Δ))
        #expect(ssm_filter_set(object, .A, 0, 1, A[1] / Δ))
        #expect(ssm_filter_set(object, .A, 1, 0, A[2] / Δ))
        #expect(ssm_filter_set(object, .A, 1, 1, A[3] / Δ))
        #expect(ssm_filter_set(object, .B, 0, 0, B[0] / Δ))
        #expect(ssm_filter_set(object, .B, 1, 0, B[1] / Δ))
        #expect(ssm_filter_set(object, .C, 0, 0, C[0] / Δ))
        #expect(ssm_filter_set(object, .C, 0, 1, C[1] / Δ))
        #expect(ssm_filter_set(object, .D, 0, 0, D[0] / Δ))
        let source = repeatElement(-1.0 ... 1.0, count: 1024).map(Float64.random(in:))
        let result = Array<Float64>(unsafeUninitializedCapacity: source.count) {
            ssm_filter(object, source, source.count, $0.baseAddress.unsafelyUnwrapped, $0.count, $0.count)
            $1 = $0.count
        }
        print(result)
    }
    @Test
    func bpf() {
        let object = ssm_filter_create(1, 1, 2)
        defer {
            ssm_filter_destroy(object)
        }
        ssm_filter_z_clear(object)
        let cutoff = 4000.0 as Float64
        let g = __tanpi(cutoff / 16000.0)
        let Δ = fma(g, g, g + 1)
        let A = [
            1 + g - g * g, 2 * g,
            -2 * g, 1 - g - g * g
        ]
        let B = [
            2 * g * g,
            2 * g
        ]
        let C = [
            -g, 1.0
        ]
        let D = [
            g
        ]
        #expect(ssm_filter_set(object, .A, 0, 0, A[0] / Δ))
        #expect(ssm_filter_set(object, .A, 0, 1, A[1] / Δ))
        #expect(ssm_filter_set(object, .A, 1, 0, A[2] / Δ))
        #expect(ssm_filter_set(object, .A, 1, 1, A[3] / Δ))
        #expect(ssm_filter_set(object, .B, 0, 0, B[0] / Δ))
        #expect(ssm_filter_set(object, .B, 1, 0, B[1] / Δ))
        #expect(ssm_filter_set(object, .C, 0, 0, C[0] / Δ))
        #expect(ssm_filter_set(object, .C, 0, 1, C[1] / Δ))
        #expect(ssm_filter_set(object, .D, 0, 0, D[0] / Δ))
        let source = repeatElement(-1.0 ... 1.0, count: 1024).map(Float64.random(in:))
        let result = Array<Float64>(unsafeUninitializedCapacity: source.count) {
            ssm_filter(object, source, source.count, $0.baseAddress.unsafelyUnwrapped, $0.count, $0.count)
            $1 = $0.count
        }
        print(result)
    }
}
