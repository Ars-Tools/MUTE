//
//  Filters.swift
//  MUTE
//
//  Created by Kota on 7/24/R7.
//
import Testing
import NSP
import simd

@Suite
struct FiltersTestCase {
    private let input = [
        0.25, -0.50, 0.75, 1.00, -0.20, 0.40, -0.90, 0.10,
        0.60, -0.30, 0.80, -0.70, 0.05, 0.35, -0.45, 0.95,
    ]

    private let staticB = [0.27, -0.11, 0.04]
    private let staticA = [1.20, -0.42, 0.15]

    private func activeCoefficients(count: Int) -> (b: [[Double]], a: [[Double]]) {
        let time = (0..<count).map(Double.init)
        return (
            b: [
                time.map { 0.22 + 0.0020 * $0 },
                time.map { -0.08 + 0.0010 * $0 },
                time.map { 0.03 - 0.0005 * $0 },
            ],
            a: [
                time.map { 1.10 + 0.0010 * $0 },
                time.map { -0.35 + 0.0020 * $0 },
                time.map { 0.09 - 0.0007 * $0 },
            ]
        )
    }

    /// Coefficients are coefficient-major. A row may contain one static value.
    private func reference(
        _ x: [Double],
        b: [[Double]],
        a: [[Double]]
    ) -> [Double] {
        func coefficient(_ row: [Double], _ time: Int) -> Double {
            row.count == 1 ? row[0] : row[time]
        }

        var y = Array(repeating: 0.0, count: x.count)
        for t in x.indices {
            var value = 0.0
            for j in b.indices where j <= t {
                value += coefficient(b[j], t) * x[t - j]
            }
            for j in a.indices.dropFirst() where j <= t {
                value -= coefficient(a[j], t) * y[t - j]
            }
            y[t] = value / coefficient(a[0], t)
        }
        return y
    }

    private func cascade(
        _ x: [Double],
        sections: [(b: [Double], a: [Double])]
    ) -> [Double] {
        sections.reduce(x) { signal, section in
            reference(signal,
                      b: section.b.map { [$0] },
                      a: section.a.map { [$0] })
        }
    }

    private func expectClose(
        _ actual: [Double],
        _ expected: [Double],
        tolerance: Double = 2e-12
    ) {
        #expect(actual.count == expected.count)
        for (lhs, rhs) in zip(actual, expected) {
            #expect(abs(lhs - rhs) <= tolerance * (1 + abs(rhs)))
        }
    }

    @Test
    func transversalTDFIIStaticMatchesDifferenceEquation() {
        let expected = reference(input,
                                 b: staticB.map { [$0] },
                                 a: staticA.map { [$0] })
        var output = Array(repeating: 0.0, count: input.count)
        var state = Array(repeating: 0.0, count: max(staticB.count, staticA.count))

        transversal_filter_static(staticB, staticB.count,
                                  staticA, staticA.count,
                                  input, &output, &state, input.count)

        expectClose(output, expected)
    }

    @Test
    func transversalSingleChannelStaticPreservesStateAndResets() {
        let object = transversal_filter_create(staticB.count, staticA.count)
        defer { transversal_filter_destroy(object) }

        let split = 7
        let firstInput = Array(input[..<split])
        let secondInput = Array(input[split...])
        var firstOutput = Array(repeating: 0.0, count: firstInput.count)
        var secondOutput = Array(repeating: 0.0, count: secondInput.count)

        transversal_filter_static(object, staticB, staticA,
                                  firstInput, &firstOutput, firstInput.count)
        transversal_filter_static(object, staticB, staticA,
                                  secondInput, &secondOutput, secondInput.count)

        let expected = reference(input,
                                 b: staticB.map { [$0] },
                                 a: staticA.map { [$0] })
        expectClose(firstOutput + secondOutput, expected)

        transversal_filter_reset(object)
        var resetOutput = Array(repeating: 0.0, count: input.count)
        transversal_filter_static(object, staticB, staticA,
                                  input, &resetOutput, input.count)
        expectClose(resetOutput, expected)
    }

    @Test
    func transversalSingleChannelActiveUsesCurrentCoefficientRows() {
        let coefficients = activeCoefficients(count: input.count)
        let object = transversal_filter_create(coefficients.b.count,
                                                coefficients.a.count)
        defer { transversal_filter_destroy(object) }
        var output = Array(repeating: 0.0, count: input.count)
        let b = coefficients.b.flatMap(\.self)
        let a = coefficients.a.flatMap(\.self)

        transversal_filter_active(object,
                                  b, input.count,
                                  a, input.count,
                                  input, &output, input.count)

        expectClose(output, reference(input, b: coefficients.b, a: coefficients.a))
    }

