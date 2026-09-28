//
//  Special+Cascade+Ar.swift
//  MUTE
//
//  Audio-rate biquad coefficient design.
//
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import protocol DSP.Stream
import typealias DSP.Filter
import func DSP.const
import typealias CLK.CMTime
import func Darwin.log2
import let Darwin.M_LN2
import let Darwin.M_LN10

private let _cascadeHalfAngleScale = Float64.pi
private let _cascadeBandwidth = 0.5 * Float64(M_LN2)
private let _cascadeGain = 0.025 * Float64(M_LN10)
private let _cascadeGain2 = Float64(log2(10.0)) / 40.0

private typealias _CascadeStreamKernel = @Sendable (
    CMTime, Int, UnsafeMutablePointer<Float64>, Int
) -> Void

@inline(__always)@_transparent
private func _cascadeBuffer(
    _ base: UnsafeMutablePointer<Float64>,
    _ channel: Int,
    _ stride: Int,
    _ length: Int
) -> UnsafeMutableBufferPointer<Float64> {
    .init(start: base.advanced(by: channel * stride), count: length)
}

@inline(__always)@_transparent
private func _cascadeCopy(
    _ source: UnsafeMutableBufferPointer<Float64>,
    _ target: UnsafeMutableBufferPointer<Float64>
) {
    switch target.initialize(fromContentsOf: source) {
    case let eof:
        assert(target.startIndex.distance(to: eof) == source.count)
    }
//    target.baseAddress.unsafelyUnwrapped.update(
//        from: source.baseAddress.unsafelyUnwrapped,
//        count: source.count
//    )
}

private struct _CascadeWorkspace {
    var x0: UnsafeMutableBufferPointer<Float64>
    var x1: UnsafeMutableBufferPointer<Float64>
    var x2: UnsafeMutableBufferPointer<Float64>
    var x3: UnsafeMutableBufferPointer<Float64>
    var x4: UnsafeMutableBufferPointer<Float64>
    var x5: UnsafeMutableBufferPointer<Float64>

    @inline(__always)
    init(_ workspace: UnsafeMutableBufferPointer<Float64>, length: Int) {
        x0 = .init(rebasing: workspace[0 * length ..< 1 * length])
        x1 = .init(rebasing: workspace[1 * length ..< 2 * length])
        x2 = .init(rebasing: workspace[2 * length ..< 3 * length])
        x3 = .init(rebasing: workspace[3 * length ..< 4 * length])
        x4 = .init(rebasing: workspace[4 * length ..< 5 * length])
        x5 = .init(rebasing: workspace[5 * length ..< 6 * length])
    }
}

private struct _CascadeCoefficients {
    var b0: UnsafeMutableBufferPointer<Float64>
    var b1: UnsafeMutableBufferPointer<Float64>
    var b2: UnsafeMutableBufferPointer<Float64>
    var a0: UnsafeMutableBufferPointer<Float64>
    var a1: UnsafeMutableBufferPointer<Float64>
    var a2: UnsafeMutableBufferPointer<Float64>

    @inline(__always)
    init(_ target: UnsafeMutablePointer<Float64>, stride: Int, length: Int) {
        b0 = _cascadeBuffer(target, 0, stride, length)
        b1 = _cascadeBuffer(target, 1, stride, length)
        b2 = _cascadeBuffer(target, 2, stride, length)
        a0 = _cascadeBuffer(target, 3, stride, length)
        a1 = _cascadeBuffer(target, 4, stride, length)
        a2 = _cascadeBuffer(target, 5, stride, length)
    }
}

@inline(__always)
private func _cascadeHalfAngle(
    _ kernel: _CascadeStreamKernel,
    moment: CMTime,
    length: Int,
    factor: Float64,
    workspace: inout _CascadeWorkspace
) {
    kernel(moment, length, workspace.x0.baseAddress.unsafelyUnwrapped, length)
    vDSP.multiply(factor, workspace.x0, result: &workspace.x0)
    vForce.sincos(workspace.x0, sinResult: &workspace.x1, cosResult: &workspace.x2)
}

@inline(__always)
private func _cascadeQualityAlpha(
    _ kernel: _CascadeStreamKernel,
    moment: CMTime,
    length: Int,
    workspace: inout _CascadeWorkspace
) {
    kernel(moment, length, workspace.x0.baseAddress.unsafelyUnwrapped, length)
    vDSP.divide(workspace.x2, workspace.x0, result: &workspace.x0)
    vDSP.multiply(workspace.x1, workspace.x0, result: &workspace.x3)
}

