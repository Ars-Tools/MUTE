//
//  Misc.swift
//  MUTE
//
//  Created by Kota on 6/26/R7.
//
import Testing
import Accelerate
import MSP
@Suite
struct MiscTestCase {
	func write(to path: String, source: MSP.Stream, for interval: CMTime, capacity: Int) throws {
		var isdir: ObjCBool = false
		if !FileManager.default.fileExists(atPath: path, isDirectory: &isdir), !isdir.boolValue {
			FileManager.default.createFile(atPath: path, contents: .none)
		}
		guard let target = FileHandle(forWritingAtPath: path) else {
			fatalError()
		}
		var object = Resource()
		let kernel = try source(interval: interval, capacity: capacity, resource: &object)
		for cursor in stride(from: 0, to: 48000, by: 1000) {
			var memory = Array<Float64>(repeating: .zero, count: 1000)
			kernel(.init(value: .init(cursor), timescale: 48000), 1000, &memory, 1000)
			try memory.withUnsafeBytes {
				try target.write(contentsOf: Data($0))
			}
		}
	}
	@Test
	func test2() throws {
		for k in 0...16 {
			let r = Float64(k) / Float64(16)
			let source = tri(freqs: 960, ratio: r)
			try write(to: "/tmp/rec\(k)", source: source, for: .init(value: 1, timescale: 48000), capacity: 1000)
		}
	}
	@Test
	func dft() throws {
		let p = phasor(freqs: 2)
		let x = framewise(p, window: .rectangular(0.125), stride: .relative(1), output: 1) { _,_ in { _, s, t in
			for (s, var t) in zip(s, t) {
				t.initialize(fromContentsOf: s)
			}
		}}
		try write(to: "/tmp/dft", source: x, for: .init(value: 1, timescale: 48000), capacity: 1000)
	}
	@Test
	func mps() throws {
		let p = phasor(freqs: 2)
		let q = MTLCreateSystemDefaultDevice().flatMap { $0.makeCommandQueue() }.unsafelyUnwrapped
		let x = framewise(2.0 * .pi * p, window: .rectangular(1000 as Samples), stride: .relative(1.0), output: 1, thread: q) {
			let x = $1.sin(with: $3, name: .none)
			let y = $1.multiplication($1.constant(2, dataType: .float32), x, name: .none)
			return y
		}
		try write(to: "/tmp/mps", source: x, for: .init(value: 1, timescale: 48000), capacity: 1000)
	}
}
