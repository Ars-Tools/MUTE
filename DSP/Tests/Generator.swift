//
//  Generator.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
import Testing
import MetalPerformanceShadersGraph
import typealias CoreMedia.CMTime
import DSP
@Suite
struct GeneratorTestCases {
	@discardableResult
	func render(stream: DSP.Stream,
				interval: CMTime,
				capacity: Duration,
				progress: Optional<Duration>,
				to storage: String) throws -> Buffer {
		try Buffer(stream: stream, interval: interval, capacity: capacity, progress: progress, backing: storage, release: false)
	}
	let interval: CMTime = .init(value: 1, timescale: 16000)
	let queue = MTLCreateSystemDefaultDevice().flatMap { $0.makeCommandQueue() }.unsafelyUnwrapped
	@Test
	func tri2() throws {
		let x = DSP.tri(freqs: 1, 3, ratio: 0.5)
		let y = DSP.sin(freqs: 2, 4, ratio: 0.3)
		let w = Σ(x, y, axis: .term)
		try render(stream: w, interval: interval, capacity: 2, progress: 0.1, to: "/tmp/dump")
	}
	@Test
	func ramp() throws {
		let r = line(order:
			.init(position: 200, duration: 0.3),
			.init(position: 6400, duration: 5.3),
			.init(duration: 1.8),
			.init(position: 400, duration: 0.7))
//			let m = sin(freqs: 3.4) * 0.45 + 0.5
//			let m = fma(sin(freqs: 3.4), 0.45, 0.5)
		let q = buffer(r)
		let m = buffer(fma(tri(freqs: 4, ratio: 0.9), 0.45, 0.5))
		let x = mix(poly: 5, each: [221.1, 333.2, 360.3, 439.5, 552.7].enumerated().publisher.map(\.self)) {
			filter(rec(freqs: $0, ratio: m), lpf: (q, const(1.8)))
//				tri(freqs: $0, ratio: m)
		}
//			let y = tri(freqs: 330, ratio: 0.5)
		let y = buffer(x.count, capacity: 5)
		let z = x + 0.6 * y[t - 0.3]
		y.input = z
		try render(stream: z.with(y), interval: interval, capacity: 6.8, progress: 0.1, to: "/tmp/dump2")
	}
}
