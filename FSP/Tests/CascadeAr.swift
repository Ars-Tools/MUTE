import Testing
import DSP
import CoreMedia
@testable import FSP

@Suite
struct CascadeArTestCase {
    @Test
    func coefficientsMatchLinearDesigns() throws {
        let interval = CMTime(value: 1, timescale: 48_000)
        let frequency = 4_800.0
        let normalized = frequency * interval.seconds
        let Q = 0.707
        let BW = 1.25
        let S = 0.8
        let dB = 7.5

        let designs: [(Filter.Cascade.Ar.Section, Linear.Biquad)] = [
            (.lpf(ω₀: frequency, Q: Q), .LPF(ω₀: normalized, Q: Q)),
            (.lpf(ω₀: frequency, BW: BW), .LPF(ω₀: normalized, BW: BW)),
            (.hpf(ω₀: frequency, Q: Q), .HPF(ω₀: normalized, Q: Q)),
            (.hpf(ω₀: frequency, BW: BW), .HPF(ω₀: normalized, BW: BW)),
            (.bpf(ω₀: frequency, Q: Q), .BPF(ω₀: normalized, Q: Q)),
            (.bpf(ω₀: frequency, BW: BW), .BPF(ω₀: normalized, BW: BW)),
            (.bsf(ω₀: frequency, Q: Q), .BSF(ω₀: normalized, Q: Q)),
            (.bsf(ω₀: frequency, BW: BW), .BSF(ω₀: normalized, BW: BW)),
            (.apf(ω₀: frequency, Q: Q), .APF(ω₀: normalized, Q: Q)),
            (.apf(ω₀: frequency, BW: BW), .APF(ω₀: normalized, BW: BW)),
            (.lsf(ω₀: frequency, Q: Q, dB: dB), .LSF(ω₀: normalized, Q: Q, dB: dB)),
            (.lsf(ω₀: frequency, BW: BW, dB: dB), .LSF(ω₀: normalized, BW: BW, dB: dB)),
            (.lsf(ω₀: frequency, S: S, dB: dB), .LSF(ω₀: normalized, S: S, dB: dB)),
            (.hsf(ω₀: frequency, Q: Q, dB: dB), .HSF(ω₀: normalized, Q: Q, dB: dB)),
            (.hsf(ω₀: frequency, BW: BW, dB: dB), .HSF(ω₀: normalized, BW: BW, dB: dB)),
            (.hsf(ω₀: frequency, S: S, dB: dB), .HSF(ω₀: normalized, S: S, dB: dB)),
            (.peq(ω₀: frequency, Q: Q, dB: dB), .PEQ(ω₀: normalized, Q: Q, dB: dB)),
            (.peq(ω₀: frequency, BW: BW, dB: dB), .PEQ(ω₀: normalized, BW: BW, dB: dB)),
            (.peq(ω₀: frequency, S: S, dB: dB), .PEQ(ω₀: normalized, S: S, dB: dB)),
        ]

        for (section, expected) in designs {
            var instance = Instance()
            let kernel = try section.closure(interval, 7, &instance)
            var target = Array(repeating: 0.0, count: 6 * 7)
            var workspace = Array(repeating: 0.0, count: 6 * 7)
            target.withUnsafeMutableBufferPointer { target in
                workspace.withUnsafeMutableBufferPointer { workspace in
                    kernel(.zero, 7, target.baseAddress.unsafelyUnwrapped, 7, workspace)
                }
            }
            let coefficients = [
                expected.b.x, expected.b.y, expected.b.z,
                expected.a.x, expected.a.y, expected.a.z,
            ]
            for channel in 0 ..< 6 {
                for sample in 0 ..< 7 {
                    #expect(abs(target[channel * 7 + sample] - coefficients[channel]) < 2e-13)
                }
            }
        }
    }
}
