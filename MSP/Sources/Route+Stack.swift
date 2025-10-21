//
//  Route+Stack.swift
//  MUTE
//
//  Created by Kota on 6/27/R7.
//
@usableFromInline
enum Stack {
	struct He<Source: Sequence<Stream> & Sendable>: RawRepresentable {
		@usableFromInline let rawValue: Source
	}
}
extension Stack.He: Stream {
	@inlinable
	var count: Int {
		rawValue.lazy.map(\.count).reduce(0, +)
	}
	@inlinable
	func callAsFunction(interval: CMTime, capacity: Int, resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let source = try rawValue.map {
			try ($0.count, $0(interval: interval, capacity: capacity, resource: &resource))
		}
		let kernel = zip(source.map(\.0).cumulative, source.map(\.1)).map(\.self)
		return {
			for (offset, kernel) in kernel {
				kernel($0, $1, $2.advanced(by: offset * $3), $3)
			}
		}
	}
}
public func stack(_ source: some Sequence<Stream> & Sendable) -> some Stream {
	Stack.He(rawValue: source)
}
@_disfavoredOverload
public func stack(_ source: Stream...) -> some Stream {
	stack(source)
}