@inline(__always)
private func _cascadeBandwidthAlpha(
    _ kernel: _CascadeStreamKernel,
    moment: CMTime,
    length: Int,
    workspace: inout _CascadeWorkspace
) {
    // sinc(2θ) = sin(2θ)/(2θ) = sin(θ)cos(θ)/θ.
    vDSP.multiply(workspace.x1, workspace.x2, result: &workspace.x3)
    kernel(moment, length, workspace.x4.baseAddress.unsafelyUnwrapped, length)
    vDSP.multiply(_cascadeBandwidth, workspace.x4, result: &workspace.x4)
    vDSP.multiply(workspace.x0, workspace.x4, result: &workspace.x4)
    vDSP.divide(workspace.x4, workspace.x3, result: &workspace.x4)
    vForce.sinh(workspace.x4, result: &workspace.x4)
    vDSP.multiply(workspace.x3, workspace.x4, result: &workspace.x3)
    vDSP.multiply(2, workspace.x3, result: &workspace.x3)
}

private protocol _CascadePassWidthPlan: Sendable {
    static func alpha(
        _ kernel: _CascadeStreamKernel,
        moment: CMTime,
        length: Int,
        workspace: inout _CascadeWorkspace
    )
}

private enum _CascadeQualityPassWidth: _CascadePassWidthPlan {
    @inline(__always)@_transparent
    static func alpha(_ kernel: _CascadeStreamKernel, moment: CMTime, length: Int, workspace: inout _CascadeWorkspace) {
        _cascadeQualityAlpha(kernel, moment: moment, length: length, workspace: &workspace)
    }
}

private enum _CascadeBandwidthPassWidth: _CascadePassWidthPlan {
    @inline(__always)@_transparent
    static func alpha(_ kernel: _CascadeStreamKernel, moment: CMTime, length: Int, workspace: inout _CascadeWorkspace) {
        _cascadeBandwidthAlpha(kernel, moment: moment, length: length, workspace: &workspace)
    }
}

private protocol _CascadePassPlan: Sendable {
    static func numerator(workspace: inout _CascadeWorkspace, coefficients: inout _CascadeCoefficients)
}

private enum _CascadeLowPass: _CascadePassPlan {
    @inline(__always)@_transparent
    static func numerator(workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        vDSP.multiply(w.x1, w.x1, result: &z.b0)
        vDSP.multiply(2, z.b0, result: &z.b1)
        _cascadeCopy(z.b0, z.b2)
        vDSP.add(multiplication: (z.b0, 4), -2, result: &z.a1)
    }
}

private enum _CascadeHighPass: _CascadePassPlan {
    @inline(__always)@_transparent
    static func numerator(workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        vDSP.multiply(w.x2, w.x2, result: &z.b0)
        vDSP.multiply(-2, z.b0, result: &z.b1)
        _cascadeCopy(z.b0, z.b2)
        vDSP.multiply(w.x1, w.x1, result: &w.x4)
        vDSP.add(multiplication: (w.x4, 4), -2, result: &z.a1)
    }
}

private enum _CascadeBandPass: _CascadePassPlan {
    @inline(__always)
    static func numerator(workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        _cascadeCopy(w.x3, z.b0)
        vDSP.clear(&z.b1)
        vDSP.negative(w.x3, result: &z.b2)
        vDSP.multiply(w.x1, w.x1, result: &w.x4)
        vDSP.add(multiplication: (w.x4, 4), -2, result: &z.a1)
    }
}

private enum _CascadeBandStop: _CascadePassPlan {
    @inline(__always)
    static func numerator(workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        vDSP.fill(&z.b0, with: 1)
        vDSP.fill(&z.b2, with: 1)
        vDSP.multiply(w.x1, w.x1, result: &w.x4)
        vDSP.add(multiplication: (w.x4, 4), -2, result: &z.a1)
        _cascadeCopy(z.a1, z.b1)
    }
}

private enum _CascadeAllPass: _CascadePassPlan {
    @inline(__always)
    static func numerator(workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        vDSP.multiply(w.x1, w.x1, result: &w.x4)
        vDSP.add(multiplication: (w.x4, 4), -2, result: &z.a1)
        _cascadeCopy(z.a2, z.b0)
        _cascadeCopy(z.a1, z.b1)
        _cascadeCopy(z.a0, z.b2)
    }
}

@inline(__always)
private func _cascadeDenominator(workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
    vDSP.fill(&w.x5, with: 1)
    vDSP.addSubtract(w.x5, w.x3, addResult: &z.a0, subtractResult: &z.a2)
}

private protocol _CascadeShelfWidthPlan: Sendable {
    static func resonance(
        _ kernel: _CascadeStreamKernel,
        moment: CMTime,
        length: Int,
        workspace: inout _CascadeWorkspace,
        coefficients: inout _CascadeCoefficients
    )
}

private enum _CascadeQualityShelfWidth: _CascadeShelfWidthPlan {
    @inline(__always)
    static func resonance(_ kernel: _CascadeStreamKernel, moment: CMTime, length: Int, workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        kernel(moment, length, z.a0.baseAddress.unsafelyUnwrapped, length)
        vForce.sqrt(w.x5, result: &z.b2)
        vDSP.divide(z.b2, z.a0, result: &z.b2)
        vDSP.multiply(w.x2, z.b2, result: &z.b2)
        vDSP.multiply(w.x1, z.b2, result: &z.a2)
    }
}

