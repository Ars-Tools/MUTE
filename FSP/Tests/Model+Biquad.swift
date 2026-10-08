import Testing
import func Darwin.pow
import KSP
@testable import FSP

@Suite
struct ModelBiquadTestCases {
    @Test
    func peqGain() {
        let object = Model.Biquad.PEQ(ω₀: 0.125, Q: 0.5.squareRoot(), dB: 12)
        // These properties report squared magnitude, including the peak at ω₀.
        #expect(abs(object.𝒢ₚ - pow(10, 1.2)) < 1e-10)
        #expect(abs(object.𝒢ₛ - 1) < 1e-10)
        #expect(object.𝒢ₘ.isFinite)
        #expect(object.𝒢ₛ <= object.𝒢ₘ && object.𝒢ₘ <= object.𝒢ₚ)
    }

    @Test
    func cascade() {
        let sections = [2.0, 4.0, 6.0].map {
            Model.Biquad.PEQ(ω₀: $0 / 16, Q: 6, dB: 12)
        }
        let count = 4096
        let input = [1.0] + Array(repeating: 0.0, count: count - 1)
        var output = input
        var state = Array<SIMD4<Float64>>(repeating: .zero, count: sections.count)
        biquad_filter_convolve_static(sections.map(\.b), sections.map(\.a),
                                     input, &output, &state, state.count, count)

        // Independent normalized difference equations for each section.
        var reference = input
        for section in sections {
            let b = section.b / section.a.x
            let a = section.a / section.a.x
            var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0
            reference = reference.map { x in
                let y = b.x * x + b.y * x1 + b.z * x2 - a.y * y1 - a.z * y2
                (x2, x1, y2, y1) = (x1, x, y1, y)
                return y
            }
        }
        #expect(output.allSatisfy { $0.isFinite })
        #expect(zip(output, reference).allSatisfy { abs($0 - $1) < 1e-10 })
    }
}
