//
//  Error.swift
//  MUTE
//
//  Created by Kota on 7/10/R7.
//
@usableFromInline
enum Error: Swift.Error & Sendable {
	case notImplemented
	case invalidContext
	case unmatchChannel
	case invalidChannel
	case lackOfResource(String)
	case resourceConflict
	case failedToAllocate(Any.Type)
}
@usableFromInline
enum TypedError<Root: Sendable>: Swift.Error, Sendable {
    case resourceConflict(of: Root, interval: CMTime, capacity: Int)
    case invalidProperty(of: Root, property: PartialKeyPath<Root> & Sendable)
    case invalidChannel(of: Root, require: Int)
}
