//
//  Polynomial.swift
//  MUTE
//
//  Created by Kota on 10/30/25.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Numerics.Complex128
import func MKL.vDSP_fill
import func LAPACK.hseqr
import typealias Foundation.KeyPathComparator
public enum Polynomial {}
extension Polynomial {
    @inlinable
    public static func roots(poly: some AccelerateBuffer<Float64>) -> Array<Complex128> {
        let n = poly.count - 1
        let l = hseqr(.E, .N,
                      n,
                      1, n,
                      .none, n,
                      .none, .none,
                      .none, n,
                      .none as Optional<UnsafeMutablePointer<Float64>>, 0)
        assert(0 < l)
        return withUnsafeTemporaryAllocation(of: Float64.self, capacity: n * n + 2 * n + l) {
            let z = UnsafeMutableBufferPointer(rebasing: $0.prefix(n * n))
            let r = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(n * n + 0 * n).prefix(n))
            let i = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(n * n + 1 * n).prefix(n))
            let w = UnsafeMutableBufferPointer(rebasing: $0.dropFirst(n * n + 2 * n).prefix(l))
            vDSP.clear(&z[0..<n*n])
            poly.withUnsafeBufferPointer {
                vDSP.divide($0[1..<n+1], -$0[0], result: &z[n*n-n..<n*n])
            }
            vDSP.reverse(&z[n*n-n..<n*n])
            vDSP_fill(1, z.baseAddress.unsafelyUnwrapped.advanced(by: 1), n + 1, n - 1)
            let s = hseqr(.E, .N,
                          n,
                          1, n,
                          z.baseAddress, n,
                          r.baseAddress, i.baseAddress,
                          .none, n,
                          w.baseAddress, l)
            assert(s == .zero)
            return zip(r, i).sorted(using: KeyPathComparator(\.1.magnitude)).map(Complex128.init(real:imag:))
        }
    }
}
