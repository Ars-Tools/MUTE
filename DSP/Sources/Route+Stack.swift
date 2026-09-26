//
//  Route+Stack.swift
//  MUTE
//
//  Created by Kota on 7/14/R7.
//
@preconcurrency import typealias Dispatch.DispatchQueue
@usableFromInline
enum Stack {
    @usableFromInline
	struct Ne<Source: Sequence<Stream> & Sendable> {
		@usableFromInline let rawValue: Source
        @usableFromInline let parallel: Bool
	}
}
extension Stack.Ne: Stream {
	@inlinable
	var count: Int {
        rawValue.lazy.map(\.count).reduce(0, +)
	}
	@inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let source = try rawValue.map {
            try ($0(interval: interval, capacity: capacity, instance: &instance), $0.count)
        }
        let kernel = zip(source.lazy.map(\.0), source.lazy.map(\.1).cumulative).map(\.self)
        return if parallel {
            { moment, length, target, stride in
                each(element: kernel) {
                    $0(moment, length, target.advanced(by: $1 * stride), stride)
                }
            }
        } else {
            {
                for (kernel, offset) in kernel {
                    kernel($0, $1, $2.advanced(by: offset * $3), $3)
                }
            }
        }
    }
}
@_disfavoredOverload
public func stack(_ source: some Sequence<Stream> & Sendable, parallel: Bool = false) -> some Stream {
	Stack.Ne(rawValue: source, parallel: parallel)
}
@inlinable
public func stack(_ source: Stream..., parallel: Bool = false) -> some Stream {
	stack(source, parallel: parallel)
}

