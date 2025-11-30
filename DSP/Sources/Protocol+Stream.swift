//
//  Protocol+Stream.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
@_exported import typealias CoreMedia.CMTime
public protocol Stream: Sendable {
	@inlinable var count: Int { get }
	@inlinable func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void
}
@usableFromInline
struct Re<Source: Stream, Resource: Sendable>: Sendable {
    @usableFromInline let source: Source
    @usableFromInline let resource: Array<Resource>
}
extension Re: Stream {
    @inlinable
    var count: Int {
        source.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        try source(interval: interval, capacity: capacity, instance: &instance)
    }
}
extension Stream {
    public func depends<Resource: Sendable>(on resource: Resource...) -> some Stream {
        Re(source: self, resource: resource)
    }
}
