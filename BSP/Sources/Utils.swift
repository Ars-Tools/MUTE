//
//  Utils.swift
//  MUTE
//
//  Created by Kota on 10/20/25.
//
import func Darwin.exp2
public func ratio(cent: Float64) -> Float64 {
    exp2(cent / 1200.0)
}
