//
//  Utils+Kernel.swift
//  MUTE
//
//  Created by Kota on 8/27/R7.
//
import protocol Accelerate.AccelerateBuffer
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
import typealias Numerics.Complex128
import typealias Complex.complex128_t
import func MKL.vDSP_clr
import func MKL.vDSP_mul
import func MKL.vDSP_ztoc
import func BLAS.copy
import func BLAS.cblas_ddot
import func BLAS.gbmv
import func BLAS.gemv
import func LAPACK.gels
import func vFORCE.vvsqrt
import func vFORCE.vvcospi
import func vFORCE.vvsinpi
import func KSP.wiener
import func simd.recip
// new version
extension Utils {
    @inlinable
    public static func Fit(response: (some AccelerateBuffer<Float64>, some AccelerateBuffer<Float64>),
                           frequency: some AccelerateBuffer<Float64>,
                           confidence: Optional<some AccelerateBuffer<Float64>>,
                           iteration: Int,
                           kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        let ω = frequency.count
        assert(ω == response.0.count)
        assert(ω == response.1.count)
        let m = response.0.count + response.1.count
        let n = 1 + kernel.b + kernel.a
        let h = max(kernel.b, kernel.a)
        let l = gels(m, n, 1,
                     .none as Optional<UnsafeMutablePointer<Float64>>, m, .N,
                     .none as Optional<UnsafeMutablePointer<Float64>>, max(m, n),
                     .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + max(m, n) + m * h + max(m, l)) {
            let A = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let b = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(max(m, n)))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + max(m, n)).prefix(m * h))
            let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + max(m, n) + m * h).prefix(max(m, l)))
            
            // Z (table)
            for k in 0..<h {
                vDSP.multiply(.init(-2*k-2), frequency, result: &w[0..<ω])
                vForce.cosPi(w[0..<ω], result: &z[k*m+0..<k*m+ω])
                vForce.sinPi(w[0..<ω], result: &z[k*m+ω..<k*m+m])
            }
            
            // initial
            vDSP.add(multiplication: (response.0, response.0), multiplication: (response.1, response.1), result: &w[0..<ω])
            // IDFT[||H||^2] → A
            A[0] = 1
            gemv(ω, kernel.a, recip(vDSP.sum(w[0..<ω])),
                 z.baseAddress.unsafelyUnwrapped, m, .T,
                 w.baseAddress.unsafelyUnwrapped, 1,
                 0,
                 A.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1)
            // AR(c)
            vDSP.negative(A[1..<1+kernel.a], result: &w[0..<kernel.a])
            b[0] = 1
            vDSP.clear(&b[1..<1+kernel.b])
            wiener(A.baseAddress.unsafelyUnwrapped,
                   w.baseAddress.unsafelyUnwrapped,
                   b.baseAddress.unsafelyUnwrapped.advanced(by: 1 + kernel.b),
                   w.baseAddress.unsafelyUnwrapped.advanced(by: 0 + kernel.a),
                   kernel.a)
            for () in repeatElement((), count: iteration) {
                // DFT(a)
                vDSP.fill(&A[0..<ω], with: 1)
                vDSP.clear(&A[ω..<m])
                gemv(m, kernel.a, 1,
                     z.baseAddress.unsafelyUnwrapped, m, .N,
                     b.baseAddress.unsafelyUnwrapped.advanced(by: 1 + kernel.b), 1,
                     1,
                     A.baseAddress.unsafelyUnwrapped, 1)
                vDSP.add(multiplication: (A[0..<ω], A[0..<ω]), multiplication: (A[ω..<m], A[ω..<m]), result: &A[0..<ω])
                if let confidence {
                    precondition(confidence.count == ω)
                    vDSP.divide(confidence, A[0..<ω], result: &A[0..<ω])
                    vForce.sqrt(A[0..<ω], result: &A[0..<ω])
                } else {
                    vForce.rsqrt(A[0..<ω], result: &A[0..<ω])
                }
                vDSP.clip(A[0..<ω], to: -.greatestFiniteMagnitude ... .greatestFiniteMagnitude, result: &A[0..<ω])
                vDSP.invertedClip(A[0..<ω], to: 0...0, result: &A[0..<ω])
                vDSP.clear(&A[ω..<m])
                // A
                for k in 0..<kernel.b {
                    let j = 1 + k
                    vDSP.multiply(A[0..<ω], z[k*m+0..<k*m+ω], result: &A[j*m+0..<j*m+ω])
                    vDSP.multiply(A[0..<ω], z[k*m+ω..<k*m+m], result: &A[j*m+ω..<j*m+m])
                }
                for k in 0..<kernel.a {
                    let j = 1 + k + kernel.b
                    vDSP.subtract(multiplication: (response.1, z[k*m+ω..<k*m+m]),
                                  multiplication: (response.0, z[k*m+0..<k*m+ω]),
                                  result: &A[j*m+0..<j*m+ω])
                    vDSP.multiply(A[0..<ω], A[j*m+0..<j*m+ω], result: &A[j*m+0..<j*m+ω])
                    vDSP.add(multiplication: (response.1, z[k*m+0..<k*m+ω]),
                             multiplication: (response.0, z[k*m+ω..<k*m+m]),
                             result: &A[j*m+ω..<j*m+m])
                    vDSP.multiply(A[0..<ω], A[j*m+ω..<j*m+m], result: &A[j*m+ω..<j*m+m])
                    vDSP.negative(A[j*m+ω..<j*m+m], result: &A[j*m+ω..<j*m+m])
                }
                
                // b
                vDSP.multiply(A[0..<ω], response.0, result: &b[0..<ω])
                vDSP.multiply(A[0..<ω], response.1, result: &b[ω..<m])
                
                let s = gels(m, n, 1,
                             A.baseAddress, m, .N,
                             b.baseAddress, max(m, n),
                             w.baseAddress, l)
                assert(s == 0)
            }
            
            return (
                .init(b.prefix(1 + kernel.b)),
                .init(arrayLiteral: 1) + b.dropFirst(1 + kernel.b).prefix(kernel.a)
            )
        }
    }
    @inlinable
    public static func Fit(response: (some AccelerateBuffer<Float64>, some AccelerateBuffer<Float64>),
                           frequency: some AccelerateBuffer<Float64>,
                           confidence: Optional<some AccelerateBuffer<Float64>>,
                           wiener c: Int,
                           kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        let ω = frequency.count
        assert(ω == response.0.count)
        assert(ω == response.1.count)
        precondition(c < ω, "lpc dimension is too high")
        let m = response.0.count + response.1.count
        let n = 1 + kernel.b + kernel.a
        let h = max(c, kernel.b, kernel.a)
        let l = gels(m, n, 1,
                     .none as Optional<UnsafeMutablePointer<Float64>>, m, .N,
                     .none as Optional<UnsafeMutablePointer<Float64>>, max(m, n),
                     .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + max(m, n) + m * h + max(m, l)) {
            let A = UnsafeMutableBufferPointer(rebasing: $0.prefix(m * n))
            let b = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n).prefix(max(m, n)))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + max(m, n)).prefix(m * h))
            let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(m * n + max(m, n) + m * h).prefix(max(m, l)))
            
            // Z (table)
            for k in 0..<h {
                vDSP.multiply(.init(-2*k-2), frequency, result: &w[0..<ω])
                vForce.cosPi(w[0..<ω], result: &z[k*m+0..<k*m+ω])
                vForce.sinPi(w[0..<ω], result: &z[k*m+ω..<k*m+m])
            }
            // C
            vDSP.add(multiplication: (response.0, response.0), multiplication: (response.1, response.1), result: &w[0..<ω])
            // IDFT(H)
            b[0] = 1
            gemv(ω, c, recip(vDSP.sum(w[0..<ω])),
                 z.baseAddress.unsafelyUnwrapped, m, .T,
                 w.baseAddress.unsafelyUnwrapped, 1,
                 0,
                 b.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1)
            // AR(c)
            vDSP.negative(b[1..<c+1], result: &w[0..<c])
            wiener(b.baseAddress.unsafelyUnwrapped,
                   w.baseAddress.unsafelyUnwrapped,
                   A.baseAddress.unsafelyUnwrapped,
                   w.baseAddress.unsafelyUnwrapped.advanced(by: c),
                   c)
            // DFT(p)
            vDSP.fill(&w[0..<ω], with: 1)
            vDSP.clear(&w[ω..<m])
            gemv(m, c, 1,
                 z.baseAddress.unsafelyUnwrapped, m, .N,
                 A.baseAddress.unsafelyUnwrapped, 1,
                 1,
                 w.baseAddress.unsafelyUnwrapped, 1)
            vDSP.add(multiplication: (w[0..<ω], w[0..<ω]), multiplication: (w[ω..<m], w[ω..<m]), result: &A[0..<ω])
            if let confidence {
                precondition(confidence.count == ω)
                vDSP.divide(confidence, A[0..<ω], result: &A[0..<ω])
                vForce.sqrt(A[0..<ω], result: &A[0..<ω])
            } else {
                vForce.rsqrt(A[0..<ω], result: &A[0..<ω])
            }
            vDSP.invertedClip(A[0..<ω], to: 0...0, result: &A[0..<ω])
            vDSP.clear(&A[ω..<m])
            for k in 0..<kernel.b {
                let j = 1 + k
                vDSP.multiply(A[0..<ω], z[k*m+0..<k*m+ω], result: &A[j*m+0..<j*m+ω])
                vDSP.multiply(A[0..<ω], z[k*m+ω..<k*m+m], result: &A[j*m+ω..<j*m+m])
            }
            for k in 0..<kernel.a {
                let j = 1 + k + kernel.b
                vDSP.subtract(multiplication: (response.1, z[k*m+ω..<k*m+m]),
                              multiplication: (response.0, z[k*m+0..<k*m+ω]),
                              result: &A[j*m+0..<j*m+ω])
                vDSP.multiply(A[0..<ω], A[j*m+0..<j*m+ω], result: &A[j*m+0..<j*m+ω])
                vDSP.add(multiplication: (response.1, z[k*m+0..<k*m+ω]),
                         multiplication: (response.0, z[k*m+ω..<k*m+m]),
                         result: &A[j*m+ω..<j*m+m])
                vDSP.multiply(A[0..<ω], A[j*m+ω..<j*m+m], result: &A[j*m+ω..<j*m+m])
                vDSP.negative(A[j*m+ω..<j*m+m], result: &A[j*m+ω..<j*m+m])
            }
            
            // b
            vDSP.multiply(A[0..<ω], response.0, result: &b[0..<ω])
            vDSP.multiply(A[0..<ω], response.1, result: &b[ω..<m])
            
            let s = gels(m, n, 1,
                         A.baseAddress, m, .N,
                         b.baseAddress, max(m, n),
                         w.baseAddress, l)
            assert(s == 0)
            return (
                .init(b.prefix(1 + kernel.b)),
                .init(arrayLiteral: 1) + b.dropFirst(1 + kernel.b).prefix(kernel.a)
            )
        }
    }
    @inlinable
    public static func Fit(response: (some AccelerateBuffer<Float64>, some AccelerateBuffer<Float64>),
                           confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                           wiener: Int = 0,
                           kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        Fit(response: response,
            frequency: Array<Float64>(unsafeUninitializedCapacity: max(response.0.count, response.1.count)) {
            $1 = $0.count
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
            vDSP.divide($0, .init($1), result: &$0)
        }, confidence: confidence,
            wiener: wiener,
            kernel: kernel)
    }
}
extension Utils {
    @inlinable
    public static func Fit(response: (some AccelerateBuffer<Float64>, some AccelerateBuffer<Float64>),
                           confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                           iteration: Int,
                           kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        Fit(response: response,
            frequency: Array<Float64>(unsafeUninitializedCapacity: max(response.0.count, response.1.count)) {
            $1 = $0.count
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
            vDSP.divide($0, .init($1), result: &$0)
        }, confidence: confidence,
            iteration: iteration,
            kernel: kernel)
    }
}
extension Utils {
    @inlinable
    public static func Fit(response: some AccelerateBuffer<Complex128>,
                           frequency: some AccelerateBuffer<Float64>,
                           confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                           iteration: Int = 1,
                           kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * response.count) {
            let r = $0.extracting(0*response.count..<1*response.count)
            let i = $0.extracting(1*response.count..<2*response.count)
            response.withUnsafeBufferPointer {
                $0.withMemoryRebound(to: Float64.self) {
                    copy(response.count, $0.baseAddress.unsafelyUnwrapped.advanced(by: 0), 2, r.baseAddress.unsafelyUnwrapped, 1)
                    copy(response.count, $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2, i.baseAddress.unsafelyUnwrapped, 1)
                }
            }
            return Fit(response: (r, i),
                       frequency: frequency,
                       confidence: confidence,
                       iteration: iteration,
                       kernel: kernel)
        }
    }
    @inlinable
    public static func Fit(response: some AccelerateBuffer<Complex128>,
                           confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                           iteration: Int = 1,
                           kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        Fit(response: response,
            frequency: Array<Float64>(unsafeUninitializedCapacity: response.count) {
            $1 = $0.count
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
            vDSP.divide($0, .init($1), result: &$0)
        },
            confidence: confidence,
            iteration: iteration,
            kernel: kernel)
    }
}


