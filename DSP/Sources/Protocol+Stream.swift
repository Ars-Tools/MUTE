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