private enum _CascadeBandwidthShelfWidth: _CascadeShelfWidthPlan {
    @inline(__always)
    static func resonance(_ kernel: _CascadeStreamKernel, moment: CMTime, length: Int, workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        vDSP.multiply(w.x1, w.x2, result: &z.a2)
        kernel(moment, length, z.a0.baseAddress.unsafelyUnwrapped, length)
        vDSP.multiply(_cascadeBandwidth, z.a0, result: &z.a0)
        vDSP.multiply(w.x0, z.a0, result: &z.a0)
        vDSP.divide(z.a0, z.a2, result: &z.a0)
        vForce.sinh(z.a0, result: &z.a0)
        vDSP.multiply(2, z.a0, result: &z.a0)
        vForce.sqrt(w.x5, result: &z.b2)
        vDSP.multiply(z.b2, z.a0, result: &z.a0)
        vDSP.multiply(z.a2, z.a0, result: &z.a2)
    }
}

private enum _CascadeSlopeShelfWidth: _CascadeShelfWidthPlan {
    @inline(__always)
    static func resonance(_ kernel: _CascadeStreamKernel, moment: CMTime, length: Int, workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        kernel(moment, length, z.a0.baseAddress.unsafelyUnwrapped, length)
        vDSP.divide(1, z.a0, result: &z.a0)
        vDSP.add(-1, z.a0, result: &z.a0)
        vDSP.add(multiplication: (w.x5, w.x5), 1, result: &z.b2)
        vDSP.multiply(z.b2, z.a0, result: &z.b2)
        vDSP.add(multiplication: (w.x5, 2), z.b2, result: &z.b2)
        vForce.sqrt(z.b2, result: &z.b2)
        vDSP.multiply(w.x1, w.x2, result: &z.a2)
        vDSP.multiply(z.a2, z.b2, result: &z.a2)
    }
}

private protocol _CascadeShelfPlan: Sendable {
    static func coefficients(workspace: inout _CascadeWorkspace, coefficients: inout _CascadeCoefficients)
}

private enum _CascadeLowShelf: _CascadeShelfPlan {
    @inline(__always)
    static func coefficients(workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        _cascadeCopy(z.a2, w.x0)
        vDSP.multiply(w.x4, w.x3, result: &z.b2)
        vDSP.add(1, z.b2, result: &w.x1)
        vDSP.add(multiplication: (z.b2, -1), w.x5, result: &w.x2)
        vDSP.add(1, w.x5, result: &z.b2)
        vDSP.add(multiplication: (z.b2, w.x3), -1, result: &z.b1)
        vDSP.multiply(z.b2, w.x3, result: &z.a1)
        vDSP.add(multiplication: (z.a1, -1), w.x5, result: &z.a1)
        vDSP.multiply(2, z.b1, result: &z.b1)
        vDSP.multiply(-2, z.a1, result: &z.a1)
        vDSP.addSubtract(w.x1, w.x0, addResult: &z.b0, subtractResult: &z.b2)
        vDSP.addSubtract(w.x2, w.x0, addResult: &z.a0, subtractResult: &z.a2)
        vDSP.multiply(w.x5, z.b0, result: &z.b0)
        vDSP.multiply(w.x5, z.b1, result: &z.b1)
        vDSP.multiply(w.x5, z.b2, result: &z.b2)
    }
}

private enum _CascadeHighShelf: _CascadeShelfPlan {
    @inline(__always)
    static func coefficients(workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        _cascadeCopy(z.a2, w.x0)
        vDSP.multiply(w.x4, w.x3, result: &z.b2)
        vDSP.add(multiplication: (z.b2, -1), w.x5, result: &w.x1)
        vDSP.add(1, z.b2, result: &w.x2)
        vDSP.add(1, w.x5, result: &z.b2)
        vDSP.multiply(z.b2, w.x3, result: &z.b1)
        vDSP.add(multiplication: (z.b1, -1), w.x5, result: &z.b1)
        vDSP.add(multiplication: (z.b2, w.x3), -1, result: &z.a1)
        vDSP.multiply(-2, z.b1, result: &z.b1)
        vDSP.multiply(2, z.a1, result: &z.a1)
        vDSP.addSubtract(w.x1, w.x0, addResult: &z.b0, subtractResult: &z.b2)
        vDSP.addSubtract(w.x2, w.x0, addResult: &z.a0, subtractResult: &z.a2)
        vDSP.multiply(w.x5, z.b0, result: &z.b0)
        vDSP.multiply(w.x5, z.b1, result: &z.b1)
        vDSP.multiply(w.x5, z.b2, result: &z.b2)
    }
}

private protocol _CascadeEqualizerWidthPlan: Sendable {
    static func alpha(
        _ kernel: _CascadeStreamKernel,
        moment: CMTime,
        length: Int,
        workspace: inout _CascadeWorkspace,
        coefficients: inout _CascadeCoefficients
    )
}

private enum _CascadeQualityEqualizerWidth: _CascadeEqualizerWidthPlan {
    @inline(__always)
    static func alpha(_ kernel: _CascadeStreamKernel, moment: CMTime, length: Int, workspace: inout _CascadeWorkspace, coefficients: inout _CascadeCoefficients) {
        _cascadeQualityAlpha(kernel, moment: moment, length: length, workspace: &workspace)
    }
}

