//
//  Model+MA.swift
//  MUTE
//
//  Created by Kota on 10/8/26.
//
import protocol Accelerate.AccelerateBuffer
import typealias Accelerate.vDSP
import func simd.fma
extension Model {
    @dynamicMemberLookup
    public struct MA {
        public typealias RawValue = Array<Float64>
        @usableFromInline let rawValue: RawValue
    }
}
extension Model.MA {
    @inlinable
    init(raw value: RawValue) {
        rawValue = value
    }
}
extension Model.MA {
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
extension Model.MA: RandomAccessCollection {
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
extension Model.MA: AccelerateBuffer {
    @inlinable
    public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R {
        try rawValue.withUnsafeBufferPointer(body)
    }
}
extension Model.MA: ExpressibleByArrayLiteral {
    @inlinable
    public init(arrayLiteral elements: Float64...) {
        rawValue = elements
    }
}
