//
//  Parameter.swift
//  MUTE
//
//  Created by Kota on 7/21/R7.
//
import Testing
import ASP
import CoreAudioKit
extension AUParameterGroup {
	public convenience init(x: Int) {
		self.init()
//		withUnsafePointer(to: self) {
//			UnsafeMutablePointer(mutating: $0).pointee = AUParameterTree.createGroupTemplate([])
//		}
	}
}
@Suite
struct X {
	@Test
	func x() {
		let tree = AUParameterTree {
			AUParameter(identifier: "s", name: "t", address: 0, range: 0...100)
		}
		print(tree.parameter(withAddress: 0))
	}
}