private enum _CascadeBandwidthEqualizerWidth: _CascadeEqualizerWidthPlan {
    @inline(__always)
    static func alpha(_ kernel: _CascadeStreamKernel, moment: CMTime, length: Int, workspace: inout _CascadeWorkspace, coefficients: inout _CascadeCoefficients) {
        _cascadeBandwidthAlpha(kernel, moment: moment, length: length, workspace: &workspace)
    }
}

private enum _CascadeSlopeEqualizerWidth: _CascadeEqualizerWidthPlan {
    @inline(__always)
    static func alpha(_ kernel: _CascadeStreamKernel, moment: CMTime, length: Int, workspace w: inout _CascadeWorkspace, coefficients z: inout _CascadeCoefficients) {
        kernel(moment, length, w.x4.baseAddress.unsafelyUnwrapped, length)
        vDSP.divide(1, w.x4, result: &w.x4)
        vDSP.add(-1, w.x4, result: &w.x4)
        vDSP.divide(1, w.x5, result: &z.b0)
        vDSP.add(w.x5, z.b0, result: &z.b0)
        vDSP.multiply(z.b0, w.x4, result: &z.b0)
        vDSP.add(2, z.b0, result: &z.b0)
        vForce.sqrt(z.b0, result: &z.b0)
        vDSP.multiply(w.x1, w.x2, result: &w.x3)
        vDSP.multiply(w.x3, z.b0, result: &w.x3)
    }
}

extension Filter.Cascade.Ar.Section {
    @inline(__always)
    private static func pass<P: _CascadePassPlan, W: _CascadePassWidthPlan>(
        _: P.Type,
        _: W.Type,
        ω₀: Stream,
        width: Stream
    ) -> Self {
        .init { interval, capacity, instance in
            guard ω₀.count == 1, width.count == 1 else {
                throw Error.unmatchChannel
            }
            let ω₀k = try ω₀(interval: interval, capacity: capacity, instance: &instance)
            let widthk = try width(interval: interval, capacity: capacity, instance: &instance)
            let factor = _cascadeHalfAngleScale * interval.seconds
            return { moment, length, target, stride, workspace in
                var w = _CascadeWorkspace(workspace, length: length)
                var z = _CascadeCoefficients(target, stride: stride, length: length)
                _cascadeHalfAngle(ω₀k, moment: moment, length: length, factor: factor, workspace: &w)
                W.alpha(widthk, moment: moment, length: length, workspace: &w)
                _cascadeDenominator(workspace: &w, coefficients: &z)
                P.numerator(workspace: &w, coefficients: &z)
            }
        }
    }

    @inline(__always)
    private static func shelf<P: _CascadeShelfPlan, W: _CascadeShelfWidthPlan>(
        _: P.Type,
        _: W.Type,
        ω₀: Stream,
        width: Stream,
        dB: Stream
    ) -> Self {
        .init { interval, capacity, instance in
            guard ω₀.count == 1, width.count == 1, dB.count == 1 else {
                throw Error.unmatchChannel
            }
            let ω₀k = try ω₀(interval: interval, capacity: capacity, instance: &instance)
            let widthk = try width(interval: interval, capacity: capacity, instance: &instance)
            let dBk = try dB(interval: interval, capacity: capacity, instance: &instance)
            let factor = _cascadeHalfAngleScale * interval.seconds
            return { moment, length, target, stride, workspace in
                var w = _CascadeWorkspace(workspace, length: length)
                var z = _CascadeCoefficients(target, stride: stride, length: length)
                _cascadeHalfAngle(ω₀k, moment: moment, length: length, factor: factor, workspace: &w)
                vDSP.multiply(w.x1, w.x1, result: &w.x3)
                dBk(moment, length, w.x4.baseAddress.unsafelyUnwrapped, length)
                vDSP.multiply(_cascadeGain, w.x4, result: &w.x4)
                vForce.expm1(w.x4, result: &w.x4)
                vDSP.add(1, w.x4, result: &w.x5)
                W.resonance(widthk, moment: moment, length: length, workspace: &w, coefficients: &z)
                P.coefficients(workspace: &w, coefficients: &z)
            }
        }
    }

