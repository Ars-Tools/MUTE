//
//  Error.swift
//  MUTE
//
//  Created by Kota on 9/20/26.
//
import Foundation
import os.log
@usableFromInline
struct Error: Swift.Error, CustomStringConvertible {
    @usableFromInline
    let operation: String
    @usableFromInline
    let status: OSStatus
}
extension Error {
    @inlinable
    static func description(for status: OSStatus) -> String {
        withUnsafeBytes(of: status) {
            String(bytes: $0, encoding: .ascii)
        } ?? "????"
    }
    @inlinable
    var description: String {
        "\(operation) failed: \(Self.description(for: status)) (\(status))"
    }
}
extension Error {
    @inlinable
    init(status fourCC: OSStatus, operation function: String = #function) {
        operation = function
        status = fourCC
    }
}
extension Error {
    @inlinable
    static func log(status: OSStatus, at position: String = #function) {
        os_log(.error, "%{public} failed: %{public}@", position, description(for: status))
    }
}
