//
//  Instance.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
import typealias CoreMedia.CMTime
@preconcurrency import class Dispatch.DispatchQueue
public struct Context: Hashable, Sendable {
	@usableFromInline let interval: CMTime
	@usableFromInline let capacity: Int
	@usableFromInline let identity: ObjectIdentifier
}
public typealias Instance = Dictionary<Context, Sendable>
public typealias Prefix = Array<@Sendable (CMTime, Int) -> Void>
public typealias Suffix = Array<@Sendable () -> Void>
extension Instance {
	@inlinable
	public var prefix: Prefix {
		values.compactMap { $0 as?Prefix.Element }
	}
	@inlinable
	public var suffix: Suffix {
		values.compactMap { $0 as?Suffix.Element }
	}
}
extension Collection where Self: Sendable, Element == Prefix.Element, Index: Strideable, Index.Stride: BinaryInteger {
	public func callAsFunction(moment: CMTime, length: Int) {
		DispatchQueue.concurrentPerform(iterations: count) {
			self[startIndex.advanced(by: .init($0))](moment, length)
		}
	}
}
extension Collection where Self: Sendable, Element == Suffix.Element, Index: Strideable, Index.Stride: BinaryInteger {
	public func callAsFunction() {
		DispatchQueue.concurrentPerform(iterations: count) {
			self[startIndex.advanced(by: .init($0))]()
		}
	}
}