extension Utils {
    @inlinable
    public static func Fit(response: some AccelerateBuffer<Complex128>,
                           frequency: some AccelerateBuffer<Float64>,
                           confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                           wiener: Int = 0,
                           kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: 2 * response.count) {
            let r = $0.extracting(0*response.count..<1*response.count)
            let i = $0.extracting(1*response.count..<2*response.count)
            response.withUnsafeBufferPointer {
                $0.withMemoryRebound(to: Float64.self) {
                    copy(response.count, $0.baseAddress.unsafelyUnwrapped.advanced(by: 0), 2, r.baseAddress.unsafelyUnwrapped, 1)
                    copy(response.count, $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2, i.baseAddress.unsafelyUnwrapped, 1)
                }
            }
            return Fit(response: (r, i),
                       frequency: frequency,
                       confidence: confidence,
                       wiener: wiener,
                       kernel: kernel)
        }
    }
    @inlinable
    public static func Fit(response: some AccelerateBuffer<Complex128>,
                           confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                           wiener: Int = 0,
                           kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        Fit(response: response,
            frequency: Array<Float64>(unsafeUninitializedCapacity: response.count) {
            $1 = $0.count
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
            vDSP.divide($0, .init($1), result: &$0)
        }, confidence: confidence,
            wiener: wiener,
            kernel: kernel)
    }
}

