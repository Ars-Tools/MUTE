//
//  Guard.swift
//  MUTE
//
//  Created by Kota on 8/29/26.
//
import protocol Accelerate.AccelerateMutableBuffer
import typealias Accelerate.vDSP
public enum Guard {}
extension Guard {
    @inlinable@inline(__always)@_transparent
    public static func removeNAN(of buffer: UnsafeMutableBufferPointer<Float64>) {
        vDSP.invertedClip(buffer, to: 0...0, result: &buffer[0..<buffer.count])
    }
    @inlinable@inline(__always)@_transparent
    public static func removeINF(of buffer: UnsafeMutableBufferPointer<Float64>) {
        vDSP.clip(buffer, to: -.greatestFiniteMagnitude  ... .greatestFiniteMagnitude, result: &buffer[0..<buffer.count])
    }
    @inlinable@inline(__always)@_transparent
    public static func removeAbnormal(of buffer: UnsafeMutableBufferPointer<Float64>) {
        vDSP.add(multiplication: (buffer, 0), buffer, result: &buffer[0..<buffer.count])
        vDSP.invertedClip(buffer, to: 0...0, result: &buffer[0..<buffer.count])
    }
}
extension Guard {
    @_disfavoredOverload
    @inlinable@inline(__always)@_transparent
    public static func removeNAN(of buffer: inout some AccelerateMutableBuffer<Float64>) {
        buffer.withUnsafeMutableBufferPointer {
            removeNAN(of: $0)
        }
    }
    @_disfavoredOverload
    @inlinable@inline(__always)@_transparent
    public static func removeINF(of buffer: inout some AccelerateMutableBuffer<Float64>) {
        buffer.withUnsafeMutableBufferPointer {
            removeINF(of: $0)
        }
    }
    @_disfavoredOverload
    @inlinable@inline(__always)@_transparent
    public static func removeAbnormal(of buffer: inout some AccelerateMutableBuffer<Float64>) {
        buffer.withUnsafeMutableBufferPointer {
            removeAbnormal(of: $0)
        }
    }
}
