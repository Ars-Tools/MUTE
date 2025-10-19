//
//  AudioComponentDescription+.swift
//  MUTE
//
//  Created by Kota on 7/21/R7.
//
import typealias AudioUnit.AudioComponentDescription
extension AudioComponentDescription {
	var readableComponents: Array<String> {
		[componentType,
		 componentSubType,
		 componentManufacturer].map(de(code:))
	}
	func identifier(suffix: String, separator: Character = ".") -> String {
		[
			de(code: componentType),
			de(code: componentSubType),
			de(code: componentManufacturer),
			suffix
		].joined(separator: .init(separator))
	}
}
