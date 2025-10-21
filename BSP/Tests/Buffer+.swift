//
//  Buffer+.swift
//  MUTE
//
//  Created by Kota on 10/20/25.
//
import Testing
@testable import BSP
@Suite
struct BufferTestCases {
    @Test
    func fadeIn() {
        let buffer = Buffer(stream: 1, period: 16)
        for signal in buffer.unsafeMutableBufferPointer {
            signal.initialize(repeating: 1)
        }
        buffer.fade(in: 16, dB: -60)
        print(buffer.unsafeMutableBufferPointer.map(Array.init))
    }
}
