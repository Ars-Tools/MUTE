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
extension Instance {
    public mutating func store(_ object: AnyObject, interval: CMTime, capacity: Int) {
        precondition(!(object is Commit))
        updateValue(unsafeBitCast(object, to: (AnyObject & Sendable).self),
                    forKey: .init(interval: interval, capacity: capacity, identity: .init(object)))
    }
}
public typealias Commit = Array<@Sendable (CMTime, Int) -> Void>
extension Instance {
    @inlinable
    public var commit: Commit {
        values.compactMap { $0 as?Commit.Element }
    }
}
extension Collection where Self: Sendable, Element == Commit.Element, Index == Int {
    @inlinable
    public func callAsFunction(moment: CMTime, length: Int) {
        each(element: self) {
            $0(moment, length)
        }
    }
}
