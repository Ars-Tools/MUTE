//
//  WindowFunction.swift
//  MUTE
//
//  Created by Kota on 9/17/26.
//
import Testing
@testable import ESP
@Suite
struct WindowFunction {
    @Test
    func chebyshev() {
        let window = ESP.WindowFunction.Chebyshev(α: 0.5).generate(count: 256)
        print(window)
    }
}
