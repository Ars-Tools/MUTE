//
//  Linear.swift
//  MUTE
//
//  Created by Kota on 9/3/26.
//
import Testing
import func Darwin.sin
import func Darwin.cos
import func Darwin.sqrt
import func Darwin.__exp10
@testable import typealias FSP.Linear
extension Float64 {
    @inlinable
    func isApprox(to target: Self, tolerance: Self = .ulpOfOne.squareRoot()) -> Bool {
        distance(to: target).isLess(than: tolerance)
    }
}
@Suite
struct LinearFilterTestCases {
    @usableFromInline
    static let ω₀Q = [
        (0.0, 0.5.squareRoot()), (0.1, 0.5.squareRoot()), (0.2, 0.5.squareRoot()), (0.4, 0.5.squareRoot()),
        (0.0, 1.0.squareRoot()), (0.1, 1.0.squareRoot()), (0.2, 1.0.squareRoot()), (0.4, 1.0.squareRoot()),
        (0.0, 2.0.squareRoot()), (0.1, 2.0.squareRoot()), (0.2, 2.0.squareRoot()), (0.4, 2.0.squareRoot()),
        (0.0, 4.0.squareRoot()), (0.1, 4.0.squareRoot()), (0.2, 4.0.squareRoot()), (0.4, 4.0.squareRoot()),
    ] as Array<(Float64, Float64)>
    @usableFromInline
    static let ω₀QdB = [
        (0.0, 0.5.squareRoot(), -6), (0.1, 0.5.squareRoot(), -6), (0.2, 0.5.squareRoot(), -6), (0.4, 0.5.squareRoot(), -6),
        (0.0, 1.0.squareRoot(), -6), (0.1, 1.0.squareRoot(), -6), (0.2, 1.0.squareRoot(), -6), (0.4, 1.0.squareRoot(), -6),
        (0.0, 2.0.squareRoot(), -6), (0.1, 2.0.squareRoot(), -6), (0.2, 2.0.squareRoot(), -6), (0.4, 2.0.squareRoot(), -6),
        (0.0, 4.0.squareRoot(), -6), (0.1, 4.0.squareRoot(), -6), (0.2, 4.0.squareRoot(), -6), (0.4, 4.0.squareRoot(), -6),
        (0.0, 0.5.squareRoot(),  0), (0.1, 0.5.squareRoot(),  0), (0.2, 0.5.squareRoot(),  0), (0.4, 0.5.squareRoot(),  0),
        (0.0, 1.0.squareRoot(),  0), (0.1, 1.0.squareRoot(),  0), (0.2, 1.0.squareRoot(),  0), (0.4, 1.0.squareRoot(),  0),
        (0.0, 2.0.squareRoot(),  0), (0.1, 2.0.squareRoot(),  0), (0.2, 2.0.squareRoot(),  0), (0.4, 2.0.squareRoot(),  0),
        (0.0, 4.0.squareRoot(),  0), (0.1, 4.0.squareRoot(),  0), (0.2, 4.0.squareRoot(),  0), (0.4, 4.0.squareRoot(),  0),
        (0.0, 0.5.squareRoot(),  6), (0.1, 0.5.squareRoot(),  6), (0.2, 0.5.squareRoot(),  6), (0.4, 0.5.squareRoot(),  6),
        (0.0, 1.0.squareRoot(),  6), (0.1, 1.0.squareRoot(),  6), (0.2, 1.0.squareRoot(),  6), (0.4, 1.0.squareRoot(),  6),
        (0.0, 2.0.squareRoot(),  6), (0.1, 2.0.squareRoot(),  6), (0.2, 2.0.squareRoot(),  6), (0.4, 2.0.squareRoot(),  6),
        (0.0, 4.0.squareRoot(),  6), (0.1, 4.0.squareRoot(),  6), (0.2, 4.0.squareRoot(),  6), (0.4, 4.0.squareRoot(),  6),
    ] as Array<(Float64, Float64, Float64)>
    @Test(
        arguments: ω₀Q
    )
    func BiquadBPF(ω₀: Float64, Q: Float64) {
        let filter = Linear.Biquad.BPF(ω₀: ω₀, Q: Q)
        #expect(filter.b.x.isApprox(to:  0.5 * sin(2.0 * .pi * ω₀) / Q))
        #expect(filter.b.y.isApprox(to:  0))
        #expect(filter.b.z.isApprox(to: -0.5 * sin(2.0 * .pi * ω₀) / Q))
        #expect(filter.a.x.isApprox(to: 1 + 0.5 * sin(2.0 * .pi * ω₀) / Q))
        #expect(filter.a.y.isApprox(to: 0 - 2.0 * cos(2.0 * .pi * ω₀)))
        #expect(filter.a.z.isApprox(to: 1 - 0.5 * sin(2.0 * .pi * ω₀) / Q))
    }
    @Test(
        arguments: ω₀Q
    )
    func BiquadLPF(ω₀: Float64, Q: Float64) {
        let filter = Linear.Biquad.LPF(ω₀: ω₀, Q: Q)
        #expect(filter.b.x.isApprox(to: 0.5 - 0.5 * cos(2.0 * .pi * ω₀)))
        #expect(filter.b.y.isApprox(to: 1.0 - 1.0 * cos(2.0 * .pi * ω₀)))
        #expect(filter.b.z.isApprox(to: 0.5 - 0.5 * cos(2.0 * .pi * ω₀)))
        #expect(filter.a.x.isApprox(to: 1 + 0.5 * sin(2.0 * .pi * ω₀) / Q))
        #expect(filter.a.y.isApprox(to: 0 - 2.0 * cos(2.0 * .pi * ω₀)))
        #expect(filter.a.z.isApprox(to: 1 - 0.5 * sin(2.0 * .pi * ω₀) / Q))
    }
    @Test(
        arguments: ω₀Q
    )
    func BiquadHPF(ω₀: Float64, Q: Float64) {
        let filter = Linear.Biquad.HPF(ω₀: ω₀, Q: Q)
        #expect(filter.b.x.isApprox(to: 0.5 + 0.5 * cos(2.0 * .pi * ω₀)))
        #expect(filter.b.y.isApprox(to: -(1 + cos(2.0 * .pi * ω₀))))
        #expect(filter.b.z.isApprox(to: 0.5 + 0.5 * cos(2.0 * .pi * ω₀)))
        #expect(filter.a.x.isApprox(to: 1 + 0.5 * sin(2.0 * .pi * ω₀) / Q))
        #expect(filter.a.y.isApprox(to: 0 - 2.0 * cos(2.0 * .pi * ω₀)))
        #expect(filter.a.z.isApprox(to: 1 - 0.5 * sin(2.0 * .pi * ω₀) / Q))
    }
    @Test(
        arguments: ω₀Q
    )
    func BiquadAPF(ω₀: Float64, Q: Float64) {
        let filter = Linear.Biquad.APF(ω₀: ω₀, Q: Q)
        #expect(filter.b.x.isApprox(to: 1 - 0.5 * sin(2.0 * .pi * ω₀) / Q))
        #expect(filter.b.y.isApprox(to: 0 - 2.0 * cos(2.0 * .pi * ω₀)))
        #expect(filter.b.z.isApprox(to: 1 + 0.5 * sin(2.0 * .pi * ω₀) / Q))
        #expect(filter.a.x.isApprox(to: 1 + 0.5 * sin(2.0 * .pi * ω₀) / Q))
        #expect(filter.a.y.isApprox(to: 0 - 2.0 * cos(2.0 * .pi * ω₀)))
        #expect(filter.a.z.isApprox(to: 1 - 0.5 * sin(2.0 * .pi * ω₀) / Q))
    }
    @Test(
        arguments: ω₀Q
    )
    func BiquadBSF(ω₀: Float64, Q: Float64) {
        let filter = Linear.Biquad.BSF(ω₀: ω₀, Q: Q)
        #expect(filter.b.x.isApprox(to: 1))
        #expect(filter.b.y.isApprox(to: 0 - 2.0 * cos(2.0 * .pi * ω₀)))
        #expect(filter.b.z.isApprox(to: 1))
        #expect(filter.a.x.isApprox(to: 1 + 0.5 * sin(2.0 * .pi * ω₀) / Q))
        #expect(filter.a.y.isApprox(to: 0 - 2.0 * cos(2.0 * .pi * ω₀)))
        #expect(filter.a.z.isApprox(to: 1 - 0.5 * sin(2.0 * .pi * ω₀) / Q))
    }
    @Test(
        arguments: ω₀QdB
    )
    func BiquadLSF(ω₀: Float64, Q: Float64, dB: Float64) {
        let filter = Linear.Biquad.LSF(ω₀: ω₀, Q: Q, dB: dB)
        let A = __exp10(dB / 40.0)
        #expect(filter.b.x.isApprox(to:  0.5 * A * ((A+1) - (A-1) * cos(2.0 * .pi * ω₀) + 2.0 * sqrt(A) * 0.5 * sin(2.0 * .pi * ω₀) / Q)))
        #expect(filter.b.y.isApprox(to:  1.0 * A * ((A-1) - (A+1) * cos(2.0 * .pi * ω₀))))
        #expect(filter.b.z.isApprox(to:  0.5 * A * ((A+1) - (A-1) * cos(2.0 * .pi * ω₀) - 2.0 * sqrt(A) * 0.5 * sin(2.0 * .pi * ω₀) / Q)))
        #expect(filter.a.x.isApprox(to:  0.5     * ((A+1) + (A-1) * cos(2.0 * .pi * ω₀) + 2.0 * sqrt(A) * 0.5 * sin(2.0 * .pi * ω₀) / Q)))
        #expect(filter.a.y.isApprox(to: -1.0     * ((A-1) + (A+1) * cos(2.0 * .pi * ω₀))))
        #expect(filter.a.z.isApprox(to:  0.5     * ((A+1) + (A-1) * cos(2.0 * .pi * ω₀) - 2.0 * sqrt(A) * 0.5 * sin(2.0 * .pi * ω₀) / Q)))
    }
    @Test(
        arguments: ω₀QdB
    )
    func BiquadHSF(ω₀: Float64, Q: Float64, dB: Float64) {
        let filter = Linear.Biquad.HSF(ω₀: ω₀, Q: Q, dB: dB)
        let A = __exp10(dB / 40.0)
        #expect(filter.b.x.isApprox(to:  0.5 * A * ((A+1) + (A-1) * cos(2.0 * .pi * ω₀) + 2.0 * sqrt(A) * 0.5 * sin(2.0 * .pi * ω₀) / Q)))
        #expect(filter.b.y.isApprox(to: -1.0 * A * ((A-1) + (A+1) * cos(2.0 * .pi * ω₀))))
        #expect(filter.b.z.isApprox(to:  0.5 * A * ((A+1) + (A-1) * cos(2.0 * .pi * ω₀) - 2.0 * sqrt(A) * 0.5 * sin(2.0 * .pi * ω₀) / Q)))
        #expect(filter.a.x.isApprox(to:  0.5     * ((A+1) - (A-1) * cos(2.0 * .pi * ω₀) + 2.0 * sqrt(A) * 0.5 * sin(2.0 * .pi * ω₀) / Q)))
        #expect(filter.a.y.isApprox(to:  1.0     * ((A-1) - (A+1) * cos(2.0 * .pi * ω₀))))
        #expect(filter.a.z.isApprox(to:  0.5     * ((A+1) - (A-1) * cos(2.0 * .pi * ω₀) - 2.0 * sqrt(A) * 0.5 * sin(2.0 * .pi * ω₀) / Q)))
    }
    @Test(
        arguments: ω₀QdB
    )
    func BiquadPEQ(ω₀: Float64, Q: Float64, dB: Float64) {
        let filter = Linear.Biquad.PEQ(ω₀: ω₀, Q: Q, dB: dB)
        let A = __exp10(dB / 40.0)
        #expect(filter.b.x.isApprox(to: 1 + 0.5 * sin(2.0 * .pi * ω₀) / Q * A))
        #expect(filter.b.y.isApprox(to: -2.0 * cos(2.0 * .pi * ω₀)))
        #expect(filter.b.z.isApprox(to: 1 - 0.5 * sin(2.0 * .pi * ω₀) / Q * A))
        #expect(filter.a.x.isApprox(to: 1 + 0.5 * sin(2.0 * .pi * ω₀) / Q / A))
        #expect(filter.a.y.isApprox(to: -2.0 * cos(2.0 * .pi * ω₀)))
        #expect(filter.a.z.isApprox(to: 1 - 0.5 * sin(2.0 * .pi * ω₀) / Q / A))
    }
}