    @inline(__always)
    private static func equalizer<W: _CascadeEqualizerWidthPlan>(
        _: W.Type,
        ω₀: Stream,
        width: Stream,
        dB: Stream
    ) -> Self {
        .init { interval, capacity, instance in
            guard ω₀.count == 1, width.count == 1, dB.count == 1 else {
                throw Error.unmatchChannel
            }
            let ω₀k = try ω₀(interval: interval, capacity: capacity, instance: &instance)
            let widthk = try width(interval: interval, capacity: capacity, instance: &instance)
            let dBk = try dB(interval: interval, capacity: capacity, instance: &instance)
            let factor = _cascadeHalfAngleScale * interval.seconds
            return { moment, length, target, stride, workspace in
                var w = _CascadeWorkspace(workspace, length: length)
                var z = _CascadeCoefficients(target, stride: stride, length: length)
                _cascadeHalfAngle(ω₀k, moment: moment, length: length, factor: factor, workspace: &w)
                dBk(moment, length, w.x5.baseAddress.unsafelyUnwrapped, length)
                vDSP.multiply(_cascadeGain2, w.x5, result: &w.x5)
                vForce.exp2(w.x5, result: &w.x5)
                W.alpha(widthk, moment: moment, length: length, workspace: &w, coefficients: &z)
                vDSP.fill(&z.b1, with: 1)
                vDSP.multiply(w.x3, w.x5, result: &w.x4)
                vDSP.addSubtract(z.b1, w.x4, addResult: &z.b0, subtractResult: &z.b2)
                vDSP.divide(w.x3, w.x5, result: &w.x4)
                vDSP.addSubtract(z.b1, w.x4, addResult: &z.a0, subtractResult: &z.a2)
                vDSP.multiply(w.x1, w.x1, result: &w.x4)
                vDSP.add(multiplication: (w.x4, 4), -2, result: &z.a1)
                _cascadeCopy(z.a1, z.b1)
            }
        }
    }
}

// MARK: - LPF / HPF / BPF / BSF / APF
extension Filter.Cascade.Ar.Section {
    public static func lpf(ω₀: Stream, Q: Stream) -> Self { pass(_CascadeLowPass.self, _CascadeQualityPassWidth.self, ω₀: ω₀, width: Q) }
    public static func lpf(ω₀: Stream, BW: Stream) -> Self { pass(_CascadeLowPass.self, _CascadeBandwidthPassWidth.self, ω₀: ω₀, width: BW) }
    public static func hpf(ω₀: Stream, Q: Stream) -> Self { pass(_CascadeHighPass.self, _CascadeQualityPassWidth.self, ω₀: ω₀, width: Q) }
    public static func hpf(ω₀: Stream, BW: Stream) -> Self { pass(_CascadeHighPass.self, _CascadeBandwidthPassWidth.self, ω₀: ω₀, width: BW) }
    public static func bpf(ω₀: Stream, Q: Stream) -> Self { pass(_CascadeBandPass.self, _CascadeQualityPassWidth.self, ω₀: ω₀, width: Q) }
    public static func bpf(ω₀: Stream, BW: Stream) -> Self { pass(_CascadeBandPass.self, _CascadeBandwidthPassWidth.self, ω₀: ω₀, width: BW) }
    public static func bsf(ω₀: Stream, Q: Stream) -> Self { pass(_CascadeBandStop.self, _CascadeQualityPassWidth.self, ω₀: ω₀, width: Q) }
    public static func bsf(ω₀: Stream, BW: Stream) -> Self { pass(_CascadeBandStop.self, _CascadeBandwidthPassWidth.self, ω₀: ω₀, width: BW) }
    public static func apf(ω₀: Stream, Q: Stream) -> Self { pass(_CascadeAllPass.self, _CascadeQualityPassWidth.self, ω₀: ω₀, width: Q) }
    public static func apf(ω₀: Stream, BW: Stream) -> Self { pass(_CascadeAllPass.self, _CascadeBandwidthPassWidth.self, ω₀: ω₀, width: BW) }
}

// MARK: - LSF / HSF / PEQ
extension Filter.Cascade.Ar.Section {
    public static func lsf(ω₀: Stream, Q: Stream, dB: Stream) -> Self { shelf(_CascadeLowShelf.self, _CascadeQualityShelfWidth.self, ω₀: ω₀, width: Q, dB: dB) }
    public static func lsf(ω₀: Stream, BW: Stream, dB: Stream) -> Self { shelf(_CascadeLowShelf.self, _CascadeBandwidthShelfWidth.self, ω₀: ω₀, width: BW, dB: dB) }
    public static func lsf(ω₀: Stream, S: Stream, dB: Stream) -> Self { shelf(_CascadeLowShelf.self, _CascadeSlopeShelfWidth.self, ω₀: ω₀, width: S, dB: dB) }
    public static func hsf(ω₀: Stream, Q: Stream, dB: Stream) -> Self { shelf(_CascadeHighShelf.self, _CascadeQualityShelfWidth.self, ω₀: ω₀, width: Q, dB: dB) }
    public static func hsf(ω₀: Stream, BW: Stream, dB: Stream) -> Self { shelf(_CascadeHighShelf.self, _CascadeBandwidthShelfWidth.self, ω₀: ω₀, width: BW, dB: dB) }
    public static func hsf(ω₀: Stream, S: Stream, dB: Stream) -> Self { shelf(_CascadeHighShelf.self, _CascadeSlopeShelfWidth.self, ω₀: ω₀, width: S, dB: dB) }
    public static func peq(ω₀: Stream, Q: Stream, dB: Stream) -> Self { equalizer(_CascadeQualityEqualizerWidth.self, ω₀: ω₀, width: Q, dB: dB) }
    public static func peq(ω₀: Stream, BW: Stream, dB: Stream) -> Self { equalizer(_CascadeBandwidthEqualizerWidth.self, ω₀: ω₀, width: BW, dB: dB) }
    public static func peq(ω₀: Stream, S: Stream, dB: Stream) -> Self { equalizer(_CascadeSlopeEqualizerWidth.self, ω₀: ω₀, width: S, dB: dB) }
}

