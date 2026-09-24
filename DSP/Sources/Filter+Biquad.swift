//
//  Filter+Biquad.swift
//  MUTE
//
//  Created by Kota on 7/11/R7.
//
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Accelerate.AccelerateBuffer
import typealias Synchronization.Mutex
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import func Layout.broadcast
import func Accelerate.vecLib.vDSP_biquadm_CreateSetupD
import func Accelerate.vecLib.vDSP_biquadm_DestroySetupD
import func Accelerate.vecLib.vDSP_biquadm_SetTargetsDoubleD
import func Accelerate.vecLib.vDSP_biquadm_SetCoefficientsDoubleD
import func Accelerate.vecLib.vDSP_biquadm_SetActiveFiltersD
import func Accelerate.vecLib.vDSP_biquadmD
import func Accelerate.vecLib.vDSP_biquad_CreateSetupD
import func Accelerate.vecLib.vDSP_biquad_DestroySetupD
import func Accelerate.vecLib.vDSP_biquadD
import Accelerate
import func NSP.biquad_filter_create
import func NSP.biquad_filter_destroy
import func NSP.biquad_filter_active
import func NSP.biquad_filter_convolve_active
import func simd.cos
import func simd.log2
import typealias Auxiliary.Autorelease
import typealias ESP.BiquadFilter
extension SIMD3: @retroactive RandomAccessCollection {
    public var startIndex: Int { 0 }
    public var endIndex: Int { scalarCount }
}
extension SIMD3: @retroactive AccelerateBuffer {
    
}
extension Filter {
    public protocol Biquad<Element>: TransferFunction where B == SIMD3<Element>, A == SIMD3<Element>, Element: SIMDScalar {
        @inlinable func coefficients(for Tₛ: CMTime) -> (b: B, a: A)
    }
}
extension Filter.Biquad {
    @inlinable
    public var counts: SIMD2<Int> {
        .init(3, 3)
    }
    @inlinable
    public func normalizedCoefficients(for Tₛ: CMTime) -> Array<Element> where Element == Float64 {
        let (b, a) = coefficients(for: Tₛ)
        return.init(unsafeUninitializedCapacity: 5) {
            $1 = $0.startIndex.distance(to: $0[$0.initialize(fromContentsOf: b / a.x)...].initialize(fromContentsOf: (a / a.x).dropFirst()))
        }
    }
    @inlinable
    public func normalizedCoefficients(for Tₛ: CMTime) -> Array<Element> where Element == Float32 {
        let (b, a) = coefficients(for: Tₛ)
        return.init(unsafeUninitializedCapacity: 5) {
            $1 = $0.startIndex.distance(to: $0[$0.initialize(fromContentsOf: b / a.x)...].initialize(fromContentsOf: (a / a.x).dropFirst()))
        }
    }
    @inlinable
    public func normalizedCoefficients(for Tₛ: CMTime) -> Array<Element> where Element == Float16 {
        let (b, a) = coefficients(for: Tₛ)
        return.init(unsafeUninitializedCapacity: 5) {
            $1 = $0.startIndex.distance(to: $0[$0.initialize(fromContentsOf: b / a.x)...].initialize(fromContentsOf: (a / a.x).dropFirst()))
        }
    }
}
extension Filter {
    @usableFromInline
    enum SOS {
        @usableFromInline
        struct Kr<Signal: Publisher<(Int, (Int, Design)), Never> & Sendable, Design: Filter.Biquad<Float64>> {
            @usableFromInline let source: Stream
            @usableFromInline let design: Signal
            @usableFromInline let stages: Int
        }
        @usableFromInline // audio-rate filtering, shared filter coefficients for all channels
        struct Ar<Batch: Sequence<Stream> & Sendable> {
            @usableFromInline let source: Stream
            @usableFromInline let design: Batch // serialized section (b a)
        }
    }
}
extension Filter.SOS.Kr: DSP.Stream {
    @inlinable
    var count: Int {
        source.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        switch source.count {
//        case 1:
        case let stream:
            let object = switch vDSP_biquadm_CreateSetupD(repeatElement(Array(arrayLiteral: 1, 0, 0, 0, 0), count: stream * stages).flatMap(\.self), .init(stages), .init(stream)) {
            case.some(let opaque):
                Autorelease.Opaque(pointer: opaque, release: vDSP_biquadm_DestroySetupD)
            case.none:
                throw Error.failedToAllocate(OpaquePointer.self)
            }
            let cancel = design.sink {
                switch ($0, $1.0) {
                case (0..<stream, 0..<stages):
                    vDSP_biquadm_SetCoefficientsDoubleD(object.pointer,
                                                        $1.1.normalizedCoefficients(for: interval),
                                                        .init($1.0), .init($0),
                                                        1, 1)
                default:
                    assertionFailure("out of range")
                }
            }
            return { [cancel, object] in
                kernel($0, $1, $2, $3)
                var x = stride(from: 0, to: stream * $3, by: $3).map(UnsafePointer($2).advanced(by:))
                var y = stride(from: 0, to: stream * $3, by: $3).map($2.advanced(by:))
                vDSP_biquadmD(object.pointer,
                              &x, 1,
                              &y, 1,
                              .init($1))
            }
        }
    }
}
extension Filter.SOS.Ar: DSP.Stream {
    @inlinable
    var count: Int {
        source.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        switch source.count {
//        case 1:
//            let batches = try design.map {
//                switch $0.count.quotientAndRemainder(dividingBy: 6) {
//                case (let stage, 0):
//                    try (Autorelease.Object(object: biquad_filter_create(stage)) {
//                        biquad_filter_destroy($0)
//                    }, $0(interval: interval, capacity: capacity, instance: &instance))
//                default:
//                    throw Error.unmatchChannel
//                }
//            }
//            let stages = batches.map(\.0.reference.pointee.z).max() ?? 0
//            let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        case let count:
            let batches = try design.map {
                switch $0.count.quotientAndRemainder(dividingBy: 6) {
                case (let stage, 0):
                    try (Autorelease.Object(object: biquad_filter_create(stage, count)) {
                        biquad_filter_destroy($0)
                    }, $0(interval: interval, capacity: capacity, instance: &instance))
                default:
                    throw Error.unmatchChannel
                }
            }
            let stages = batches.map(\.0.reference.pointee.order).max() ?? 0
            let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
            return { moment, length, target, stride in
                kernel(moment, length, target, stride)
                withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * stages * length) {
                    guard case.some(let θ) = $0.baseAddress else {
                        return assertionFailure()
                    }
                    for (object, coefficients) in batches {
                        coefficients(moment, length, θ, length)
                        biquad_filter_active(object.reference,
                                             θ.advanced(by: 0 * length), 6 * length,
                                             θ.advanced(by: 1 * length), 6 * length,
                                             θ.advanced(by: 2 * length), 6 * length,
                                             θ.advanced(by: 3 * length), 6 * length,
                                             θ.advanced(by: 4 * length), 6 * length,
                                             θ.advanced(by: 5 * length), 6 * length,
                                             target, stride,
                                             target, stride,
                                             length)
                    }
                }
            }
        }
    }
}
// MARK: filter functions
@_disfavoredOverload
public func filter(_ source: Stream, sos design: some Publisher<(Int, (Int, some Filter.Biquad<Float64>)), Never> & Sendable, count: Int) -> some Stream {
    Filter.SOS.Kr(source: source, design: design, stages: count)
}
@inlinable
public func filter(_ source: Stream, sos design: some Publisher<(Int, some Filter.Biquad<Float64>), Never>, count: Int) -> some Stream {
    filter(source, sos: design.repeat(count: source.count), count: count)
}
@inlinable
public func filter(_ source: Stream, sos design: some Publisher<(Int, some Collection<some Filter.Biquad<Float64>>), Never>, count: Int) -> some Stream {
    filter(source, sos: design.flatMap { (key, value) in value.enumerated().publisher.map { (key, $0) } }, count: count)
}
@inlinable
public func filter(_ source: Stream, sos design: some Publisher<some Collection<some Filter.Biquad<Float64>>, Never>, count: Int) -> some Stream {
    filter(source, sos: design.repeat(count: source.count), count: count)
}
@inlinable
public func filter(_ source: Stream, sos design: some Collection<some Filter.Biquad<Float64>>) -> some Stream {
    filter(source, sos: `repeat`(design, count: source.count), count: design.count)
}
@inlinable
public func filter<Design: Filter.Biquad<Float64>>(_ source: Stream, sos design: Design...) -> some Stream {
    filter(source, sos: design)
}
@_disfavoredOverload
public func filter(_ source: Stream, sos design: some Sequence<Stream> & Sendable) -> some Stream { // 1 batch = [section][b0, b1, b2, a0, a1, a2] layout
    Filter.SOS.Ar(source: source, design: design)
}
@inlinable
public func filter(_ source: Stream, sos design: Stream...) -> some Stream { // 1 batch = [section][b0, b1, b2, a0, a1, a2] layout
    filter(source, sos: design)
}


