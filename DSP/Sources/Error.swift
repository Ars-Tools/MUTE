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
/*
 He: without any arguments
 Ne: with constant arguments
 Kr: with control-rate arguments
 Ar: with audio-rate arguments
 Xe: special (like buffer)
 Rn: detect
 Og:
 */