// MARK: - Constant audio-rate adapters
extension Filter.Cascade.Ar.Section {
    public static func lpf(ω₀: Stream, Q: Float64) -> Self { lpf(ω₀: ω₀, Q: const(Q)) }
    public static func lpf(ω₀: Float64, Q: Stream) -> Self { lpf(ω₀: const(ω₀), Q: Q) }
    public static func lpf(ω₀: Float64, Q: Float64) -> Self { lpf(ω₀: const(ω₀), Q: const(Q)) }
    public static func lpf(ω₀: Stream, BW: Float64) -> Self { lpf(ω₀: ω₀, BW: const(BW)) }
    public static func lpf(ω₀: Float64, BW: Stream) -> Self { lpf(ω₀: const(ω₀), BW: BW) }
    public static func lpf(ω₀: Float64, BW: Float64) -> Self { lpf(ω₀: const(ω₀), BW: const(BW)) }
    public static func hpf(ω₀: Stream, Q: Float64) -> Self { hpf(ω₀: ω₀, Q: const(Q)) }
    public static func hpf(ω₀: Float64, Q: Stream) -> Self { hpf(ω₀: const(ω₀), Q: Q) }
    public static func hpf(ω₀: Float64, Q: Float64) -> Self { hpf(ω₀: const(ω₀), Q: const(Q)) }
    public static func hpf(ω₀: Stream, BW: Float64) -> Self { hpf(ω₀: ω₀, BW: const(BW)) }
    public static func hpf(ω₀: Float64, BW: Stream) -> Self { hpf(ω₀: const(ω₀), BW: BW) }
    public static func hpf(ω₀: Float64, BW: Float64) -> Self { hpf(ω₀: const(ω₀), BW: const(BW)) }
    public static func bpf(ω₀: Stream, Q: Float64) -> Self { bpf(ω₀: ω₀, Q: const(Q)) }
    public static func bpf(ω₀: Float64, Q: Stream) -> Self { bpf(ω₀: const(ω₀), Q: Q) }
    public static func bpf(ω₀: Float64, Q: Float64) -> Self { bpf(ω₀: const(ω₀), Q: const(Q)) }
    public static func bpf(ω₀: Stream, BW: Float64) -> Self { bpf(ω₀: ω₀, BW: const(BW)) }
    public static func bpf(ω₀: Float64, BW: Stream) -> Self { bpf(ω₀: const(ω₀), BW: BW) }
    public static func bpf(ω₀: Float64, BW: Float64) -> Self { bpf(ω₀: const(ω₀), BW: const(BW)) }
    public static func bsf(ω₀: Stream, Q: Float64) -> Self { bsf(ω₀: ω₀, Q: const(Q)) }
    public static func bsf(ω₀: Float64, Q: Stream) -> Self { bsf(ω₀: const(ω₀), Q: Q) }
    public static func bsf(ω₀: Float64, Q: Float64) -> Self { bsf(ω₀: const(ω₀), Q: const(Q)) }
    public static func bsf(ω₀: Stream, BW: Float64) -> Self { bsf(ω₀: ω₀, BW: const(BW)) }
    public static func bsf(ω₀: Float64, BW: Stream) -> Self { bsf(ω₀: const(ω₀), BW: BW) }
    public static func bsf(ω₀: Float64, BW: Float64) -> Self { bsf(ω₀: const(ω₀), BW: const(BW)) }
    public static func apf(ω₀: Stream, Q: Float64) -> Self { apf(ω₀: ω₀, Q: const(Q)) }
    public static func apf(ω₀: Float64, Q: Stream) -> Self { apf(ω₀: const(ω₀), Q: Q) }
    public static func apf(ω₀: Float64, Q: Float64) -> Self { apf(ω₀: const(ω₀), Q: const(Q)) }
    public static func apf(ω₀: Stream, BW: Float64) -> Self { apf(ω₀: ω₀, BW: const(BW)) }
    public static func apf(ω₀: Float64, BW: Stream) -> Self { apf(ω₀: const(ω₀), BW: BW) }
    public static func apf(ω₀: Float64, BW: Float64) -> Self { apf(ω₀: const(ω₀), BW: const(BW)) }

