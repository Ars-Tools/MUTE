//
//  DFT.swift
//  MUTE
//
//  Created by Kota on 8/18/26.
//
import Testing
@testable import ESP
@Suite
struct DFTTestCases {
    @Test
    func pwt() throws {
        let op = try DFT.PWT(count: 8)
        let y = op.forward([1, 2, 3, 4, 1, 2, 3, 4])
        print(y)
        print(op.inverse(y))
    }
}
