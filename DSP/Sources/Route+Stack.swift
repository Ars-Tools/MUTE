//
//  Route+Stack.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import typealias Dispatch.DispatchQueue
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
	func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
		let source = try rawValue.map {
			try ($0(interval: interval, capacity: capacity, instance: &instance), $0.count)
		}
		let kernel = zip(source.map(\.0), source.map(\.1).cumulative).map(\.self)
		return { moment, length, target, stride in
			each(element: kernel) {
				$0(moment, length, target.advanced(by: $1 * stride), stride)
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

