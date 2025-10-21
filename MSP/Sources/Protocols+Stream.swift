//
//  Protocols+Stream.swift
//  MUTE
//
//  Created by Kota on 5/9/R7.
//
@_exported @preconcurrency import typealias CoreMedia.CMTime
public protocol Stream: Sendable {
	@inlinable var count: Int { get }
	@inlinable func callAsFunction(interval: CMTime,
								   capacity: Int,
								   resource: inout Resource) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void
}