    @Test
    func transversalFilterbankStaticAndActiveKeepChannelsIndependent() {
        let channels = [
            input,
            input.enumerated().map { index, value in
                (index.isMultiple(of: 2) ? -0.75 : 0.50) * value + 0.03
            },
            input.enumerated().map { index, value in value + Double(index) * 0.01 },
        ]
        let channelCount = channels.count
        let length = input.count
        let x = channels.flatMap(\.self)
        let object = transversal_filter_create(staticB.count, staticA.count, channelCount)
        defer { transversal_filter_destroy(object) }

        var staticOutput = Array(repeating: 0.0, count: x.count)
        transversal_filter_static(object,
                                  staticB, staticA,
                                  x, length,
                                  &staticOutput, length,
                                  length)

        let staticExpected = channels.flatMap {
            reference($0,
                      b: staticB.map { [$0] },
                      a: staticA.map { [$0] })
        }
        expectClose(staticOutput, staticExpected)

        transversal_filter_reset(object)
        let coefficients = activeCoefficients(count: length)
        let b = coefficients.b.flatMap(\.self)
        let a = coefficients.a.flatMap(\.self)
        var activeOutput = Array(repeating: 0.0, count: x.count)
        transversal_filter_active(object,
                                  b, length,
                                  a, length,
                                  x, length,
                                  &activeOutput, length,
                                  length)

        let activeExpected = channels.flatMap {
            reference($0, b: coefficients.b, a: coefficients.a)
        }
        expectClose(activeOutput, activeExpected)
    }

    @Test
    func biquadUtilities() {
        let w = SIMD3<Double>(0.50, -0.25, 0.75)
        let power = biquad_power_coefficients(w)
        let delay = biquad_delay_coefficients(w)

        expectClose([power.x, power.y, power.z], [0.125, -0.625, 1.5])
        expectClose([delay.x, delay.y, delay.z], [0.8125, -0.6875, 0.75])
    }

    @Test
    func biquadStaticTDFIIAndDFIMatchDifferenceEquation() {
        let b = SIMD3<Double>(staticB)
        let a = SIMD3<Double>(staticA)
        let expected = reference(input,
                                 b: staticB.map { [$0] },
                                 a: staticA.map { [$0] })
        var tdfOutput = Array(repeating: 0.0, count: input.count)
        var dfOutput = Array(repeating: 0.0, count: input.count)
        var tdfState = SIMD2<Double>.zero
        var dfState = SIMD4<Double>.zero

        biquad_filter_convolve_static(b, a, input, &tdfOutput, &tdfState, input.count)
        biquad_filter_convolve_static(b, a, input, &dfOutput, &dfState, input.count)

        expectClose(tdfOutput, expected)
        expectClose(dfOutput, expected)
    }

    @Test
    func biquadStaticSOSMatchesCascadedDifferenceEquations() {
        let sections: [(b: [Double], a: [Double])] = [
            ([0.30, -0.12, 0.05], [1.10, -0.40, 0.13]),
            ([0.80,  0.07, 0.02], [0.95, -0.22, 0.06]),
        ]
        let b = sections.map { SIMD3<Double>($0.b) }
        let a = sections.map { SIMD3<Double>($0.a) }
        var state = Array(repeating: SIMD4<Double>.zero, count: sections.count)
        var output = Array(repeating: 0.0, count: input.count)

        biquad_filter_convolve_static(b, a, input, &output,
                                      &state, sections.count, input.count)

        expectClose(output, cascade(input, sections: sections))
    }

    @Test
    func biquadStaticRealRootPairsMatchExpandedSections() {
        let zeros = [
            SIMD2<Double>(0.20, -0.10),
            SIMD2<Double>(-0.40, 0.30),
        ]
        let poles = [
            SIMD2<Double>(0.55, 0.25),
            SIMD2<Double>(0.40, -0.20),
        ]
        let sections = zip(zeros, poles).map { zero, pole in
            (
                b: [1.0, -(zero.x + zero.y), zero.x * zero.y],
                a: [1.0, -(pole.x + pole.y), pole.x * pole.y]
            )
        }
        var state = Array(repeating: SIMD2<Double>.zero, count: sections.count)
        var output = Array(repeating: 0.0, count: input.count)

        biquad_filter_convolve_static(zeros, poles, input, &output,
                                      &state, sections.count, input.count)

        expectClose(output, cascade(input, sections: sections))
    }

    @Test
    func biquadActivePackedAndSplitFormsUseCurrentCoefficients() {
        let coefficients = activeCoefficients(count: input.count)
        let expected = reference(input, b: coefficients.b, a: coefficients.a)
        let b = coefficients.b.flatMap(\.self)
        let a = coefficients.a.flatMap(\.self)
        var packedOutput = Array(repeating: 0.0, count: input.count)
        var splitOutput = Array(repeating: 0.0, count: input.count)
        var packedState = SIMD4<Double>.zero
        var splitState = SIMD4<Double>.zero

        biquad_filter_convolve_active(b, input.count,
                                      a, input.count,
                                      input, &packedOutput,
                                      &packedState, input.count)
        biquad_filter_convolve_active(coefficients.b[0], coefficients.b[1], coefficients.b[2],
                                      coefficients.a[0], coefficients.a[1], coefficients.a[2],
                                      input, &splitOutput,
                                      &splitState, input.count)

        expectClose(packedOutput, expected)
        expectClose(splitOutput, expected)
    }