    public static func lsf(ω₀: Stream, Q: Stream, dB: Float64) -> Self { lsf(ω₀: ω₀, Q: Q, dB: const(dB)) }
    public static func lsf(ω₀: Stream, Q: Float64, dB: Stream) -> Self { lsf(ω₀: ω₀, Q: const(Q), dB: dB) }
    public static func lsf(ω₀: Stream, Q: Float64, dB: Float64) -> Self { lsf(ω₀: ω₀, Q: const(Q), dB: const(dB)) }
    public static func lsf(ω₀: Float64, Q: Stream, dB: Stream) -> Self { lsf(ω₀: const(ω₀), Q: Q, dB: dB) }
    public static func lsf(ω₀: Float64, Q: Stream, dB: Float64) -> Self { lsf(ω₀: const(ω₀), Q: Q, dB: const(dB)) }
    public static func lsf(ω₀: Float64, Q: Float64, dB: Stream) -> Self { lsf(ω₀: const(ω₀), Q: const(Q), dB: dB) }
    public static func lsf(ω₀: Float64, Q: Float64, dB: Float64) -> Self { lsf(ω₀: const(ω₀), Q: const(Q), dB: const(dB)) }
    public static func lsf(ω₀: Stream, BW: Stream, dB: Float64) -> Self { lsf(ω₀: ω₀, BW: BW, dB: const(dB)) }
    public static func lsf(ω₀: Stream, BW: Float64, dB: Stream) -> Self { lsf(ω₀: ω₀, BW: const(BW), dB: dB) }
    public static func lsf(ω₀: Stream, BW: Float64, dB: Float64) -> Self { lsf(ω₀: ω₀, BW: const(BW), dB: const(dB)) }
    public static func lsf(ω₀: Float64, BW: Stream, dB: Stream) -> Self { lsf(ω₀: const(ω₀), BW: BW, dB: dB) }
    public static func lsf(ω₀: Float64, BW: Stream, dB: Float64) -> Self { lsf(ω₀: const(ω₀), BW: BW, dB: const(dB)) }
    public static func lsf(ω₀: Float64, BW: Float64, dB: Stream) -> Self { lsf(ω₀: const(ω₀), BW: const(BW), dB: dB) }
    public static func lsf(ω₀: Float64, BW: Float64, dB: Float64) -> Self { lsf(ω₀: const(ω₀), BW: const(BW), dB: const(dB)) }
    public static func lsf(ω₀: Stream, S: Stream, dB: Float64) -> Self { lsf(ω₀: ω₀, S: S, dB: const(dB)) }
    public static func lsf(ω₀: Stream, S: Float64, dB: Stream) -> Self { lsf(ω₀: ω₀, S: const(S), dB: dB) }
    public static func lsf(ω₀: Stream, S: Float64, dB: Float64) -> Self { lsf(ω₀: ω₀, S: const(S), dB: const(dB)) }
    public static func lsf(ω₀: Float64, S: Stream, dB: Stream) -> Self { lsf(ω₀: const(ω₀), S: S, dB: dB) }
    public static func lsf(ω₀: Float64, S: Stream, dB: Float64) -> Self { lsf(ω₀: const(ω₀), S: S, dB: const(dB)) }
    public static func lsf(ω₀: Float64, S: Float64, dB: Stream) -> Self { lsf(ω₀: const(ω₀), S: const(S), dB: dB) }
    public static func lsf(ω₀: Float64, S: Float64, dB: Float64) -> Self { lsf(ω₀: const(ω₀), S: const(S), dB: const(dB)) }

    public static func hsf(ω₀: Stream, Q: Stream, dB: Float64) -> Self { hsf(ω₀: ω₀, Q: Q, dB: const(dB)) }
    public static func hsf(ω₀: Stream, Q: Float64, dB: Stream) -> Self { hsf(ω₀: ω₀, Q: const(Q), dB: dB) }
    public static func hsf(ω₀: Stream, Q: Float64, dB: Float64) -> Self { hsf(ω₀: ω₀, Q: const(Q), dB: const(dB)) }
    public static func hsf(ω₀: Float64, Q: Stream, dB: Stream) -> Self { hsf(ω₀: const(ω₀), Q: Q, dB: dB) }
    public static func hsf(ω₀: Float64, Q: Stream, dB: Float64) -> Self { hsf(ω₀: const(ω₀), Q: Q, dB: const(dB)) }
    public static func hsf(ω₀: Float64, Q: Float64, dB: Stream) -> Self { hsf(ω₀: const(ω₀), Q: const(Q), dB: dB) }
    public static func hsf(ω₀: Float64, Q: Float64, dB: Float64) -> Self { hsf(ω₀: const(ω₀), Q: const(Q), dB: const(dB)) }
    public static func hsf(ω₀: Stream, BW: Stream, dB: Float64) -> Self { hsf(ω₀: ω₀, BW: BW, dB: const(dB)) }
    public static func hsf(ω₀: Stream, BW: Float64, dB: Stream) -> Self { hsf(ω₀: ω₀, BW: const(BW), dB: dB) }
    public static func hsf(ω₀: Stream, BW: Float64, dB: Float64) -> Self { hsf(ω₀: ω₀, BW: const(BW), dB: const(dB)) }
    public static func hsf(ω₀: Float64, BW: Stream, dB: Stream) -> Self { hsf(ω₀: const(ω₀), BW: BW, dB: dB) }
    public static func hsf(ω₀: Float64, BW: Stream, dB: Float64) -> Self { hsf(ω₀: const(ω₀), BW: BW, dB: const(dB)) }
    public static func hsf(ω₀: Float64, BW: Float64, dB: Stream) -> Self { hsf(ω₀: const(ω₀), BW: const(BW), dB: dB) }
    public static func hsf(ω₀: Float64, BW: Float64, dB: Float64) -> Self { hsf(ω₀: const(ω₀), BW: const(BW), dB: const(dB)) }
    public static func hsf(ω₀: Stream, S: Stream, dB: Float64) -> Self { hsf(ω₀: ω₀, S: S, dB: const(dB)) }
    public static func hsf(ω₀: Stream, S: Float64, dB: Stream) -> Self { hsf(ω₀: ω₀, S: const(S), dB: dB) }
    public static func hsf(ω₀: Stream, S: Float64, dB: Float64) -> Self { hsf(ω₀: ω₀, S: const(S), dB: const(dB)) }
    public static func hsf(ω₀: Float64, S: Stream, dB: Stream) -> Self { hsf(ω₀: const(ω₀), S: S, dB: dB) }
    public static func hsf(ω₀: Float64, S: Stream, dB: Float64) -> Self { hsf(ω₀: const(ω₀), S: S, dB: const(dB)) }
    public static func hsf(ω₀: Float64, S: Float64, dB: Stream) -> Self { hsf(ω₀: const(ω₀), S: const(S), dB: dB) }
    public static func hsf(ω₀: Float64, S: Float64, dB: Float64) -> Self { hsf(ω₀: const(ω₀), S: const(S), dB: const(dB)) }