// MARK: Legacy
extension BiquadFilter {
    public enum Design: Sendable {
        case bpf(ω₀: Frequency, quality: Float64) // band-pass
        case lpf(ω₀: Frequency, quality: Float64) // lo-pass
        case hpf(ω₀: Frequency, quality: Float64) // hi-pass
        case apf(ω₀: Frequency, quality: Float64) // all-pass
        case bsf(ω₀: Frequency, quality: Float64) // band-stop
        case lsf(ω₀: Frequency, quality: Float64, gain: Float64) // lo-shelf
        case hsf(ω₀: Frequency, quality: Float64, gain: Float64) // hi-shelf
        case peq(ω₀: Frequency, quality: Float64, gain: Float64) // peaking
        case raw(b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) // raw coefficients
    }
}
extension BiquadFilter.Design {
    @inlinable@inline(__always)@_transparent
    public init(lpf: (ω₀: Frequency, Q: Float64)) {
        self = .lpf(ω₀: lpf.ω₀, quality: lpf.Q)
    }
    @inlinable@inline(__always)@_transparent
    public init(hpf: (ω₀: Frequency, Q: Float64)) {
        self = .hpf(ω₀: hpf.ω₀, quality: hpf.Q)
    }
    @inlinable@inline(__always)@_transparent
    public init(bpf: (ω₀: Frequency, Q: Float64)) {
        self = .bpf(ω₀: bpf.ω₀, quality: bpf.Q)
    }
    @inlinable@inline(__always)@_transparent
    public init(bsf: (ω₀: Frequency, Q: Float64)) {
        self = .bsf(ω₀: bsf.ω₀, quality: bsf.Q)
    }
    @inlinable@inline(__always)@_transparent
    public init(apf: (ω₀: Frequency, Q: Float64)) {
        self = .apf(ω₀: apf.ω₀, quality: apf.Q)
    }
    @inlinable@inline(__always)@_transparent
    public init(lsf: (ω₀: Frequency, Q: Float64, dB: Float64)) {
        self = .lsf(ω₀: lsf.ω₀, quality: lsf.Q, gain: lsf.dB)
    }
    @inlinable@inline(__always)@_transparent
    public init(hsf: (ω₀: Frequency, Q: Float64, dB: Float64)) {
        self = .hsf(ω₀: hsf.ω₀, quality: hsf.Q, gain: hsf.Q)
    }
    @inlinable@inline(__always)@_transparent
    public init(peq: (ω₀: Frequency, Q: Float64, dB: Float64)) {
        self = .peq(ω₀: peq.ω₀, quality: peq.Q, gain: peq.dB)
    }
    @inlinable@inline(__always)@_transparent
    public init(b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
        self = .raw(b₀: b₀, b₁: b₁, b₂: b₂, a₁: a₁, a₂: a₁)
    }
    @inlinable@inline(__always)@_transparent
    public init(_ raw: (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64)) {
        self.init(b₀: raw.b₀, b₁: raw.b₁, b₂: raw.b₂, a₁: raw.a₁, a₂: raw.a₂)
    }
    @inlinable
    public init(z: (r: Float64, θ: Float64), p: (r: Float64, θ: Float64)) {
        let x = SIMD2<Float64>(z.r, p.r)
        let y = 2 * x * cos(SIMD2<Float64>(z.θ, p.θ))
        let z = x * x
        self = .raw(b₀: 1, b₁: y.x, b₂: z.x, a₁: y.y, a₂: z.y)
    }
}
extension BiquadFilter.Design {
	@inlinable@inline(__always)
	public func coefficients(for Ts: CMTime) -> (b₀: Float64, b₁: Float64, b₂: Float64, a₁: Float64, a₂: Float64) {
		switch self {
        case.bpf(let ω₀, let Q):
            BiquadFilter.BPF(ω₀: ω₀.increment(for: Ts), Q: Q)
		case.lpf(let ω₀, let Q):
            BiquadFilter.LPF(ω₀: ω₀.increment(for: Ts), Q: Q)
		case.hpf(let ω₀, let Q):
            BiquadFilter.HPF(ω₀: ω₀.increment(for: Ts), Q: Q)
        case.apf(let ω₀, let Q):
            BiquadFilter.APF(ω₀: ω₀.increment(for: Ts), Q: Q)
		case.bsf(let ω₀, let Q):
            BiquadFilter.BSF(ω₀: ω₀.increment(for: Ts), Q: Q)
		case.lsf(let ω₀, let Q, let dB):
            BiquadFilter.LSF(ω₀: ω₀.increment(for: Ts), Q: Q, dB: dB)
		case.hsf(let ω₀, let Q, let dB):
            BiquadFilter.HSF(ω₀: ω₀.increment(for: Ts), Q: Q, dB: dB)
		case.peq(let ω₀, let Q, let dB):
            BiquadFilter.PEQ(ω₀: ω₀.increment(for: Ts), Q: Q, dB: dB)
		case.raw(let b₀, let b₁, let b₂, let a₁, let a₂):
			(b₀, b₁, b₂, a₁, a₂)
		}
	}
}
extension BiquadFilter {
	@usableFromInline
	struct Kr<Signal: Publisher<(Int, (Int, BiquadFilter.Design)), Never> & Sendable> {
		@usableFromInline let source: Stream
		@usableFromInline let design: Signal
		@usableFromInline let length: Int
	}
}
extension BiquadFilter.Kr: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
		let stream = source.count
		guard let opaque = vDSP_biquadm_CreateSetupD(repeatElement([1,0,0,0,0], count: stream * length).flatMap(\.self), .init(length), .init(stream)) else {
			throw Error.failedToAllocate(OpaquePointer.self)
		}
		let object = Autorelease.Opaque(pointer: opaque, release: vDSP_biquadm_DestroySetupD)
		let cancel = design.sink { key, value in
			switch (key, value.0) {
			case (0..<stream, 0..<length):
				withUnsafeBytes(of: value.1.coefficients(for: interval)) {
					vDSP_biquadm_SetCoefficientsDoubleD(object.pointer,
														$0.assumingMemoryBound(to: Float64.self).baseAddress.unsafelyUnwrapped,
														.init(value.0), .init(key),
														1, 1)
				}
			default:
				assertionFailure("out of range")
			}
		}
		return {
			kernel($0, $1, $2, $3)
			var x = stride(from: 0, to: stream * $3, by: $3).map(UnsafePointer($2).advanced(by:))
			var y = stride(from: 0, to: stream * $3, by: $3).map($2.advanced(by:))
			vDSP_biquadmD(withExtendedLifetime(cancel) { object }.pointer,
						  &x, 1,
						  &y, 1,
						  .init($1))
		}
	}
}
public func filter(_ source: Stream, sos design: some Publisher<(Int, (Int, BiquadFilter.Design)), Never> & Sendable, length: Int) -> some Stream {
	BiquadFilter.Kr(source: source, design: design, length: length)
}
public func filter(_ source: Stream, sos design: some Publisher<(Int, BiquadFilter.Design), Never>, length: Int) -> some Stream {
	filter(source, sos: design.repeat(count: source.count), length: length)
}
public func filter(_ source: Stream, sos design: some Publisher<(Int, some Collection<BiquadFilter.Design>), Never>, length: Int) -> some Stream {
	filter(source, sos: design.flatMap { (key, value) in value.enumerated().publisher.map { (key, $0) } }, length: length)
}
public func filter(_ source: Stream, sos design: some Publisher<some Collection<BiquadFilter.Design>, Never>, length: Int) -> some Stream {
	filter(source, sos: design.repeat(count: source.count), length: length)
}
public func filter(_ source: Stream, sos design: some Collection<BiquadFilter.Design>) -> some Stream {
	filter(source, sos: `repeat`(design, count: source.count), length: design.count)
}
@_disfavoredOverload
public func filter(_ source: Stream, sos design: BiquadFilter.Design...) -> some Stream {
	filter(source, sos: design)
}
extension BiquadFilter {
	@usableFromInline
	struct Ar {
		@usableFromInline let source: Stream
		@usableFromInline let design: Design
		@usableFromInline
		enum Design: Sendable {
			case lpf(ω₀: Stream, quality: Stream)
			case hpf(ω₀: Stream, quality: Stream)
			case bpf(ω₀: Stream, quality: Stream)
			case bsf(ω₀: Stream, quality: Stream)
			case apf(ω₀: Stream, quality: Stream)
			case peq(ω₀: Stream, quality: Stream, gain: Stream)
			case lsf(ω₀: Stream, quality: Stream, gain: Stream)
			case hsf(ω₀: Stream, quality: Stream, gain: Stream)
			case raw(bₖ: Stream, aₖ: Stream)
		}
	}
}
extension BiquadFilter.Ar: Stream {
	@inlinable
	var count: Int {
		source.count
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let xk = try source(interval: interval, capacity: capacity, instance: &instance)
		let factor = 2.0 * .pi * interval.seconds
		let object = Autorelease.Object(object: biquad_filter_create(source.count)) {
			biquad_filter_destroy($0)
		}
		switch design {
		case.lpf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &a2)
					vDSP.fill(&a0, with: 1)
					//
					vDSP.subtract(a0, a1, result: &b1) // b1 = 1-cosω
					vDSP.addSubtract(a0, a2, addResult: &a0, subtractResult: &a2)
					//
					vDSP.multiply(0.5, b1, result: &b0)
					vDSP.multiply(0.5, b1, result: &b2)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.hpf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &a2)
					vDSP.fill(&a0, with: 1)
					//
					vDSP.multiply(addition: (a0, a1), -1, result: &b1)
					vDSP.addSubtract(a0, a2, addResult: &a0, subtractResult: &a2)
					//
					vDSP.multiply(-0.5, b1, result: &b0)
					vDSP.multiply(-0.5, b1, result: &b2)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.bpf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &b0)
					vDSP.negative(b0, result: &b2)
					vDSP.clear(&b1)
					//
					vDSP.add(1, b0, result: &a0)
					vDSP.add(1, b2, result: &a2)
					//
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.bsf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &a0)
					//
					vDSP.fill(&b0, with: 1)
					vDSP.fill(&b2, with: 1)
					vDSP.addSubtract(b0, a0, addResult: &a0, subtractResult: &a2)
					//
					vDSP.multiply(-2, a1, result: &b1)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.apf(let ω₀, let quality):
			guard ω₀.count == 1, quality.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &a0)
					//
					vDSP.fill(&a2, with: 1)
					vDSP.addSubtract(a2, a0, addResult: &b2, subtractResult: &b0)
					vDSP.addSubtract(a2, a0, addResult: &a0, subtractResult: &a2)
					//
					vDSP.multiply(-2, a1, result: &b1)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.lsf(let ω₀, let quality, let gain):
			guard ω₀.count == 1, quality.count == 1, gain.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			let gk = try gain(interval: interval, capacity: capacity, instance: &instance)
			let dB = SIMD2<Float64>(repeating: log2(10.0)) / SIMD2<Float64>(40, 80)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					var dc = UnsafeMutableBufferPointer(start: target, count: length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.divide(a2, a0, result: &a0)
					gk(moment, length, a2.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(dB.y, a2, result: &dc)
					vForce.exp2(dc, result: &dc)
					vDSP.multiply(a0, dc, result: &dc)
					vDSP.multiply(dB.x, a2, result: &a2)
					vForce.exp2(a2, result: &a2)
					//
					vDSP.fill(&a0, with: 1)
					vDSP.addSubtract(a0, a1, addResult: &a0, subtractResult: &a1)
					vDSP.multiply(a1, a2, result: &b0)
					vDSP.addSubtract(b0, a0, addResult: &b0, subtractResult: &b1)
					vDSP.addSubtract(b0, dc, addResult: &b0, subtractResult: &b2)
					vDSP.multiply(a2, b0, result: &b0)
					vDSP.multiply(a2, b1, result: &b1)
					vDSP.multiply(a2, b2, result: &b2)
					vDSP.multiply( 2, b1, result: &b1)
					//
					vDSP.multiply(a2, a0, result: &a0)
					vDSP.addSubtract(a0, a1, addResult: &a0, subtractResult: &a1)
					vDSP.addSubtract(a0, dc, addResult: &a0, subtractResult: &a2)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.hsf(let ω₀, let quality, let gain):
			guard ω₀.count == 1, quality.count == 1, gain.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			let gk = try gain(interval: interval, capacity: capacity, instance: &instance)
			let dB = SIMD2<Float64>(repeating: log2(10.0)) / SIMD2<Float64>(40, 80)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					var dc = UnsafeMutableBufferPointer(start: target, count: length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.divide(a2, a0, result: &a0)
					gk(moment, length, a2.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(dB.y, a2, result: &dc)
					vForce.exp2(dc, result: &dc)
					vDSP.multiply(a0, dc, result: &dc)
					vDSP.multiply(dB.x, a2, result: &a2)
					vForce.exp2(a2, result: &a2)
					//
					vDSP.fill(&a0, with: 1)
					vDSP.addSubtract(a0, a1, addResult: &a0, subtractResult: &a1)
					vDSP.multiply(a0, a2, result: &b0)
					vDSP.addSubtract(b0, a1, addResult: &b0, subtractResult: &b1)
					vDSP.addSubtract(b0, dc, addResult: &b0, subtractResult: &b2)
					vDSP.multiply(a2, b0, result: &b0)
					vDSP.multiply(a2, b1, result: &b1)
					vDSP.multiply(a2, b2, result: &b2)
					vDSP.multiply(-2, b1, result: &b1)
					//
					vDSP.multiply(a2, a1, result: &a1)
					vDSP.addSubtract(a1, a0, addResult: &a0, subtractResult: &a1)
					vDSP.addSubtract(a0, dc, addResult: &a0, subtractResult: &a2)
					vDSP.multiply( 2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.peq(let ω₀, let quality, let gain):
			guard ω₀.count == 1, quality.count == 1, gain.count == 1 else {
				throw Error.invalidChannel
			}
			let ωk = try ω₀(interval: interval, capacity: capacity, instance: &instance)
			let qk = try quality(interval: interval, capacity: capacity, instance: &instance)
			let gk = try gain(interval: interval, capacity: capacity, instance: &instance)
			let dB = log2(10.0) / 40.0
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					var b0 = $0.extracting(0*length..<1*length)
					var b1 = $0.extracting(1*length..<2*length)
					var b2 = $0.extracting(2*length..<3*length)
					var a0 = $0.extracting(3*length..<4*length)
					var a1 = $0.extracting(4*length..<5*length)
					var a2 = $0.extracting(5*length..<6*length)
					//
					ωk(moment, length, a1.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(factor, a1, result: &a1)
					vForce.sincos(a1, sinResult: &a2, cosResult: &a1)
					qk(moment, length, a0.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(2, a0, result: &a0)
					vDSP.divide(a2, a0, result: &a0)
					gk(moment, length, a2.baseAddress.unsafelyUnwrapped, length)
					vDSP.multiply(dB, a2, result: &a2)
					vForce.exp2(a2, result: &a2)
					//
					vDSP.fill(&b1, with: 1)
					vDSP.multiply(a0, a2, result: &b0)
					vDSP.addSubtract(b1, b0, addResult: &b0, subtractResult: &b2)
					vDSP.divide(a0, a2, result: &a0)
					vDSP.addSubtract(b1, a0, addResult: &a0, subtractResult: &a2)
					vDSP.multiply(-2, a1, result: &b1)
					vDSP.multiply(-2, a1, result: &a1)
					//
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b0.baseAddress.unsafelyUnwrapped, length,
										 a0.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		case.raw(let bₖ, let aₖ):
			guard bₖ.count == 3, aₖ.count == 3 else {
				throw Error.invalidChannel
			}
			let bk = try bₖ(interval: interval, capacity: capacity, instance: &instance)
			let ak = try aₖ(interval: interval, capacity: capacity, instance: &instance)
			return { moment, length, target, stride in
				withUnsafeTemporaryAllocation(of: Float64.self, capacity: 6 * length) {
					let b = $0.extracting(0*length..<3*length)
					let a = $0.extracting(3*length..<6*length)
					bk(moment, length, b.baseAddress.unsafelyUnwrapped, length)
					ak(moment, length, a.baseAddress.unsafelyUnwrapped, length)
					xk(moment, length, target, stride)
					biquad_filter_active(object.reference,
										 b.baseAddress.unsafelyUnwrapped, length,
										 a.baseAddress.unsafelyUnwrapped, length,
										 target, stride,
										 target, stride,
										 length)
				}
			}
		}
	}
}
public func filter(_ source: Stream, lpf: (ω₀: Stream, quality: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .lpf(ω₀: lpf.ω₀, quality: lpf.quality))
}
public func filter(_ source: Stream, hpf: (ω₀: Stream, quality: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .hpf(ω₀: hpf.ω₀, quality: hpf.quality))
}
public func filter(_ source: Stream, bpf: (ω₀: Stream, quality: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .bpf(ω₀: bpf.ω₀, quality: bpf.quality))
}
public func filter(_ source: Stream, bsf: (ω₀: Stream, quality: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .bsf(ω₀: bsf.ω₀, quality: bsf.quality))
}
public func filter(_ source: Stream, apf: (ω₀: Stream, quality: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .apf(ω₀: apf.ω₀, quality: apf.quality))
}
public func filter(_ source: Stream, lsf: (ω₀: Stream, quality: Stream, gain: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .lsf(ω₀: lsf.ω₀, quality: lsf.quality, gain: lsf.gain))
}
public func filter(_ source: Stream, hsf: (ω₀: Stream, quality: Stream, gain: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .hsf(ω₀: hsf.ω₀, quality: hsf.quality, gain: hsf.gain))
}
public func filter(_ source: Stream, peq: (ω₀: Stream, quality: Stream, gain: Stream)) -> some Stream {
	BiquadFilter.Ar(source: source, design: .peq(ω₀: peq.ω₀, quality: peq.quality, gain: peq.gain))
}
