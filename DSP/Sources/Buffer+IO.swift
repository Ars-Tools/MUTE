//
//  Buffer+IO.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
import typealias CoreMedia.CMTime
import func CoreMedia.CMTimeMultiply
import typealias Auxiliary.Autorelease
extension Buffer {
	public init(raw path: String, offset: Int = 0, stream: Int) throws {
		let memory = try Autorelease.Memory(ro: path)
		self.init(stream: stream,
				  period: (memory.count - offset) / stream / MemoryLayout<Float64>.stride,
				  memory: memory,
				  offset: offset)
	}
	public init(raw path: String, offset: Int = 0, period: Int) throws {
		let memory = try Autorelease.Memory(ro: path)
		self.init(stream: (memory.count - offset) / period / MemoryLayout<Float64>.stride,
				  period: period,
				  memory: memory,
				  offset: offset)
	}
    public init(ro path: String, offset: Int = 0, period: Int) throws {
        let memory = try Autorelease.Memory(ro: path)
        self.init(stream: (memory.count - offset) / period / MemoryLayout<Float64>.stride,
                  period: period,
                  memory: memory,
                  offset: offset)
    }
}
extension Buffer {
	public init(stream: Int, period: Int, offset: Int = 0, backing storage: String, release: Bool) throws {
		try self.init(stream: stream,
					  period: period,
					  memory: .init(rw: storage, minimum: stream * period * MemoryLayout<Float64>.stride + offset, release: release),
					  offset: offset)
	}
}
extension Buffer {
	public init(stream: DSP.Stream, interval: CMTime, capacity: Duration, progress: Optional<Duration> = .none) throws {
		self.init(stream: stream.count, period: capacity.samples(for: interval))
		try`import`(stream: stream, interval: interval, capacity: progress)
	}
	public init(stream: DSP.Stream, interval: CMTime, capacity: Duration, progress: Optional<Duration> = .none, backing storage: String, release: Bool) throws {
		try self.init(stream: stream.count, period: capacity.samples(for: interval), backing: storage, release: release)
		try`import`(stream: stream, interval: interval, capacity: progress)
	}
	public func`import`(stream: DSP.Stream, interval: CMTime, capacity: Optional<Duration> = .none) throws {
		var instance = Instance()
		let length = capacity.map { $0.samples(for: interval) } ?? period
		let render = try stream(interval: interval, capacity: length, instance: &instance)
		let commit = instance.commit
		for cursor in stride(from: 0, to: period, by: length) {
            render(CMTimeMultiply(interval, multiplier: .init(cursor)),
				   Swift.min(period - cursor, length),
				   start.advanced(by: cursor),
				   period)
            commit(moment: CMTimeMultiply(interval, multiplier: .init(cursor)),
                   length: Swift.min(period - cursor, length))
		}
	}
}
