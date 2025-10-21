//
//  SIMD+AtomicRepresentable.swift
//  MUTE
//
//  Created by Kota on 6/4/R7.
//
import simd
import protocol Synchronization.AtomicRepresentable
//extension simd_float2: @retroactive AtomicRepresentable {
//	public typealias AtomicRepresentation = simd_int2
//	public static func encodeAtomicRepresentation(_ value: consuming Self) -> AtomicRepresentation {
//		unsafeBitCast(value, to: AtomicRepresentation.self)
//	}
//	public static func decodeAtomicRepresentation(_ storage: consuming AtomicRepresentation) -> Self {
//		unsafeBitCast(storage, to: Self.self)
//	}
//}
//extension simd_float3: @retroactive AtomicRepresentable {
//	public typealias AtomicRepresentation = simd_int3
//	public static func encodeAtomicRepresentation(_ value: consuming Self) -> AtomicRepresentation {
//		unsafeBitCast(value, to: AtomicRepresentation.self)
//	}
//	public static func decodeAtomicRepresentation(_ storage: consuming AtomicRepresentation) -> Self {
//		unsafeBitCast(storage, to: Self.self)
//	}
//}
//extension simd_float4: @retroactive AtomicRepresentable {
//	public typealias AtomicRepresentation = simd_int4
//	public static func encodeAtomicRepresentation(_ value: consuming Self) -> AtomicRepresentation {
//		unsafeBitCast(value, to: AtomicRepresentation.self)
//	}
//	public static func decodeAtomicRepresentation(_ storage: consuming AtomicRepresentation) -> Self {
//		unsafeBitCast(storage, to: Self.self)
//	}
//}
extension simd_double2: @retroactive AtomicRepresentable {
	public typealias AtomicRepresentation = simd_long2
	public static func encodeAtomicRepresentation(_ value: consuming Self) -> AtomicRepresentation {
		unsafeBitCast(value, to: AtomicRepresentation.self)
	}
	public static func decodeAtomicRepresentation(_ storage: consuming AtomicRepresentation) -> Self {
		unsafeBitCast(storage, to: Self.self)
	}
}
extension simd_double3: @retroactive AtomicRepresentable {
	public typealias AtomicRepresentation = simd_long3
	public static func encodeAtomicRepresentation(_ value: consuming Self) -> AtomicRepresentation {
		unsafeBitCast(value, to: AtomicRepresentation.self)
	}
	public static func decodeAtomicRepresentation(_ storage: consuming AtomicRepresentation) -> Self {
		unsafeBitCast(storage, to: Self.self)
	}
}
extension simd_double4: @retroactive AtomicRepresentable {
	public typealias AtomicRepresentation = simd_long4
	public static func encodeAtomicRepresentation(_ value: consuming Self) -> AtomicRepresentation {
		unsafeBitCast(value, to: AtomicRepresentation.self)
	}
	public static func decodeAtomicRepresentation(_ storage: consuming AtomicRepresentation) -> Self {
		unsafeBitCast(storage, to: Self.self)
	}
}
