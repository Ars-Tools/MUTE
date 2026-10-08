//
//  Filter+Median.swift
//  MUTE
//
//  Created by Kota on 10/7/26.
//
import typealias CoreMedia.CMTime
import func KSP.median_filter_create
import func KSP.median_filter_destroy
import func KSP.median_filter
import protocol DSP.Stream
import typealias DSP.Filter
import typealias DSP.Instance
import typealias Auxiliary.Autorelease
@preconcurrency import protocol Combine.Publisher
extension Filter {
    @usableFromInline
    enum Median {
        @usableFromInline
        struct He {
            @usableFromInline let source: Stream
            @usableFromInline let length: Int
        }
    }
}
extension Filter.Median.He: Stream {
    @inlinable
    var count: Int {
        source.count
    }
    @inlinable
    func callAsFunction(interval: CMTime, capacity: Int, instance: inout Instance) throws -> @Sendable (CMTime, Int, UnsafeMutablePointer<Float64>, Int) -> Void {
        let kernel = try source(interval: interval, capacity: capacity, instance: &instance)
        let object = Autorelease.Object(object: median_filter_create(source.count, length)) {
            median_filter_destroy($0)
        }
        return {
            kernel($0, $1, $2, $3)
            median_filter(object.reference, $2, $3, $2, $3, $1)
        }
    }
}
public func filter(_ source: Stream, median length: Int) -> some Stream {
    Filter.Median.He(source: source, length: length)
}