extension Utils {
    @inlinable // real-number constraint ls
    static func fit(response: (some AccelerateBuffer<Float64>, some AccelerateBuffer<Float64>),
                    frequency: some AccelerateBuffer<Float64>,
                    confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                    kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        let p = min(response.0.count, response.1.count) // sub-block
        assert(p == response.0.count)
        assert(p == response.1.count)
        let m = 2 * p
        let n = 1 + kernel.b + kernel.a
        let l = gels(m, n, 1,
                     .none as Optional<UnsafeMutablePointer<Float64>>, m, .N,
                     .none as Optional<UnsafeMutablePointer<Float64>>, max(m, n),
                     .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + max(m, n) + max(m, l)) {
            let A = $0.extracting(0 * m * n ..< 1 * m * n)
            let b = $0.extracting(1 * m * n ..< 1 * m * n + max(m, n))
            let w = $0.extracting(1 * m * n + max(m, n) ..< 1 * m * n + max(m, n) + max(m, l))
            switch confidence {
            case.some(let weight):
                vForce.sqrt(weight, result: &A[0..<p])
            case.none:
                vDSP.fill(&A[0..<p], with: 1)
            }
            vDSP.clear(&A[p..<m])
            for k in 0..<max(kernel.b, kernel.a) {
                vDSP.multiply(.init(-2*k-2), frequency, result: &w[0..<p])
                vForce.cosPi(w[0..<p], result: &b[0*p..<1*p])
                vForce.sinPi(w[0..<p], result: &b[1*p..<2*p])
                vDSP.multiply(A[0..<p], b[0*p..<1*p], result: &b[0*p..<1*p])
                vDSP.multiply(A[0..<p], b[1*p..<2*p], result: &b[1*p..<2*p])
                if k < kernel.b {
                    let col = m * ( 1 + k )
                    vDSP.negative(b[0..<m], result: &A[col ..< col + m])
                }
                if k < kernel.a {
                    let col = m * ( 1 + k + kernel.b )
                    vDSP.subtract(multiplication: (b[0*p..<1*p], response.0),
                                  multiplication: (b[1*p..<2*p], response.1),
                                  result: &A[col + 0 * p ..< col + 1 * p])
                    vDSP.add(multiplication: (b[0*p..<1*p], response.1),
                             multiplication: (b[1*p..<2*p], response.0),
                             result: &A[col + 1 * p ..< col + 2 * p])
                }
            }
            vDSP.negative(A[0..<p], result: &A[0..<p])
            vDSP.negative(response.0, result: &b[0*p..<1*p])
            vDSP.negative(response.1, result: &b[1*p..<2*p])
            let r = gels(m, n, 1,
                         A.baseAddress, m, .N,
                         b.baseAddress, max(m, n),
                         w.baseAddress, l)
            assert(0 == r)
            return (
                Array(b.prefix(1 + kernel.b)),
                Array(arrayLiteral: 1) + b.dropFirst(1 + kernel.b).prefix(kernel.a)
            )
        }
    }
    @inlinable // real-number constraint
    static func fit(response: (some AccelerateBuffer<Float64>, some AccelerateBuffer<Float64>),
                    confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                    kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        fit(response: response,
            frequency: Array(unsafeUninitializedCapacity: max(response.0.count, response.1.count)) {
            $1 = $0.count
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
            vDSP.divide($0, .init($1), result: &$0)
        }, kernel: kernel)
    }
    @inlinable // real-number constraint
    static func fit(response: (some AccelerateBuffer<Float64>, some AccelerateBuffer<Float64>),
                    frequency: some AccelerateBuffer<Float64>,
                    confidence: Optional<some AccelerateBuffer<Float64>>,
                    kernel: (b: Int, a: Int), iteration: Int) -> (Array<Float64>, Array<Float64>) {
        let ω = frequency.count
        precondition(ω == response.0.count)
        precondition(ω == response.1.count)
        let m = response.0.count + response.1.count
        let n = 1 + kernel.b + kernel.a
        let l = gels(m, n, 1,
                     .none as Optional<UnsafeMutablePointer<Float64>>, m, .N,
                     .none as Optional<UnsafeMutablePointer<Float64>>, max(m, n),
                     .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: m * n + max(m, n) + m * max(kernel.b, kernel.a) + l) {
            let w = $0.extracting(0..<l)
            let A = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(l).prefix(m * n))
            let z = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(l + m * n).prefix(m * max(kernel.b, kernel.a)))
            let b = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(l + m * n + m * max(kernel.b, kernel.a)).prefix(max(m, n)))
            // table
            for k in 0..<max(kernel.b, kernel.a) {
                vDSP.multiply(.init(-2*k-2), frequency, result: &A[0..<ω])
                vForce.cosPi(A[0..<ω], result: &z[k*m+0..<k*m+ω])
                vForce.sinPi(A[0..<ω], result: &z[k*m+ω..<k*m+m])
            }
            // initial
            vDSP.clear(&b[0..<n])
            
            // compute
            for _ in 0..<iteration {
                // DFT(a)
                vDSP.fill(&A[0..<ω], with: 1)
                vDSP.clear(&A[ω..<m])
                gemv(m, kernel.a,
                     1,
                     z.baseAddress.unsafelyUnwrapped, m, .N,
                     b.baseAddress.unsafelyUnwrapped.advanced(by: 1 + kernel.b), 1,
                     1,
                     A.baseAddress.unsafelyUnwrapped, 1)
                // 1/|a|
                vDSP.add(multiplication: (A[0..<ω], A[0..<ω]), multiplication: (A[ω..<m], A[ω..<m]), result: &A[0..<ω])
                
                // spectrum
//                vDSP.add(multiplication: (response.0, response.0), multiplication: (response.1, response.1), result: &A[ω..<m])
//                vDSP.divide(A[0..<ω], A[ω..<m], result: &A[0..<ω])
                
                vForce.sqrt(A[0..<ω], result: &A[0..<ω])
                vDSP.invertedClip(A[0..<ω], to: 0...0, result: &A[0..<ω])
                
                // A[0] (weight) = sqrt(confidence) / |a|
                if let confidence {
                    vForce.sqrt(confidence, result: &A[ω..<m])
                    vDSP.multiply(A[0..<ω], A[ω..<m], result: &A[0..<ω])
                }
                vDSP.clear(&A[ω..<m])
                
                // A[1…] = diag(A[:,0]) • [z|-z•response]
                for k in 0..<max(kernel.b, kernel.a) {
                    vDSP.multiply(A[0..<ω], z[k*m+0..<k*m+ω], result: &b[0..<ω])
                    vDSP.multiply(A[0..<ω], z[k*m+ω..<k*m+m], result: &b[ω..<m])
                    if k < kernel.b {
                        let col = m * ( 1 + k )
                        A[col+0..<col+ω].update(fromContentsOf: b[0..<ω])
                        A[col+ω..<col+m].update(fromContentsOf: b[ω..<m])
                    }
                    if k < kernel.a {
                        let col = m * ( 1 + k + kernel.b )
                        vDSP.subtract(multiplication: (response.0, b[0..<ω]),
                                      multiplication: (response.1, b[ω..<m]),
                                      result: &A[col+0..<col+ω])
                        vDSP.add(multiplication: (response.1, b[0..<ω]),
                                 multiplication: (response.0, b[ω..<m]),
                                 result: &A[col+ω..<col+m])
                        vDSP.negative(A[col..<col+m], result: &A[col..<col+m])
                    }
                }
                
                // b = diag(A[:,0]) • response
                vDSP.multiply(A[0..<ω], response.0, result: &b[0..<ω])
                vDSP.multiply(A[0..<ω], response.1, result: &b[ω..<m])
                
                // solve
                let s = gels(m, n, 1,
                             A.baseAddress, m, .N,
                             b.baseAddress, max(m, n),
                             w.baseAddress, l)
                assert(s == 0)
            }
            return (
                Array(b.prefix(1 + kernel.b)),
                Array(arrayLiteral: 1) + b.dropFirst(1 + kernel.b).prefix(kernel.a)
            )
        }
    }
    @inlinable
    public static func fit(response: some AccelerateBuffer<Complex128>,
                           frequency: some AccelerateBuffer<Float64>,
                           confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                           kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        let m = min(response.count, frequency.count)
        assert(SIMD2(response.count, frequency.count) == .init(repeating: m))
        let n = 1 + kernel.b + kernel.a
        let l = gels(m, n, 1,
                     .none as Optional<UnsafeMutablePointer<complex128_t>>, m, .N,
                     .none as Optional<UnsafeMutablePointer<complex128_t>>, max(m, n),
                     .none as Optional<UnsafeMutablePointer<complex128_t>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Complex128.self, capacity: m * n + max(m, n) + max(m, l)) {
            let A = $0.extracting(0 * m * n ..< 1 * m * n)
            let B = $0.extracting(1 * m * n ..< 1 * m * n + max(m, n))
            let W = $0.extracting(1 * m * n + max(m, n) ..< 1 * m * n + max(m, n) + max(m, l))
            let a = A.withMemoryRebound(to: Float64.self, \.self) // real reference (danger)
            let b = B.withMemoryRebound(to: Float64.self, \.self) // real reference (danger)
            let w = W.withMemoryRebound(to: Float64.self, \.self) // real reference (danger)
            assert(m <= w.count)
            switch confidence {
            case.some(let weight):
                vForce.sqrt(weight, result: &w[0..<m])
            case.none:
                vDSP.fill(&w[0..<m], with: 1)
            }
            // A
            for k in 0..<max(kernel.b, kernel.a) {
                // Z^(-2πjk/M*m) * W -> B[[r, i]]
                vDSP.multiply(.init(-2*k-2), frequency, result: &a[1*m..<2*m])
                vForce.cosPi(a[1*m..<2*m], result: &a[0..<m])
                vDSP_mul(a.baseAddress.unsafelyUnwrapped, 1,
                         w.baseAddress.unsafelyUnwrapped, 1,
                         b.baseAddress.unsafelyUnwrapped.advanced(by: 0), 2, m)
                vForce.sinPi(a[1*m..<2*m], result: &a[0..<m])
                vDSP_mul(a.baseAddress.unsafelyUnwrapped, 1,
                         w.baseAddress.unsafelyUnwrapped, 1,
                         b.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2, m)
                if k < kernel.b {
                    copy(m,
                         B.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                         A.baseAddress.unsafelyUnwrapped.advanced(by: (1 + k) * m).mutableRawPointer, 1)
                }
                if k < kernel.a {
                    response.withUnsafeBufferPointer {
                        gbmv(m, m, 0, 0,
                             .init(.init(r: -1, i: 0)),
                             $0.baseAddress.unsafelyUnwrapped.rawPointer, 1, .N,
                             B.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,                             
                             .init(.init(r:  0, i: 0)),
                             A.baseAddress.unsafelyUnwrapped.advanced(by: (1 + k + kernel.b) * m).mutableRawPointer, 1)
                    }
                }
            }
            copy(m,
                 w.baseAddress.unsafelyUnwrapped, 1,
                 a.baseAddress.unsafelyUnwrapped, 2)
            vDSP_clr(a.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2, m)
            // B
            response.withUnsafeBufferPointer {
                $0.withMemoryRebound(to: Float64.self) {
                    vDSP_mul($0.baseAddress.unsafelyUnwrapped.advanced(by: 0), 2,
                             w.baseAddress.unsafelyUnwrapped, 1,
                             b.baseAddress.unsafelyUnwrapped.advanced(by: 0), 2, m)
                    vDSP_mul($0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2,
                             w.baseAddress.unsafelyUnwrapped, 1,
                             b.baseAddress.unsafelyUnwrapped.advanced(by: 1), 2, m)
                }
            }
            // solve
            let info = gels(m, n, 1,
                            A.baseAddress.map(\.mutableRawPointer), m, .N,
                            B.baseAddress.map(\.mutableRawPointer), max(m, n),
                            W.baseAddress.map(\.mutableRawPointer), l)
            assert(info == 0)
            return (
                Array<Float64>(unsafeUninitializedCapacity: 1 + kernel.b) {
                    $1 = $0.count
                    $0[0] = b[0]
                    copy(kernel.b,
                         b.baseAddress.unsafelyUnwrapped.advanced(by: 0 * kernel.b + 2), 2,
                         $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1)
                },
                Array<Float64>(unsafeUninitializedCapacity: 1 + kernel.a) {
                    $1 = $0.count
                    $0[0] = 1
                    copy(kernel.a,
                         b.baseAddress.unsafelyUnwrapped.advanced(by: 2 * kernel.b + 2), 2,
                         $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1)
                }
            )
        }
    }
    @inlinable
    public static func fit(response: some AccelerateBuffer<Complex128>,
                           confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                           kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
        fit(response: response,
            frequency: Array<Float64>(unsafeUninitializedCapacity: response.count) {
            $1 = $0.count
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
            vDSP.divide($0, .init($1), result: &$0)
        }, confidence: confidence, kernel: kernel)
    }
}
extension Utils {
    @inlinable // real-number constraint
    static func fit(response: (some AccelerateBuffer<Float64>, some AccelerateBuffer<Float64>),
                    confidence: Optional<some AccelerateBuffer<Float64>> = .none as Optional<Array<Float64>>,
                    kernel: (b: Int, a: Int), iteration: Int) -> (Array<Float64>, Array<Float64>) {
        fit(response: response,
            frequency: Array<Float64>(unsafeUninitializedCapacity: max(response.0.count, response.1.count)) {
            $1 = $0.count
            vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
            vDSP.divide($0, .init($1), result: &$0)
        }, confidence: confidence, kernel: kernel, iteration: iteration)
    }
}

