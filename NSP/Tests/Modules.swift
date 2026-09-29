//
//  Modules.swift
//  MUTE
//
//  Created by Kota on 8/14/26.
//
import Testing
@testable import NSP
import Complex
import Numerics
@Suite
struct ModuleTestCases {
    @Test
    func copy() {
        let x: Complex128.RawValue = .init()
        withUnsafePointer(to: x) {
            print($0.pointer(to: \.r))
        }
    }
}
