//
//  Utils+Biquad.swift
//  MUTE
//
//  Created by Kota on 8/26/R7.
//
import typealias Foundation.KeyPathComparator
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias Accelerate.vForce
//import func simd.__sincospi_stret
import typealias Numerics.Complex64
import typealias Numerics.Complex128
import typealias Dense.MatBuf
import typealias Optimise.Graph
import func simd.log
import func simd.atan2
import func simd.distance
import simd
import MetalPerformanceShadersGraph
import func Accelerate.vecLib.vDSP_mtrans
import func Layout.zip
@inlinable@_transparent
func roots(response: some AccelerateBuffer<Complex128>, frequency: some AccelerateBuffer<Float64>, with sos: Int) -> some Sequence<((Complex128, Complex128), (Complex128, Complex128))> {
    let (b, a) = fit(response: response, frequency: frequency, with: (2 * sos, 2 * sos))
    let zeros = roots(poly: b).sorted(using: KeyPathComparator(\.imag.magnitude, order: .reverse))
    let poles = roots(poly: a).sorted(using: KeyPathComparator(\.imag.magnitude, order: .reverse))
    assert(zeros.count.isMultiple(of: 2))
    assert(poles.count.isMultiple(of: 2))
    let z = stride(from: 0, to: zeros.count, by: 2).map {
        switch (zeros[$0], zeros[$0+1]) {
        case (let z0, let z1) where z0.imag < z1.imag:
            (z1, z0)
        case (let z0, let z1):
            (z0, z1)
        }
    }
    let p = stride(from: 0, to: poles.count, by: 2).map {
        switch (poles[$0], poles[$0+1]) {
        case (let p0, let p1) where p0.imag < p1.imag:
            (p1, p0)
        case (let p0, let p1):
            (p0, p1)
        }
    }
    assert(z.count == sos)
    assert(p.count == sos)
    let c = min(z.prefix { ($0 - $1.conjugate).magnitude < .ulpOfOne }.count,
                p.prefix { ($0 - $1.conjugate).magnitude < .ulpOfOne }.count)
    var table = MatBuf<Float64>(shape: (c, c), for: .rowMajor, with: .zero)
    for (j, p) in p.prefix(c).enumerated() {
        for (k, z) in z.prefix(c).enumerated() {
            assert(p.0.imag.sign == z.0.imag.sign)
            let p = SIMD2<Float64>(log(p.0.magnitude), atan2(p.0.imag, p.0.real))
            let z = SIMD2<Float64>(log(z.0.magnitude), atan2(z.0.imag, z.0.real))
            table[j, k] = distance(p, z)
        }
    }
    let pair = zip(z.dropFirst(c), p.dropFirst(c)) + Graph.Match(table: table).map {
        (z[$0.y], p[$0.x])
    }
    return pair
}
@inlinable
public func fit(response: some AccelerateBuffer<Complex128>, frequency: some AccelerateBuffer<Float64>, with sos: Int) -> Array<(SIMD3<Float64>, SIMD3<Float64>)> {
    roots(response: response, frequency: frequency, with: sos).map {(
		SIMD3<Float64>(1, -($0.0 + $0.1).real, ($0.0 * $0.1).real),
		SIMD3<Float64>(1, -($1.0 + $1.1).real, ($1.0 * $1.1).real)
	)}
}
@inlinable
public func fit(response: some AccelerateBuffer<Complex128>, with sos: Int) -> Array<(SIMD3<Float64>, SIMD3<Float64>)> {
	fit(response: response,
		frequency: Array(unsafeUninitializedCapacity: response.count) {
		vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
		vDSP.divide($0, .init($0.count), result: &$0)
		$1 = $0.count
	}, with: sos)
}
@inlinable
public func peq(response: some AccelerateBuffer<Complex128>, frequency: some AccelerateBuffer<Float64>, with sos: Int) -> Array<(Float64, Float64, Float64)> {
    let sos = roots(response: response, frequency: frequency, with: sos).map {(
        SIMD3<Float64>(1, -($0.0 + $0.1).real, ($0.0 * $0.1).real),
        SIMD3<Float64>(1, -($1.0 + $1.1).real, ($1.0 * $1.1).real)
    )}
    let peq = sos.map { b, a in
        let b = b / a.x
        let a = a / a.x
        let ω = acos(max(-1, min(1, -a.y / (1 + a.z))))
        let A = switch ((b.x - b.z) * (1 + a.z), (b.x + b.z) * (1 - a.z)) {
        case (let numerator, let denominator):
            sqrt(max(0, numerator / max(1e-2, denominator)))
        }
        let α = switch ((b.x - b.z) * (1 - a.z), (b.x + b.z) * (1 + a.z)) {
        case (let numerator, let denominator):
            sqrt(max(0, numerator / max(1e-2, denominator)))
        }
        let Q = 0.5 * sin(ω) / max(1e-2, α)
        return (ω, A, Q)
    }
    return peq.filter { [$0, $1, $2].allSatisfy(\.isNormal) }.sorted(using: KeyPathComparator(\.0))
}
@inlinable
public func peq(response: some AccelerateBuffer<Complex128>, with sos: Int) -> Array<(Float64, Float64, Float64)>{
    peq(response: response,
        frequency: Array(unsafeUninitializedCapacity: response.count) {
        vDSP.formRamp(withInitialValue: 0, increment: 1, result: &$0)
        vDSP.divide($0, .init($0.count), result: &$0)
        $1 = $0.count
    }, with: sos)
}
@inlinable
public func peq(frequency: Array<Float64>,
                magnitude: (Array<Float64>, lr: Float64),
                cascading: (Array<Float64>, lr: Float64),
                bandwidth: (Float64, lr: Float64),
                queue: Optional<MTLCommandQueue> = MTLCreateSystemDefaultDevice().flatMap { $0.makeCommandQueue() },
                epoch: (major: Int, minor: Int),
                board: (Int, Array<MTLBuffer>) -> Void) {
    let graph = MPSGraph()
    let count = min(frequency.count, magnitude.0.count)
    let (r, i) = withUnsafeTemporaryAllocation(of: Float32.self, capacity: 6 * count) {
        vDSP.clear(&$0[3*count..<4*count])
        vDSP.convertElements(of: frequency, to: &$0[4*count..<5*count])
        vDSP.multiply(2, $0[4*count..<5*count], result: &$0[5*count..<6*count])
        vForce.cosPi($0[3*count..<6*count], result: &$0[0*count..<3*count])
        vForce.sinPi($0[3*count..<6*count], result: &$0[3*count..<6*count])
        return (
            graph.transposeTensor(graph.constant(.init(buffer: $0.extracting(0*count..<3*count)), shape: [3, count].map(NSNumber.init(integerLiteral:)), dataType: .float32), dimension: 0, withDimension: 1, name: .none),
            graph.transposeTensor(graph.constant(.init(buffer: $0.extracting(3*count..<6*count)), shape: [3, count].map(NSNumber.init(integerLiteral:)), dataType: .float32), dimension: 0, withDimension: 1, name: .none)
        )
    }
    
    assert(r.shape == [count, 3].map(NSNumber.init(integerLiteral:)))
    assert(i.shape == [count, 3].map(NSNumber.init(integerLiteral:)))
    
    let lnω = vDSP.doubleToFloat(vForce.log(cascading.0)).withUnsafeBufferPointer {
        graph.variable(with: .init(buffer: $0), shape: [1, $0.count].map(NSNumber.init(integerLiteral:)), dataType: .float32, name: "lnω")
    }
    let lnA = Array<Float32>(repeating: 2, count: cascading.0.count).withUnsafeBufferPointer {
        graph.variable(with: .init(buffer: $0), shape: [1, $0.count].map(NSNumber.init(integerLiteral:)), dataType: .float32, name: "lnA")
    }
    let lnB = withUnsafeBytes(of: Float32(bandwidth.0)) {
        graph.variable(with: .init($0), shape: [1, 1].map(NSNumber.init(integerLiteral:)), dataType: .float32, name: "lnB")
    }
    
    let lnω⁺ = graph.read(lnω, name: .none)
    let lnB⁺ = graph.read(lnB, name: .none)
    let lnA⁺ = graph.read(lnA, name: .none)
    
    let ω = graph.multiplication(graph.constant(.pi, dataType: .float32), graph.exponent(with: lnω⁺, name: .none), name: "πω")
    let s = graph.sin(with: ω, name: "sin(πω)")
    let c = graph.cos(with: ω, name: "cos(πω)")
    
    let explnB = graph.exponent(with: lnB⁺, name: "B")
    let explnA = graph.exponent(with: lnA⁺, name: "A")
    
    let w = graph.multiplication(graph.constant(0.5 * M_LN2, dataType: .float32),
                                 graph.multiplication(explnB, graph.division(ω, s, name: "ω/sin(ω)"), name: "w*ω/sin(ω)"),
                                 name: "0.5*ln2*w*ω/sin(ω)")
    let α = graph.multiplication(s, graph.sinh(with: w, name: .none), name: "sinh(0.5*ln2*w*ω/sin(ω))")
    
    let b₀ = graph.addition(graph.constant(1, dataType: .float32), graph.multiplication(α, explnA, name: .none), name: .none)
    let b₁ = graph.multiplication(graph.constant(-2.0, dataType: .float32), c, name: "-2.0*cos(ω)")
    let b₂ = graph.subtraction(graph.constant(1, dataType: .float32), graph.multiplication(α, explnA, name: .none), name: .none)
    let a₀ = graph.addition(graph.constant(1, dataType: .float32), graph.division(α, explnA, name: .none), name: .none)
    let a₁ = graph.multiplication(graph.constant(-2.0, dataType: .float32), c, name: "-2.0*cos(ω)")
    let a₂ = graph.subtraction(graph.constant(1, dataType: .float32), graph.division(α, explnA, name: .none), name: .none)
    
    let b = graph.division(graph.concatTensors([b₀, b₁, b₂], dimension: 0, name: .none), a₀, name: "B")
    let a = graph.division(graph.concatTensors([a₀, a₁, a₂], dimension: 0, name: .none), a₀, name: "A")
    
    let Br = graph.matrixMultiplication(primary: r, secondary: b, name: "Zr•B")
    let Bi = graph.matrixMultiplication(primary: i, secondary: b, name: "Zi•B")
    
    assert(Br.shape == [count, cascading.0.count].map(NSNumber.init(integerLiteral:)))
    assert(Bi.shape == [count, cascading.0.count].map(NSNumber.init(integerLiteral:)))
    
    let Ar = graph.matrixMultiplication(primary: r, secondary: a, name: "Zr•A")
    let Ai = graph.matrixMultiplication(primary: i, secondary: a, name: "Zi•A")
    
    assert(Ar.shape == [count, cascading.0.count].map(NSNumber.init(integerLiteral:)))
    assert(Ai.shape == [count, cascading.0.count].map(NSNumber.init(integerLiteral:)))
    
    let`|B|²` = graph.addition(graph.square(with: Br, name: .none), graph.square(with: Bi, name: .none), name: "|B|²")
    let`|A|²` = graph.addition(graph.square(with: Ar, name: .none), graph.square(with: Ai, name: .none), name: "|A|²")
    
    let`ln|B|` = graph.multiplication(graph.constant(0.5, dataType: .float32), graph.logarithm(with: `|B|²`, name: .none), name: "ln|B|")
    let`ln|A|` = graph.multiplication(graph.constant(0.5, dataType: .float32), graph.logarithm(with: `|A|²`, name: .none), name: "ln|A|")
    
    assert(Ar.shape == [count, cascading.0.count].map(NSNumber.init(integerLiteral:)))
    assert(Ai.shape == [count, cascading.0.count].map(NSNumber.init(integerLiteral:)))
    
    let`Σln|B|` = graph.reductionSum(with: `ln|B|`, axis: 1, name: "Σln|B|")
    let`Σln|A|` = graph.reductionSum(with: `ln|A|`, axis: 1, name: "Σln|A|")
    
    assert(`Σln|B|`.shape == [count, 1].map(NSNumber.init(integerLiteral:)))
    assert(`Σln|A|`.shape == [count, 1].map(NSNumber.init(integerLiteral:)))
    
    let`ln|D|` = vDSP.doubleToFloat(vForce.log(magnitude.0)).withUnsafeBufferPointer {
        graph.constant(.init(buffer: $0), shape: [.init(integerLiteral: $0.count), 1], dataType: .float32)
    }
    let`ln|Y|` = graph.subtraction(`Σln|B|`, `Σln|A|`, name: "Σln|B|-Σln|A|")
    
    assert(`ln|D|`.shape == [.init(integerLiteral: count), 1])
    assert(`ln|Y|`.shape == [.init(integerLiteral: count), 1])
    
    let Δ = graph.subtraction(`ln|D|`, `ln|Y|`, name: "ln|D|-ln|Y|")
    // Itakura-Saito dist.
//    let ℒ = graph.subtraction(graph.subtraction(graph.exponent(with: Δ, name: .none), Δ, name: .none), graph.constant(1, dataType: .float32), name: .none)
    // MSE
    let ℒ = graph.square(with: Δ, name: .none)
    let Σℒ = graph.reductionSum(with: ℒ, axes: .none, name: "Σℒ")
    assert(Σℒ.shape.map { $0.map(\.intValue).reduce(1, *) } == 1)
    
    let ℛ = graph.addition(graph.multiplication(graph.constant(1e-3, dataType: .float32), graph.square(with: lnB⁺, name: .none), name: .none),
                           graph.multiplication(graph.constant(1e-3, dataType: .float32), graph.square(with: lnA⁺, name: .none), name: .none),
                           name: .none)
    let Σℛ = graph.reductionSum(with: ℛ, axes: .none, name: "Σℛ")
    
    let`∂p` = graph.gradients(of: graph.addition(Σℒ, Σℛ, name: .none), with: [lnω, lnA, lnB], name: "∂p")
    
    let Δlnω = `∂p`[lnω, default: graph.constant(.zero, dataType: .float32)]
    let ΔlnB = `∂p`[lnB, default: graph.constant(.zero, dataType: .float32)]
    let ΔlnA = `∂p`[lnA, default: graph.constant(.zero, dataType: .float32)]
    
    let nlnω = graph.subtraction(lnω⁺, graph.multiplication(graph.constant(cascading.lr, dataType: .float32), Δlnω, name: .none), name: .none)
    let nlnB = graph.subtraction(lnB⁺, graph.multiplication(graph.constant(bandwidth.lr, dataType: .float32), ΔlnB, name: .none), name: .none)
    let nlnA = graph.subtraction(lnA⁺, graph.multiplication(graph.constant(magnitude.lr, dataType: .float32), ΔlnA, name: .none), name: .none)
    
    let update = [
        graph.assign(lnω, tensor: graph.satuarte(tensor: nlnω, in: log(vDSP.minimum(cascading.0)) ... log(vDSP.maximum(cascading.0))), name: .none),
        graph.assign(lnB, tensor: graph.satuarte(tensor: nlnB, in: -.infinity ... .infinity), name: .none),
        graph.assign(lnA, tensor: graph.satuarte(tensor: nlnA, in: -.infinity ... .infinity), name: .none),
    ]
    
    let kernel = graph.compile(with: queue.map(\.device).map(MPSGraphDevice.init(mtlDevice:)),
                               feeds: [:],
                               targetTensors: [`Σℒ`, `ln|D|`, `ln|Y|`].map { graph.transposeTensor($0, dimension: 0, withDimension: 1, name: .none) },
                               targetOperations: .some(update),
                               compilationDescriptor: .none)
    let memory = queue.map(\.device).flatMap {
        let descriptor = MTLHeapDescriptor()
        descriptor.size = 3 * count * MemoryLayout<Float32>.stride
        descriptor.storageMode = .shared
        return $0.makeHeap(descriptor: descriptor)
    }
    do {
        let status = [count, count, 1].compactMap { count in
            memory.flatMap { $0.makeBuffer(length: count * MemoryLayout<Float32>.stride) }
        }.reversed() as Array<MTLBuffer>
        let result = status.compactMap(\.self).map {
            MPSGraphTensorData($0, shape: [.init(integerLiteral: $0.length / MemoryLayout<Float32>.stride)], dataType: .float32)
        }
        assert(result.flatMap(\.shape).map(\.intValue) == [1, count, count])
        for major in 0..<epoch.major {
            for minor in 0..<epoch.minor {
                kernel.runAsync(with: queue.unsafelyUnwrapped, inputs: [], results: .none, executionDescriptor: .none)
            }
            kernel.run(with: queue.unsafelyUnwrapped, inputs: [], results: .some(result), executionDescriptor: .none)
            board(major, status)
        }
    }
    do {
        let result = graph.run(with: queue.unsafelyUnwrapped, feeds: [:], targetTensors: [lnω, lnB, lnA], targetOperations: .none)
        let lnω = result[lnω, default: .init()]
        let lnB = result[lnB, default: .init()]
        let lnA = result[lnA, default: .init()]
        
        assert(lnω.shape == [1, .init(integerLiteral: cascading.0.count)])
        let ω = Array<Float64>(unsafeUninitializedCapacity: lnω.shape[1].intValue) {
            vDSP.convertElements(of: Array<Float32>(unsafeUninitializedCapacity: $0.count) {
                lnω.mpsndarray().readBytes($0.baseAddress.unsafelyUnwrapped, strideBytes: .none)
                $1 = $0.count
            }, to: &$0)
            vForce.exp($0, result: &$0)
            $1 = $0.count
        }
        assert(lnB.shape == [1, 1])
        let B = withUnsafeTemporaryAllocation(of: Float32.self, capacity: 1) {
            lnB.mpsndarray().readBytes($0.baseAddress.unsafelyUnwrapped, strideBytes: .none)
            return exp($0.baseAddress.unsafelyUnwrapped.pointee)
        }
        assert(lnω.shape == [1, .init(integerLiteral: cascading.0.count)])
        let A = Array<Float64>(unsafeUninitializedCapacity: lnA.shape[1].intValue) {
            vDSP.convertElements(of: Array<Float32>(unsafeUninitializedCapacity: $0.count) {
                lnA.mpsndarray().readBytes($0.baseAddress.unsafelyUnwrapped, strideBytes: .none)
                $1 = $0.count
            }, to: &$0)
            vForce.exp($0, result: &$0)
            $1 = $0.count
        }
        print(ω, B, A)
    }
}
@inlinable
public func peq(frequency: some AccelerateBuffer<Float64>,
                magnitude: some AccelerateBuffer<Float64>,
                initial: some Collection<(ω: Float64, Q: Float64, A: Float64)>,
                update: (ω: Float64, Q: Float64, A: Float64, r: Float64),
                queue: Optional<MTLCommandQueue> = MTLCreateSystemDefaultDevice().flatMap { $0.makeCommandQueue() },
                epoch: (major: Int, minor: Int),
                board: (Int, Array<MTLBuffer>) -> Void) -> Array<(ω: Float64, Q: Float64, A: Float64)> {
    let graph = MPSGraph()
    let count = min(frequency.count, magnitude.count)
    let (r, i) = withUnsafeTemporaryAllocation(of: Float32.self, capacity: 6 * count) {
        vDSP.clear(&$0[3*count..<4*count])
        vDSP.convertElements(of: frequency, to: &$0[4*count..<5*count])
        vDSP.multiply(2, $0[4*count..<5*count], result: &$0[5*count..<6*count])
        vForce.cosPi($0[3*count..<6*count], result: &$0[0*count..<3*count])
        vForce.sinPi($0[3*count..<6*count], result: &$0[3*count..<6*count])
        return (
            graph.transposeTensor(graph.constant(.init(buffer: $0.extracting(0*count..<3*count)), shape: [3, count].map(NSNumber.init(integerLiteral:)), dataType: .float32), dimension: 0, withDimension: 1, name: .none),
            graph.transposeTensor(graph.constant(.init(buffer: $0.extracting(3*count..<6*count)), shape: [3, count].map(NSNumber.init(integerLiteral:)), dataType: .float32), dimension: 0, withDimension: 1, name: .none)
        )
    }
    
    assert(r.shape == [count, 3].map(NSNumber.init(integerLiteral:)))
    assert(i.shape == [count, 3].map(NSNumber.init(integerLiteral:)))
    
    let lnω = vDSP.doubleToFloat(vForce.log(initial.map(\.ω))).withUnsafeBufferPointer {
        graph.variable(with: .init(buffer: $0), shape: [1, .init(integerLiteral: $0.count)], dataType: .float32, name: "lnω")
    }
    let lnQ = vDSP.doubleToFloat(vForce.log(initial.map(\.Q))).withUnsafeBufferPointer {
        graph.variable(with: .init(buffer: $0), shape: [1, .init(integerLiteral: $0.count)], dataType: .float32, name: "lnQ")
    }
    let lnA = vDSP.doubleToFloat(vForce.log(initial.map(\.A))).withUnsafeBufferPointer {
        graph.variable(with: .init(buffer: $0), shape: [1, .init(integerLiteral: $0.count)], dataType: .float32, name: "lnA")
    }
    
//    let lnω⁺ = graph.read(lnω, name: .none)
//    let lnQ⁺ = graph.read(lnQ, name: .none)
//    let lnA⁺ = graph.read(lnA, name: .none)
    
    let ω = graph.multiplication(graph.constant(.pi, dataType: .float32), graph.exponent(with: lnω, name: .none), name: "πω")
    let σ = graph.exponent(with: graph.subtraction(lnA, lnQ, name: .none), name: "1*A/Q")
    let λ = graph.exponent(with: graph.negative(with: graph.addition(lnA, lnQ, name: .none), name: .none), name: "1/A/Q")
    
    let s = graph.multiplication(graph.constant(0.5, dataType: .float32), graph.sin(with: ω, name: .none), name: "0.5*sin(πω)")
    let c = graph.multiplication(graph.constant(2.0, dataType: .float32), graph.cos(with: ω, name: .none), name: "2.0*cos(πω)")
    
    let b₀ = graph.addition(graph.constant(1, dataType: .float32), graph.multiplication(s, σ, name: .none), name: "1+0.5*sin(πω)*A/Q")
    let b₁ = graph.negative(with: c, name: "-2.0*cos(2πω)")
    let b₂ = graph.subtraction(graph.constant(1, dataType: .float32), graph.multiplication(s, σ, name: .none), name: "1-0.5*sin(πω)*A/Q")
    let a₀ = graph.addition(graph.constant(1, dataType: .float32), graph.multiplication(s, λ, name: .none), name: "1+0.5*sin(πω)/A/Q")
    let a₁ = graph.negative(with: c, name: "-2.0*cos(2πω)")
    let a₂ = graph.subtraction(graph.constant(1, dataType: .float32), graph.multiplication(s, λ, name: .none), name: "1-0.5*sin(πω)/A/Q")
    
    let b = graph.division(graph.concatTensors([b₀, b₁, b₂], dimension: 0, name: .none), a₀, name: "B")
    let a = graph.division(graph.concatTensors([a₀, a₁, a₂], dimension: 0, name: .none), a₀, name: "A")
    
    let Br = graph.matrixMultiplication(primary: r, secondary: b, name: "Zr•B")
    let Bi = graph.matrixMultiplication(primary: i, secondary: b, name: "Zi•B")
    
    let Ar = graph.matrixMultiplication(primary: r, secondary: a, name: "Zr•A")
    let Ai = graph.matrixMultiplication(primary: i, secondary: a, name: "Zi•A")
    
    let`|B|²` = graph.addition(graph.square(with: Br, name: .none), graph.square(with: Bi, name: .none), name: "|B|²")
    let`|A|²` = graph.addition(graph.square(with: Ar, name: .none), graph.square(with: Ai, name: .none), name: "|A|²")
    
    let`ln|B|` = graph.multiplication(graph.constant(0.5, dataType: .float32), graph.logarithm(with: `|B|²`, name: .none), name: "ln|B|")
    let`ln|A|` = graph.multiplication(graph.constant(0.5, dataType: .float32), graph.logarithm(with: `|A|²`, name: .none), name: "ln|A|")
    
    let`Σln|B|` = graph.reductionSum(with: `ln|B|`, axis: 1, name: "Σln|B|")
    let`Σln|A|` = graph.reductionSum(with: `ln|A|`, axis: 1, name: "Σln|A|")
    
    let`ln|Y|` = graph.subtraction(`Σln|B|`, `Σln|A|`, name: "Σln|B|-Σln|A|")
    let`ln|D|` = vDSP.doubleToFloat(vForce.log(magnitude)).withUnsafeBufferPointer {
        graph.constant(.init(buffer: $0), shape: [.init(integerLiteral: $0.count), 1], dataType: .float32)
    }
    
    let Δ = graph.subtraction(`ln|D|`, `ln|Y|`, name: "ln|D|-ln|Y|")
    // Itakura-Saito dist.
    let ℒ = graph.subtraction(graph.subtraction(graph.exponent(with: Δ, name: .none), Δ, name: .none), graph.constant(1, dataType: .float32), name: .none)
    // MSE
//    let ℒ = graph.square(with: Δ, name: .none)
    let Σℒ = graph.reductionSum(with: ℒ, axes: .none, name: "Σℒ")
    assert(Σℒ.shape.map { $0.map(\.intValue).reduce(1, *) } == 1)
    
    let ℛ = graph.addition(graph.multiplication(graph.constant(update.r, dataType: .float32), graph.square(with: lnQ, name: .none), name: .none),
                           graph.multiplication(graph.constant(update.r, dataType: .float32), graph.square(with: lnA, name: .none), name: .none),
                           name: .none)
    let Σℛ = graph.reductionSum(with: ℛ, axes: .none, name: "Σℛ")
    
    let`∂p` = graph.gradients(of: graph.addition(Σℒ, Σℛ, name: .none), with: [lnω, lnQ, lnA], name: "∂p")
    
    let Δlnω = `∂p`[lnω, default: graph.constant(.zero, dataType: .float32)]
    let ΔlnQ = `∂p`[lnQ, default: graph.constant(.zero, dataType: .float32)]
    let ΔlnA = `∂p`[lnA, default: graph.constant(.zero, dataType: .float32)]
    
    let nlnω = graph.subtraction(lnω, graph.multiplication(graph.constant(update.ω, dataType: .float32), Δlnω, name: .none), name: .none)
    let nlnQ = graph.subtraction(lnQ, graph.multiplication(graph.constant(update.Q, dataType: .float32), ΔlnQ, name: .none), name: .none)
    let nlnA = graph.subtraction(lnA, graph.multiplication(graph.constant(update.A, dataType: .float32), ΔlnA, name: .none), name: .none)
    
    let update = [
        graph.assign(lnω, tensor: graph.satuarte(tensor: nlnω, in: -.infinity ... 0), name: .none),
        graph.assign(lnQ, tensor: graph.satuarte(tensor: nlnQ, in: -3 ... 3), name: .none),
        graph.assign(lnA, tensor: graph.satuarte(tensor: nlnA, in: -3 ... 3), name: .none),
    ]
    
    let kernel = graph.compile(with: queue.map(\.device).map(MPSGraphDevice.init(mtlDevice:)),
                               feeds: [:],
                               targetTensors: [
                                `Σℒ`,
                                graph.transposeTensor(`ln|D|`, dimension: 0, withDimension: 1, name: .none),
                                graph.transposeTensor(`ln|Y|`, dimension: 0, withDimension: 1, name: .none),
                                graph.exponent(with: lnω, name: .none),
                                graph.exponent(with: lnQ, name: .none),
                                graph.exponent(with: lnA, name: .none)
                               ],
                               targetOperations: .some(update),
                               compilationDescriptor: .none)
    let memory = queue.map(\.device).flatMap {
        let descriptor = MTLHeapDescriptor()
        descriptor.size = 3 * (initial.count + count) * MemoryLayout<Float32>.stride
        descriptor.storageMode = .shared
        return $0.makeHeap(descriptor: descriptor)
    }
    let status = [initial.count, initial.count, initial.count, count, count, 1].compactMap { count in
        memory.flatMap { $0.makeBuffer(length: count * MemoryLayout<Float32>.stride) }
    }.reversed() as Array<MTLBuffer>
    let result = status.compactMap(\.self).map {
        MPSGraphTensorData($0, shape: [.init(integerLiteral: $0.length / MemoryLayout<Float32>.stride)], dataType: .float32)
    }
    assert(result.flatMap(\.shape).map(\.intValue) == [1, count, count, initial.count, initial.count, initial.count])
    for major in 0..<epoch.major {
        for minor in 0..<epoch.minor {
            kernel.runAsync(with: queue.unsafelyUnwrapped, inputs: [], results: .none, executionDescriptor: .none)
        }
        kernel.run(with: queue.unsafelyUnwrapped, inputs: [], results: .some(result), executionDescriptor: .none)
        board(major, status)
    }
    return zip(UnsafeBufferPointer(start: status[3].contents().assumingMemoryBound(to: Float32.self), count: initial.count),
               UnsafeBufferPointer(start: status[4].contents().assumingMemoryBound(to: Float32.self), count: initial.count),
               UnsafeBufferPointer(start: status[5].contents().assumingMemoryBound(to: Float32.self), count: initial.count)).map {(
                ω: Float64($0),
                Q: Float64($1),
                A: Float64($2)
               )}
}
@inlinable
public func peq(frequency: some AccelerateBuffer<Float64>,
                magnitude: some AccelerateBuffer<Float64>,
                initial: (centre: Array<Float64>, bandwidth: Float64),
                update: (ω: Float64, Q: Float64, A: Float64, r: Float64),
                queue: Optional<MTLCommandQueue> = MTLCreateSystemDefaultDevice().flatMap { $0.makeCommandQueue() },
                epoch: (major: Int, minor: Int),
                board: (Int, Array<MTLBuffer>) -> Void) -> Array<(ω: Float64, Q: Float64, A: Float64)> {
    peq(frequency: frequency,
        magnitude: magnitude,
        initial: initial.centre.map {(
            ω: $0,
            Q: 0.5 / sinh(0.5 * M_LN2 * initial.bandwidth * $0 / __sinpi($0)),
            A: 1.0
        )},
        update: update,
        epoch: epoch,
        board: board)
}
extension MPSGraph {
    @inlinable@_transparent
    func satuarte(tensor: MPSGraphTensor, in range: ClosedRange<Float64>) -> MPSGraphTensor {
        minimum(constant(range.upperBound, dataType: .float32), maximum(constant(range.lowerBound, dataType: .float32), tensor, name: .none), name: .none)
    }
}
