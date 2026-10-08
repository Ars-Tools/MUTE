//
//  Model+PARCOR.swift
//  MUTE
//
//  Created by Kota on 10/8/26.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import func simd.fma
extension Model {
    @dynamicMemberLookup
    public struct PARCOR {
        public typealias RawValue = Array<Float64>
        @usableFromInline let rawValue: RawValue
    }
}
extension Model.PARCOR {
    @inlinable
    init(raw value: RawValue) {
        rawValue = value
    }
}
extension Model.PARCOR {
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
extension Model.PARCOR: RandomAccessCollection {
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
extension Model.PARCOR: AccelerateBuffer {
    @inlinable
    public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R {
        try rawValue.withUnsafeBufferPointer(body)
    }
}
extension Model.PARCOR: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: Float64...) {
        rawValue = elements
    }
}
extension Model.PARCOR {
    @inlinable
    public init(ar model: Model.AR) {
        rawValue = .init(sequence(state: vDSP.divide(model.rawValue.dropFirst(), model.first.unsafelyUnwrapped)) {
            guard case.some(let k) = $0.popLast() else { return.none }
            var r = $0
            vDSP.reverse(&r)
            vDSP.add(multiplication: (r, -k), $0, result: &r)
            vDSP.divide(r, fma(-k, k, 1), result: &r)
            $0 = r
            return.some(k)
        })
    }
    @inlinable
    public var stable: Bool {
        rawValue.allSatisfy { $0.isLess(than: 1) }
    }
}
