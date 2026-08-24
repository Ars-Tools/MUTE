//
//  Hilbert.swift
//  MUTE
//
//  Created by Kota on 10/30/25.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Numerics.Complex128
import AltVec
public enum Hilbert {}
extension Hilbert {
    public enum Domain {
        case Time
        case Freq
    }
}
extension Hilbert {
    public struct Transformer<RawValue: DFT.`Protocol`> {
        @usableFromInline
        let rawValue: RawValue
        @inlinable
        init(dft: RawValue) {
            rawValue = dft
        }
    }
}
extension Hilbert.Transformer where RawValue == DFT.BFS {
    @inlinable
    public init(count: Int) {
        self.init(dft: .init(count: count))
    }
}
extension Hilbert.Transformer {
    @inlinable
    public func Analytic(signal: some AccelerateBuffer<Float64>) -> Array<Complex128> {
        .init(unsafeUninitializedCapacity: signal.count) {
            $1 = $0.count
            $0.withMemoryRebound(to: Float64.self) { zc in
                signal.withUnsafeBufferPointer {
                    Float64.Copy(x: $0.baseAddress.unsafelyUnwrapped, inc: 1,
                                 y: zc.baseAddress.unsafelyUnwrapped, inc: 2,
                                 length: $0.count)
                }
                Float64.Zero(x: zc.baseAddress.unsafelyUnwrapped.advanced(by: 1), inc: 2, length: signal.count)
            }
            rawValue.hilbert(x: $0.baseAddress.unsafelyUnwrapped, inc: 1,
                             y: $0.baseAddress.unsafelyUnwrapped, inc: 1,
                             domain: .Time)
        }
    }
}
extension Hilbert.Transformer {
    @inlinable
    public func MinimumPhase(response: some AccelerateBuffer<Float64>) -> Array<Complex128> {
        .init(unsafeUninitializedCapacity: response.count) {
            $1 = $0.count
            $0.withMemoryRebound(to: Float64.self) { zc in
                response.withUnsafeBufferPointer {
                    Float64.Copy(x: $0.baseAddress.unsafelyUnwrapped, inc: 1,
                                 y: zc.baseAddress.unsafelyUnwrapped, inc: 2,
                                 length: $0.count)
                }
                Float64.Zero(x: zc.baseAddress.unsafelyUnwrapped.advanced(by: 1), inc: 2, length: response.count)
            }
            Complex128.log($0.baseAddress.unsafelyUnwrapped, 1, $0.baseAddress.unsafelyUnwrapped, 1, $1)
            $0.withMemoryRebound(to: Float64.self) {
                vDSP.invertedClip($0, to: 0...0, result: &$0[0..<$0.count])
            }
            rawValue.hilbert(x: $0.baseAddress.unsafelyUnwrapped, inc: 1,
                             y: $0.baseAddress.unsafelyUnwrapped, inc: 1,
                             domain: .Freq)
            Complex128.exp($0.baseAddress.unsafelyUnwrapped, 1, $0.baseAddress.unsafelyUnwrapped, 1, $1)
        }
    }
}
extension Hilbert {
    @inlinable
    public static func Analytic(signal: some AccelerateBuffer<Float64>) -> Array<Complex128> {
        Transformer(dft: DFT.DFS(count: signal.count)).Analytic(signal: signal)
    }
}
extension Hilbert {
    @inlinable
    public static func MinimumPhase(response: some AccelerateBuffer<Float64>) -> Array<Complex128> {
        Transformer(dft: DFT.DFS(count: response.count)).MinimumPhase(response: response)
    }
}
extension DFT.`Protocol` {
    @inlinable
    public func hilbert(x: UnsafePointer<Complex128>, inc incx: Int,
                        y: UnsafeMutablePointer<Complex128>, inc incy: Int,
                        domain: Hilbert.Domain) {
        switch domain {
        case.Time:
            forward(x: x, inc: incx, y: y, inc: incy)
            Complex128.Scale(x: y.advanced(by: 1), inc: incy,
                             y: 2,
                             z: y.advanced(by: 1), inc: incy,
                             length: (count-1)/2)
            Complex128.Zero(x: y.advanced(by: count/2+1), inc: incy, length: count-count/2-1)
            inverse(x: y, inc: incy, y: y, inc: incy)
        case.Freq:
            inverse(x: x, inc: incx, y: y, inc: incy)
            Complex128.Scale(x: y.advanced(by: 1), inc: incy,
                             y: 2,
                             z: y.advanced(by: 1), inc: incy,
                             length: (count-1)/2)
            Complex128.Zero(x: y.advanced(by: count/2+1), inc: incy, length: count-count/2-1)
            forward(x: y, inc: incy, y: y, inc: incy)
        }
    }
    @inlinable
    public func hilbert(_ x: UnsafeBufferPointer<Complex128>, domain: Hilbert.Domain = .Time) -> Array<Complex128> {
        .init(unsafeUninitializedCapacity: x.count) {
            hilbert(x: x.baseAddress.unsafelyUnwrapped, inc: 1,
                    y: $0.baseAddress.unsafelyUnwrapped, inc: 1,
                    domain: domain)
            $1 = $0.count
        }
    }
    @_disfavoredOverload
    @inlinable
    public func hilbert(_ x: some AccelerateBuffer<Complex128>, domain: Hilbert.Domain = .Time) -> Array<Complex128> {
        x.withUnsafeBufferPointer { hilbert($0, domain: domain) }
    }
    @inlinable
    public func hilbert(_ x: some AccelerateBuffer<Float64>, domain: Hilbert.Domain = .Time) -> Array<Complex128> {
        x.withUnsafeTemporaryComplexBuffer { hilbert($0, domain: domain) }
    }
}