    @Test
    func biquadObjectKeepsChannelStateIndependentAndResets() {
        let channels = [
            input,
            input.enumerated().map { index, value in
                (index.isMultiple(of: 2) ? -0.60 : 0.85) * value
            },
        ]
        let length = input.count
        let coefficients = activeCoefficients(count: length)
        let b = coefficients.b.flatMap(\.self)
        let a = coefficients.a.flatMap(\.self)
        let x = channels.flatMap(\.self)
        let object = biquad_filter_create(channels.count)
        defer { biquad_filter_destroy(object) }
        var output = Array(repeating: 0.0, count: x.count)

        biquad_filter_active(object,
                             b, length,
                             a, length,
                             x, length,
                             &output, length,
                             length)

        let expected = channels.flatMap {
            reference($0, b: coefficients.b, a: coefficients.a)
        }
        expectClose(output, expected)

        biquad_filter_reset(object)
        var resetOutput = Array(repeating: 0.0, count: x.count)
        biquad_filter_active(object,
                             b, length,
                             a, length,
                             x, length,
                             &resetOutput, length,
                             length)
        expectClose(resetOutput, expected)
    }

    @Test
    func biquadFilterbankSharedSOSKeepsChannelsIndependent() {
        let sections: [(b: [Double], a: [Double])] = [
            ([0.30, -0.12, 0.05], [1.10, -0.40, 0.13]),
            ([0.80,  0.07, 0.02], [0.95, -0.22, 0.06]),
        ]
        let channels = [
            input,
            input.enumerated().map { index, value in
                value * (index.isMultiple(of: 2) ? 0.70 : -0.45) + 0.02
            },
        ]
        let length = input.count
        let sectionStride = length
        func rows(_ index: Int, numerator: Bool) -> [Double] {
            sections.flatMap { section in
                Array(repeating: numerator ? section.b[index] : section.a[index],
                      count: length)
            }
        }
        let channelStride = sections.count * sectionStride
        let strides = SIMD2<Int>(channelStride, sectionStride)
        func channelRows(_ index: Int, numerator: Bool) -> [Double] {
            Array(repeating: rows(index, numerator: numerator), count: channels.count)
                .flatMap(\.self)
        }
        let b0 = channelRows(0, numerator: true)
        let b1 = channelRows(1, numerator: true)
        let b2 = channelRows(2, numerator: true)
        let a0 = channelRows(0, numerator: false)
        let a1 = channelRows(1, numerator: false)
        let a2 = channelRows(2, numerator: false)
        let x = channels.flatMap(\.self)
        let object = biquad_filter_create(sections.count, channels.count)
        defer { biquad_filter_destroy(object) }
        var output = Array(repeating: 0.0, count: x.count)

        biquad_filter_active(object,
                             b0, strides,
                             b1, strides,
                             b2, strides,
                             a0, strides,
                             a1, strides,
                             a2, strides,
                             x, length,
                             &output, length,
                             length)

        let expected = channels.flatMap { cascade($0, sections: sections) }
        expectClose(output, expected)

        biquad_filter_reset(object)
        var resetOutput = Array(repeating: 0.0, count: x.count)
        biquad_filter_active(object,
                             b0, strides,
                             b1, strides,
                             b2, strides,
                             a0, strides,
                             a1, strides,
                             a2, strides,
                             x, length,
                             &resetOutput, length,
                             length)
        expectClose(resetOutput, expected)
    }

    @Test
    func biquadFilterbankPackedSOSUsesSectionParameterTimeLayout() {
        let sections: [(b: [Double], a: [Double])] = [
            ([0.30, -0.12, 0.05], [1.10, -0.40, 0.13]),
            ([0.80,  0.07, 0.02], [0.95, -0.22, 0.06]),
        ]
        let length = input.count
        let b = sections.flatMap { section in
            section.b.flatMap { Array(repeating: $0, count: length) }
        }
        let a = sections.flatMap { section in
            section.a.flatMap { Array(repeating: $0, count: length) }
        }
        let object = biquad_filter_create(sections.count, 1)
        defer { biquad_filter_destroy(object) }
        var output = Array(repeating: 0.0, count: length)

        biquad_filter_active(object,
                             b, length,
                             a, length,
                             input, length,
                             &output, length,
                             length)

        expectClose(output, cascade(input, sections: sections))
    }
}