@inlinable
public func fit(response: some AccelerateBuffer<Complex128>,
                frequency: some AccelerateBuffer<Float64>,
                confidence: some AccelerateBuffer<Float64>,
                with kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
    let m = min(response.count, frequency.count, confidence.count)
    let n = 1 + kernel.b + kernel.a
    assert(m <= n)
    assert([response.count, frequency.count, confidence.count].allSatisfy { $0 == m })
    let l = gels(m, n, 1,
                 .none as Optional<UnsafeMutablePointer<complex128_t>>, m, .N,
                 .none as Optional<UnsafeMutablePointer<complex128_t>>, max(m, n),
                 .none as Optional<UnsafeMutablePointer<complex128_t>>, 0)
    withUnsafeTemporaryAllocation(of: Complex128.self, capacity: m * n + max(m, n) + max(m, l)) {
        let A = $0.extracting(0 * m * n..<1 * m * n)
        let b = $0.extracting(1 * m * n..<1 * m * n + max(m, n))
        let w = $0.extracting(1 * m * n + max(m, n) ..< 1 * m * n + max(m, n) + max(m, l))
        w.withMemoryRebound(to: Float64.self) {
            assert(2 * m <= w.count)
            let r = $0.extracting(0 * m ..< 1 * m)
            let i = $0.extracting(1 * m ..< 2 * m)
            vForce.sqrt(confidence, result: &r[0..<r.count])
            for k in 0..<max(kernel.b, kernel.a) {
                vDSP.multiply(.init(-2*k-2), frequency, result: &i[0..<i.count])
            }
        }
        for k in 0..<max(kernel.b, kernel.a) {
            // exp(-2πjk[t])
            w.withMemoryRebound(to: Float64.self) {
                let r = $0.extracting(0 * m ..< 1 * m)
                let i = $0.extracting(1 * m ..< 2 * m)
                vDSP.multiply(.init(-2*k-2), frequency, result: &i[0..<i.count])
                vForce.cosPi(i, result: &r[0..<r.count])
                vForce.sinPi(i, result: &i[0..<i.count])
                vDSP_ztoc(r.baseAddress.unsafelyUnwrapped, i.baseAddress.unsafelyUnwrapped, 1,
                          b.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1, m)
            }
            if k < kernel.b {
                copy(m, b.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1,
                     A.baseAddress.unsafelyUnwrapped.mutableRawPointer.advanced(by: k * m), 1)
            }
            if k < kernel.a {
                
            }
        }
    }
    //        var info = 0 as __LAPACK_int
    //        zgels_("N",
    //               withUnsafePointer(to: m, \.self), withUnsafePointer(to: n, \.self), withUnsafePointer(to: 1, \.self),
    //               .init(A.baseAddress), withUnsafePointer(to: m, \.self),
    //               .init(b.baseAddress), withUnsafePointer(to: max(m, n), \.self),
    //               .init(work.baseAddress.unsafelyUnwrapped), withUnsafePointer(to: work.count, \.self),
    //               &info)
    
    let size = l
    return withUnsafeTemporaryAllocation(byteCount: MemoryLayout<Complex128>.stride * (m * n + 2 * max(m, n) + n),
                                         alignment: MemoryLayout<Complex128>.alignment) {
        let A = $0.assumingMemoryBound(to: Complex128.self).extracting(0 * m * n ..< 1 * m * n)
        let b = $0.assumingMemoryBound(to: Complex128.self).extracting(1 * m * n ..< 1 * m * n + max(m, n))
        let work = $0.assumingMemoryBound(to: Complex128.self).extracting((1 * m * n + max(m, n))...)
        assert(m < work.count)
        do {
            let edx = $0.assumingMemoryBound(to: Float64.self).extracting(0 * m ..< 1 * m)
            let edy = $0.assumingMemoryBound(to: Float64.self).extracting(1 * m ..< 2 * m)
            response.withUnsafeBufferPointer {
                copy(m,
                     $0.baseAddress.unsafelyUnwrapped.rawPointer, 1,
                     b.baseAddress.unsafelyUnwrapped.mutableRawPointer, 1)
            }
            for index in 0..<max(kernel.b, kernel.a) {
                vDSP.multiply(.init(-2*index-2), frequency, result: &edy[0..<edy.count])
                vForce.cosPi(edy, result: &edx[0..<edx.count])
                vForce.sinPi(edy, result: &edy[0..<edy.count])
                vDSP_ztoc(edx.baseAddress.unsafelyUnwrapped, edy.baseAddress.unsafelyUnwrapped, 1,
                          work.baseAddress.unsafelyUnwrapped.mutableRawPointer, 2, m)
                if index < kernel.b {
                    copy(m,
                         work.baseAddress.unsafelyUnwrapped.pointer(to: \.rawValue).unsafelyUnwrapped.advanced(by: 1), 1,
                         .init(mutating: A.baseAddress.unsafelyUnwrapped.advanced(by: m * (1 + index)).pointer(to: \.rawValue).unsafelyUnwrapped), 1)
                }
                if index < kernel.a {
                    gbmv(m, m, 0, 0,
                         .init(.init(r: -1, i: 0)),
                         work.baseAddress.unsafelyUnwrapped.pointer(to: \.rawValue).unsafelyUnwrapped, 1, .N,
                         b.baseAddress.unsafelyUnwrapped.pointer(to: \.rawValue).unsafelyUnwrapped, 1,
                         .init(.init(r:  0, i: 0)),
                         .init(mutating: A.baseAddress.unsafelyUnwrapped.pointer(to: \.rawValue).unsafelyUnwrapped.advanced(by: m * (1 + index + kernel.b))), 1)
                }
            }
        }
        $0.assumingMemoryBound(to: Complex128.self).prefix(m).initialize(repeating: 1)
        // LS
        let info = gels(m, n, 1,
                        A.baseAddress.map(\.mutableRawPointer).unsafelyUnwrapped, m, .N,
                        b.baseAddress.map(\.mutableRawPointer).unsafelyUnwrapped, max(m, n),
                        work.baseAddress.map(\.mutableRawPointer), work.count)
        assert(info == 0)
        return(
            Array<Float64>(unsafeUninitializedCapacity: 1 + kernel.b) {
                let b = b.prefix(1 + kernel.b).withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)
                $0[0] = b.pointee
                copy(kernel.b, b, 2, $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1)
                $1 = $0.count
            },
            Array<Float64>(unsafeUninitializedCapacity: 1 + kernel.a) {
                let a = b.dropFirst(1 + kernel.b).withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)
                $0[0] = 1
                copy(kernel.a, a, 2, $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1)
                $1 = $0.count
            }
        )
    }
}
@inlinable
public func fit(response: some AccelerateBuffer<Complex128>, frequency: some AccelerateBuffer<Float64>, with kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
	assert(frequency.count == response.count)
	let m = response.count
	let n = 1 + kernel.b + kernel.a
	return withUnsafeTemporaryAllocation(byteCount: MemoryLayout<Complex128>.stride * (m * n + 2 * max(m, n) + n),
										 alignment: MemoryLayout<Complex128>.alignment) {
		let A = $0.assumingMemoryBound(to: Complex128.self).extracting(0 * m * n ..< 1 * m * n)
		let b = $0.assumingMemoryBound(to: Complex128.self).extracting(1 * m * n ..< 1 * m * n + max(m, n))
		let work = $0.assumingMemoryBound(to: Complex128.self).extracting((1 * m * n + max(m, n))...)
		assert(m < work.count)
		var edx = $0.assumingMemoryBound(to: Float64.self).extracting(0 * m ..< 1 * m)
		var edy = $0.assumingMemoryBound(to: Float64.self).extracting(1 * m ..< 2 * m)
		response.withUnsafeBufferPointer {
			b.baseAddress?.initialize(from: $0.baseAddress.unsafelyUnwrapped, count: m)
		}
		for index in 0..<max(kernel.b, kernel.a) {
			vDSP.multiply(.init(-2*index-2), frequency, result: &edy)
			vForce.cosPi(edy, result: &edx)
			vForce.sinPi(edy, result: &edy)
            vDSP_ztoc(edx.baseAddress.unsafelyUnwrapped, edy.baseAddress.unsafelyUnwrapped, 1,
                      work.baseAddress.unsafelyUnwrapped.mutableRawPointer, 2, m)
//			vDSP_ztocD(withUnsafePointer(to: DSPDoubleSplitComplex(realp: edx.baseAddress.unsafelyUnwrapped,
//																   imagp: edy.baseAddress.unsafelyUnwrapped), \.self), 1,
//					   work.withMemoryRebound(to: DSPDoubleComplex.self, \.baseAddress.unsafelyUnwrapped), 2, .init(m))
			if index < kernel.b {
//				zcopy_(withUnsafePointer(to: m, \.self),
//					   .init(work.baseAddress), withUnsafePointer(to: 1, \.self),
//					   .init(A.baseAddress?.advanced(by: m * (1 + index))), withUnsafePointer(to: 1, \.self))
                copy(m,
                     work.baseAddress.unsafelyUnwrapped.pointer(to: \.rawValue).unsafelyUnwrapped.advanced(by: 1), 1,
                     .init(mutating: A.baseAddress.unsafelyUnwrapped.advanced(by: m * (1 + index)).pointer(to: \.rawValue).unsafelyUnwrapped), 1)
			}
			if index < kernel.a {
//				zgbmv_("N",
//					   withUnsafePointer(to: m, \.self), withUnsafePointer(to: m, \.self),
//					   withUnsafePointer(to: 0, \.self), withUnsafePointer(to: 0, \.self),
//					   .init(withUnsafePointer(to: -1 as Complex128, \.self)),
//					   .init(work.baseAddress), withUnsafePointer(to: 1, \.self),
//					   .init(b.baseAddress), withUnsafePointer(to: 1, \.self),
//					   .init(withUnsafePointer(to:  0 as Complex128, \.self)),
//					   .init(A.baseAddress?.advanced(by: m * (1 + index + kernel.b))), withUnsafePointer(to: 1, \.self))
                gbmv(m, m, 0, 0,
                     .init(.init(r: -1, i: 0)),
                     work.baseAddress.unsafelyUnwrapped.pointer(to: \.rawValue).unsafelyUnwrapped, 1, .N,
                     b.baseAddress.unsafelyUnwrapped.pointer(to: \.rawValue).unsafelyUnwrapped, 1,
                     .init(.init(r:  0, i: 0)),
                     .init(mutating: A.baseAddress.unsafelyUnwrapped.pointer(to: \.rawValue).unsafelyUnwrapped.advanced(by: m * (1 + index + kernel.b))), 1)
			}
		}
		$0.assumingMemoryBound(to: Complex128.self).prefix(m).initialize(repeating: 1)
		// LS
        let info = gels(m, n, 1,
                        A.baseAddress.map(\.mutableRawPointer).unsafelyUnwrapped, m, .N,
                        b.baseAddress.map(\.mutableRawPointer).unsafelyUnwrapped, max(m, n),
                        work.baseAddress.map(\.mutableRawPointer), work.count)
		assert(info == 0)
		return(
			Array<Float64>(unsafeUninitializedCapacity: 1 + kernel.b) {
				let b = b.prefix(1 + kernel.b).withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)
				$0[0] = b.pointee
                copy(kernel.b, b, 2, $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1)
				$1 = $0.count
			},
			Array<Float64>(unsafeUninitializedCapacity: 1 + kernel.a) {
				let a = b.dropFirst(1 + kernel.b).withMemoryRebound(to: Float64.self, \.baseAddress.unsafelyUnwrapped)
				$0[0] = 1
                copy(kernel.a, a, 2, $0.baseAddress.unsafelyUnwrapped.advanced(by: 1), 1)
				$1 = $0.count
			}
		)
	}
}
@inlinable
public func fit(response: Array<Complex128>, with kernel: (b: Int, a: Int)) -> (Array<Float64>, Array<Float64>) {
	fit(response: response, frequency: Array<Float64>(unsafeUninitializedCapacity: response.count) {
		vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
		vDSP.divide($0, .init($0.count), result: &$0)
		$1 = $0.count
	}, with: kernel)
}
