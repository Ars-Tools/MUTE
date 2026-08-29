//
//  Guard.swift
//  MUTE
//
//  Created by Kota on 8/29/26.
//
import Testing
import typealias Accelerate.vDSP
@testable import ESP
@Suite
struct GuardTestCases {
    @Test
    func removeNAN() throws {
        var x = [0, .nan] as Array<Float64>
        Guard.removeNAN(of: &x)
        #expect(x.allSatisfy { $0.isFinite })
    }
    @Test
    func removeINF() {
        var x = [0, .infinity] as Array<Float64>
        Guard.removeINF(of: &x)
        #expect(x.allSatisfy { $0.isFinite })
    }
    @Test
    func removeAbnormal() {
        var x = [0, .infinity, .nan] as Array<Float64>
        Guard.removeAbnormal(of: &x)
        #expect(x.allSatisfy(0.0.isEqual(to:)))
    }
}
