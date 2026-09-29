//
//  Extension.swift
//  MUTE
//
//  Created by Kota on 6/10/26.
//
import Testing
import Foundation
@testable import PSP
@Suite
struct ExtensionTestCases {
    @Test(TimeLimitTrait.timeLimit(.minutes(1)))
    func parallel() {
        let query = repeatElement(0.0 ... 1.0, count: 100).map(Float64.random(in:))
        let result = Array<Float64>(unsafeUninitializedCapacity: query.count) { memory, length in
            DispatchQueue.parallel(for: memory.count) {
                memory[$0] = j0(query[$0])
                Thread.sleep(forTimeInterval: 1)
            }
            length = memory.count
        }
        #expect(zip(result, query.lazy.map(j0)).allSatisfy(==))
    }
}
