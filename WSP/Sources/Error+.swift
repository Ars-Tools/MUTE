//
//  Error+.swift
//  MUTE
//
//  Created by Kota on 7/7/R7.
//
import typealias CoreMIDI.OSStatus
@usableFromInline
enum Error: Swift.Error {
	case noEndpoint
	case native(OSStatus)
}
