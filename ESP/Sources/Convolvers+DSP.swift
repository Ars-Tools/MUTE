//
//  Convolvers+DSP.swift
//  MUTE
//
//  Created by Kota on 8/18/26.
//
import typealias Accelerate.vDSP
extension Convolvers {
    @usableFromInline
    struct DSP {}
}
extension Convolvers.DSP: Convolvers.`Protocol` {
    @inlinable
    func convolve(x: UnsafePointer<Float64>, count xc: Int,
                  y: UnsafePointer<Float64>, count yc: Int,
                  z: UnsafeMutablePointer<Float64>) {
        let (signal, kernel) = xc < yc ?
            (UnsafeBufferPointer(start: y, count: yc), UnsafeBufferPointer(start: x, count: xc)) :
            (UnsafeBufferPointer(start: x, count: xc), UnsafeBufferPointer(start: y, count: yc))
        let zc = signal.count + kernel.count - 1
        withUnsafeTemporaryAllocation(of: Float64.self, capacity: zc + kernel.count - 1) {
            vDSP.clear(&$0[0..<kernel.count-1])
            $0[$0.dropFirst(kernel.count-1).initialize(fromContentsOf: signal)...].initialize(repeating: .zero)
            vDSP.convolve($0, withKernel: kernel, result: &UnsafeMutableBufferPointer(start: z, count: zc)[0..<zc])
        }
    }
}
extension Convolvers {
    public static let Naïve: some Convolvers.`Protocol` = DSP()
}
