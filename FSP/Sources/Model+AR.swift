//
//  Model+AR.swift
//  MUTE
//
//  Created by Kota on 10/8/26.
//
@preconcurrency import typealias Combine.Just
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import typealias CLK.CMTime
import typealias DSP.Filter
extension Model {
    public struct AR {
        public typealias RawValue = Array<Float64>
        @usableFromInline let rawValue: Array<Float64>
    }
}
extension Model.AR {
    @inlinable
    init(raw value: RawValue) {
        rawValue = value
    }
}
extension Model.AR {
    @inlinable
    public subscript<R>(dynamicMember dynamicMember: KeyPath<RawValue, R>) -> R {
        rawValue[keyPath: dynamicMember]
    }
    @inlinable
    public subscript<R>(dynamicMember dynamicMember: ReferenceWritableKeyPath<RawValue, R>) -> R {
        _read {
            yield rawValue[keyPath: dynamicMember]
        }
        _modify {
            yield &rawValue[keyPath: dynamicMember]
        }
    }
}
extension Model.AR: RandomAccessCollection {
    @inlinable
    public var startIndex: RawValue.Index {
        _read {
            yield rawValue.startIndex
        }
    }
    @inlinable
    public var endIndex: RawValue.Index {
        _read {
            yield rawValue.endIndex
        }
    }
    @inlinable
    public var count: Int {
        _read {
            yield rawValue.count
        }
    }
    @inlinable
    public subscript(position: RawValue.Index) -> RawValue.Element {
        rawValue[position]
    }
    @inlinable
    public subscript(bounds: Range<RawValue.Index>) -> RawValue.SubSequence {
        rawValue[bounds]
    }
}
extension Model.AR: AccelerateBuffer {
    @inlinable
    public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R {
        try rawValue.withUnsafeBufferPointer(body)
    }
}
extension Model.AR: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: Float64...) {
        rawValue = elements
    }
}
extension Model.AR {
    @inlinable
    public init(parcor model: Model.PARCOR) {
        rawValue = model.reversed().reduce(.init(arrayLiteral: 1)) { a, k in
                .init(unsafeUninitializedCapacity: a.count + 1) {
                    switch $0[1..<a.count].initialize(fromContentsOf: a.dropFirst()) {
                    case let eof:
                        assert($0.startIndex.advanced(by: a.count) == eof)
                    }
                    vDSP.reverse(&$0[1..<a.count])
                    vDSP.add(
                        multiplication: ($0[1..<a.count], k),
                        a.dropFirst(),
                        result: &$0[1..<a.count]
                    )
                    $0.suffix(1).initialize(repeating: k)
                    $0.prefix(1).initialize(repeating: 1)
                    $1 = a.count + 1
                }
        }
    }
}
extension Model.AR: DSP.Filter.TransferFunction {
    public typealias Scalar = Float64
    public typealias B = CollectionOfOne<Float64>
    public typealias A = RawValue
    public typealias TransferFunctionCoefficients = Just<(b: B, a: A)>
    @inlinable
    public var counts: SIMD2<Int> {
        .init(1, rawValue.count)
    }
    @inlinable
    public func coefficients(for Tₛ: CMTime) -> TransferFunctionCoefficients {
        Just((B(1), rawValue))
    }
}
