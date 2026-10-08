//
//  Integrators.swift
//  MUTE
//
//  Created by Kota on 6/15/26.
//
import typealias Numerics.Complex128
public enum Integrators {
    public protocol `1D`: Sendable {
        func integrate(over range: ClosedRange<Float64>, integrand ƒ: (Float64) -> Float64) -> Float64
        func integrate(over range: ClosedRange<Float64>, integrand ƒ: (Float64) -> Complex128) -> Complex128
    }
    public protocol `2D`: Sendable {
        func integrate(over area: (u: ClosedRange<Float64>, v: ClosedRange<Float64>), integrand ƒ: (Float64, Float64) -> Float64) -> Float64
        func integrate(over area: (u: ClosedRange<Float64>, v: ClosedRange<Float64>), integrand ƒ: (Float64, Float64) -> Complex128) -> Complex128
    }
}
