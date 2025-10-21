//
//  Resource.swift
//  MUTE
//
//  Created by Kota on 5/9/R7.
//
public struct Identify: Hashable & Sendable {
	@usableFromInline let interval: CMTime
	@usableFromInline let capacity: Int
	@usableFromInline let instance: ObjectIdentifier
}
public typealias Resource = Dictionary<Identify, Sendable>
