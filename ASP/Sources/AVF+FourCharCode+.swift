//
//  OSType+.swift
//  MUTE
//
//  Created by Kota on 5/15/R7.
//
import typealias CoreFoundation.FourCharCode
@inlinable
func en(code: String) -> FourCharCode {
	code.lazy.compactMap(\.asciiValue).prefix(4).lazy.map(FourCharCode.init).reduce(0) { $0 << 8 | $1 }
}
@inlinable
func de(code: FourCharCode) -> String {
	withUnsafeBytes(of: code.bigEndian) {
		String(bytes: $0, encoding: .ascii) ?? ""
	}
}
extension String {
	public init(four code: FourCharCode) {
		self = de(code: code)
	}
}
extension FourCharCode {
	public init(four code: String) {
		self = en(code: code)
	}
}
