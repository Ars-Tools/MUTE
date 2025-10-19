//
//  Error.swift
//  MUTE
//
//  Created by Kota on 7/16/R7.
//
@preconcurrency import typealias os.OSStatus
@usableFromInline
enum Error: Swift.Error {
	case unsupportedFormat
	case converterNotAllocated
	case pcmBufferNotAllocated
	case midi(OSStatus)
}
