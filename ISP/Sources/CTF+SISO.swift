//
//  CTF+Estimators.swift
//  MUTE
//
//  Created by Kota on 9/29/26.
//
@preconcurrency import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Numerics.Complex128
import typealias Synchronization.Atomic
import typealias Synchronization.Mutex
import typealias KSP.rls_complex_filterbank_t
import func KSP.rls_complex_filter_create
import func KSP.rls_filter_destroy
import func KSP.rls_filter_reset
import func KSP.rls_filter_lambda
import func KSP.rls_filter_error
import typealias ESP.DFT
import AltVec
extension CTF {
    public enum SISO {}
}
extension CTF.SISO {
    public protocol `Protocol`: Sendable {
        func update(sample: Int,
                    x: some AccelerateBuffer<Float64>,
                    y: some AccelerateBuffer<Float64>) throws
        func reset()
        var snapshot: CTF.Snapshot { get }
    }
    public protocol FrequencyDomain<DFT>: `Protocol` {
        associatedtype DFT: ESP.DFT.`Protocol`
        func update(sample: Int, X: UnsafeMutableBufferPointer<Complex128>, Y: UnsafeMutableBufferPointer<Complex128>, W: UnsafeMutableBufferPointer<Complex128>)
        var dft: DFT { get }
        var workspace: Int { get }
    }
}
extension CTF.SISO.FrequencyDomain {
    public func update(sample: Int,
                       x: some AccelerateBuffer<Float64>,
                       y: some AccelerateBuffer<Float64>) throws {
        let count = dft.count
        withUnsafeTemporaryAllocation(of: Complex128.self, capacity: 2 * count + workspace) {
            let X = UnsafeMutableBufferPointer(rebasing: $0[0 * count ..< 1 * count])
            let Y = UnsafeMutableBufferPointer(rebasing: $0[1 * count ..< 2 * count])
            x.withUnsafeBufferPointer { x in
                X.withMemoryRebound(to: Float64.self) {
                    Float64.Copy(x: x.baseAddress.unsafelyUnwrapped, inc: 1,
                                 y: $0.baseAddress.unsafelyUnwrapped.advanced(by: 0), inc: 2, length: count)
                    Float64.Zero(x: $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), inc: 2, length: count)
                }
            }
            y.withUnsafeBufferPointer { y in
                Y.withMemoryRebound(to: Float64.self) {
                    Float64.Copy(x: y.baseAddress.unsafelyUnwrapped, inc: 1,
                                 y: $0.baseAddress.unsafelyUnwrapped.advanced(by: 0), inc: 2, length: count)
                    Float64.Zero(x: $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), inc: 2, length: count)
                }
            }
            dft.forward(x: X.baseAddress.unsafelyUnwrapped, ld: count,
                        y: X.baseAddress.unsafelyUnwrapped, ld: count,
                        nrhs: 2) // DFT two signal in oneshot
            update(sample: sample, X: X, Y: Y, W: .init(rebasing: $0.dropFirst(2 * count)))
        }
    }
}
extension CTF.SISO {
    public final class RLS<DFT: ESP.DFT.`Protocol`>: FrequencyDomain, @unchecked Sendable {
        @usableFromInline
        let core: UnsafeMutablePointer<rls_complex_filterbank_t>
        public let dft: DFT
        public let statistics: Mutex<CTF.Snapshot>
        public let average: Atomic<Float64>
        @inlinable
        init(dft transformer: DFT, count: Int, λ: Float64) { // count = filter order
            dft = transformer
            core = rls_complex_filter_create(count, dft.count / 2 + 1) // 0 ~ Nyquist
            statistics = .init(.init(angular: .init(unsafeUninitializedCapacity: dft.count / 2 + 1) { [dft] in
                $1 = $0.count
                vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
                vDSP.divide($0, .init(dft.count), result: &$0)
            }))
            average = .init(λ)
            rls_filter_lambda(core, λ)
        }
        deinit {
            rls_filter_destroy(core)
        }
    }
}
extension CTF.SISO.RLS {
    @inlinable
    public convenience init(width: Int, count: Int, λ: Float64 = 1) where DFT == ESP.DFT.BFS {
        self.init(dft: .init(count: width), count: count, λ: λ)
    }
}
extension CTF.SISO.RLS {
    @inlinable
    public var λ: Float64 {
        get {
            average.load(ordering: .relaxed)
        }
        set {
            average.store(newValue, ordering: .relaxed)
            rls_filter_lambda(core, newValue)
        }
    }
}
extension CTF.SISO.RLS {
    @inlinable
    public var workspace: Int {
        2 * ( dft.count / 2 + 1 )
    }
    @inlinable
    public func update(sample: Int,
                       X: UnsafeMutableBufferPointer<Complex128>,
                       Y: UnsafeMutableBufferPointer<Complex128>,
                       W: UnsafeMutableBufferPointer<Complex128>) {
        let count = dft.count / 2 + 1
        let X = UnsafeMutableBufferPointer(rebasing: X.prefix(count))
        let Y = UnsafeMutableBufferPointer(rebasing: Y.prefix(count))
        let Ŷ = UnsafeMutableBufferPointer(rebasing: W[0*count..<1*count])
        let Ε = UnsafeMutableBufferPointer(rebasing: W[1*count..<2*count])
        rls_filter_error(core,
                         .init(X.baseAddress.unsafelyUnwrapped), 1,
                         .init(Y.baseAddress.unsafelyUnwrapped), 1,
                         .init(Ε.baseAddress), 1,
                         1) // 1 timestep
        statistics.withLock { [λ] in
            // timestamp τ
            $0.τ = sample
            // E[ε]
            $0.ε.withUnsafeMutableBufferPointer {
                $0.withMemoryRebound(to: Float64.self) { t in
                    assert(t.count == 2 * count)
                    Ε.withMemoryRebound(to: Float64.self) {
                        vDSP.linearInterpolate($0, t, using: λ, result: &t[t.startIndex..<t.endIndex])
                    }
                }
            }
            // E[εε^H]
            $0.Sεε.withUnsafeMutableBufferPointer { t in
                assert(t.count == count)
                Ŷ.withMemoryRebound(to: Float64.self) {
                    Complex128.mags(Ε.baseAddress.unsafelyUnwrapped, 1, $0.baseAddress.unsafelyUnwrapped, 1, count)
                    vDSP.linearInterpolate($0, t, using: λ, result: &t[t.startIndex..<t.endIndex])
                }
            }
            // Ŷ_k ← Y - Ε
            Complex128.Sub(x: Y.baseAddress.unsafelyUnwrapped, inc: 1,
                           y: Ε.baseAddress.unsafelyUnwrapped, inc: 1,
                           z: Ŷ.baseAddress.unsafelyUnwrapped, inc: 1,
                           length: count)
            // E[x]
            $0.x.withUnsafeMutableBufferPointer {
                $0.withMemoryRebound(to: Float64.self) { t in
                    assert(t.count == 2 * count)
                    X.withMemoryRebound(to: Float64.self) {
                        vDSP.linearInterpolate($0, t, using: λ, result: &t[t.startIndex..<t.endIndex])
                    }
                }
            }
            // E[xx^h]
            $0.Sxx.withUnsafeMutableBufferPointer { t in
                assert(t.count == count)
                Ε.withMemoryRebound(to: Float64.self) {
                    Complex128.mags(X.baseAddress.unsafelyUnwrapped, 1, $0.baseAddress.unsafelyUnwrapped, 1, X.count)
                    vDSP.linearInterpolate($0, t, using: λ, result: &t[t.startIndex..<t.endIndex])
                }
            }
            // E[y]
            $0.y.withUnsafeMutableBufferPointer {
                $0.withMemoryRebound(to: Float64.self) { t in
                    assert(t.count == 2 * count)
                    Ŷ.withMemoryRebound(to: Float64.self) {
                        assert($0.count == 2 * count)
                        vDSP.linearInterpolate($0, t, using: λ, result: &t[t.startIndex..<t.endIndex])
                    }
                }
            }
            // E[yy^H]
            $0.Syy.withUnsafeMutableBufferPointer { t in
                assert(t.count == count)
                Ε.withMemoryRebound(to: Float64.self) {
                    assert($0.count == 2 * count)
                    Complex128.mags(Ŷ.baseAddress.unsafelyUnwrapped, 1, $0.baseAddress.unsafelyUnwrapped, 1, Ŷ.count)
                    vDSP.linearInterpolate($0, t, using: λ, result: &t[t.startIndex..<t.endIndex])
                }
            }
            // E[yx^H]
            Complex128.Mul(conjx: X.baseAddress.unsafelyUnwrapped, inc: 1,
                           y: Ŷ.baseAddress.unsafelyUnwrapped, inc: 1,
                           z: Ε.baseAddress.unsafelyUnwrapped, inc: 1,
                           length: count)
            $0.Syx.withUnsafeMutableBufferPointer {
                $0.withMemoryRebound(to: Float64.self) { t in
                    assert(t.count == 2 * count)
                    Ε.withMemoryRebound(to: Float64.self) {
                        assert($0.count == 2 * count)
                        vDSP.linearInterpolate($0, t, using: λ, result: &t[t.startIndex..<t.endIndex])
                    }
                }
            }
        }
    }
    @inlinable
    public func reset() {
        statistics.withLock {
            $0 = .init(angular: $0.ω)
        }
        rls_filter_reset(core)
    }
    @inlinable
    public var snapshot: CTF.Snapshot {
        statistics.withLock(\.self)
    }
}