    public static func peq(ω₀: Stream, Q: Stream, dB: Float64) -> Self { peq(ω₀: ω₀, Q: Q, dB: const(dB)) }
    public static func peq(ω₀: Stream, Q: Float64, dB: Stream) -> Self { peq(ω₀: ω₀, Q: const(Q), dB: dB) }
    public static func peq(ω₀: Stream, Q: Float64, dB: Float64) -> Self { peq(ω₀: ω₀, Q: const(Q), dB: const(dB)) }
    public static func peq(ω₀: Float64, Q: Stream, dB: Stream) -> Self { peq(ω₀: const(ω₀), Q: Q, dB: dB) }
    public static func peq(ω₀: Float64, Q: Stream, dB: Float64) -> Self { peq(ω₀: const(ω₀), Q: Q, dB: const(dB)) }
    public static func peq(ω₀: Float64, Q: Float64, dB: Stream) -> Self { peq(ω₀: const(ω₀), Q: const(Q), dB: dB) }
    public static func peq(ω₀: Float64, Q: Float64, dB: Float64) -> Self { peq(ω₀: const(ω₀), Q: const(Q), dB: const(dB)) }
    public static func peq(ω₀: Stream, BW: Stream, dB: Float64) -> Self { peq(ω₀: ω₀, BW: BW, dB: const(dB)) }
    public static func peq(ω₀: Stream, BW: Float64, dB: Stream) -> Self { peq(ω₀: ω₀, BW: const(BW), dB: dB) }
    public static func peq(ω₀: Stream, BW: Float64, dB: Float64) -> Self { peq(ω₀: ω₀, BW: const(BW), dB: const(dB)) }
    public static func peq(ω₀: Float64, BW: Stream, dB: Stream) -> Self { peq(ω₀: const(ω₀), BW: BW, dB: dB) }
    public static func peq(ω₀: Float64, BW: Stream, dB: Float64) -> Self { peq(ω₀: const(ω₀), BW: BW, dB: const(dB)) }
    public static func peq(ω₀: Float64, BW: Float64, dB: Stream) -> Self { peq(ω₀: const(ω₀), BW: const(BW), dB: dB) }
    public static func peq(ω₀: Float64, BW: Float64, dB: Float64) -> Self { peq(ω₀: const(ω₀), BW: const(BW), dB: const(dB)) }
    public static func peq(ω₀: Stream, S: Stream, dB: Float64) -> Self { peq(ω₀: ω₀, S: S, dB: const(dB)) }
    public static func peq(ω₀: Stream, S: Float64, dB: Stream) -> Self { peq(ω₀: ω₀, S: const(S), dB: dB) }
    public static func peq(ω₀: Stream, S: Float64, dB: Float64) -> Self { peq(ω₀: ω₀, S: const(S), dB: const(dB)) }
    public static func peq(ω₀: Float64, S: Stream, dB: Stream) -> Self { peq(ω₀: const(ω₀), S: S, dB: dB) }
    public static func peq(ω₀: Float64, S: Stream, dB: Float64) -> Self { peq(ω₀: const(ω₀), S: S, dB: const(dB)) }
    public static func peq(ω₀: Float64, S: Float64, dB: Stream) -> Self { peq(ω₀: const(ω₀), S: const(S), dB: dB) }
    public static func peq(ω₀: Float64, S: Float64, dB: Float64) -> Self { peq(ω₀: const(ω₀), S: const(S), dB: const(dB)) }
}
