//
//  AUv3+AUParameterNode+.swift
//  MUTE
//
//  Created by Kota on 7/4/R7.
//
@preconcurrency import typealias Foundation.NSNumber
@preconcurrency import typealias AudioUnit.AudioUnitParameterUnit
@preconcurrency import typealias AudioUnit.AudioUnitParameterOptions
@preconcurrency import typealias AudioUnit.AUValue
@preconcurrency import typealias AudioUnit.AUParameterNode
@preconcurrency import typealias AudioUnit.AUParameterAddress
@preconcurrency import typealias AudioUnit.AUParameter
@preconcurrency import typealias AudioUnit.AUParameterGroup
@preconcurrency import typealias AudioUnit.AUParameterTree
@preconcurrency import typealias AudioUnit.AUParameterObserver
@preconcurrency import typealias AudioUnit.AUParameterObserverToken
@preconcurrency import protocol Combine.Publisher
@preconcurrency import protocol Combine.Subscriber
@preconcurrency import typealias AUExtension.AUParameter
@preconcurrency import typealias AUExtension.AUParameterGroup
@preconcurrency import Observation
@dynamicMemberLookup
public protocol AUParameterNodeDynamicMemberLookup: AUParameterNode {
	func value(forKey: String) -> Optional<Any>
}
extension AUParameterNodeDynamicMemberLookup {
	@inlinable
	public subscript<T: AUParameterNode>(dynamicMember dynamicMember: String) -> T! {
		@inlinable
		_read {
			yield value(forKey: dynamicMember)as?T
		}
		@inlinable
		set {
			setValue(newValue, forKey: dynamicMember)
		}
	}
}
extension AUParameterNode: @retroactive Observable {}
extension AUParameterNode: AUParameterNodeDynamicMemberLookup {}
extension AUParameter: @retroactive Publisher {
	public typealias Output = AUValue
	public typealias Failure = Never
	@inlinable
	public func receive(subscriber: some Subscriber<Output, Failure>) {
		publisher(for: \.value, options: [.initial, .new]).receive(subscriber: subscriber)
	}
}
extension AUParameter {
	@inlinable
	public func description(of value: AUValue) -> String {
		withUnsafePointer(to: value, string(fromValue:))
	}
	@inlinable
	public var valueDescription: String {
		description(of: value)
	}
	@inlinable
	public var range: ClosedRange<Float> {
		minValue...maxValue
	}
}
@resultBuilder public struct AUParameterNodeBuilder {
	public static func buildBlock(_ components: AUParameterNode...) -> Array<AUParameterNode> { components }
}
extension Array where Element: AUParameterNode {
	public init(@AUParameterNodeBuilder elements: () -> Array<Element>) {
		self = elements()
	}
}
extension AUParameter {
	public convenience init(identifier: String, name: String, address: AUParameterAddress, range: ClosedRange<AUValue>, unit: AudioUnitParameterUnit = .generic, unitName: String = "", flags: AudioUnitParameterOptions = .init(), valueStrings: some Collection<String> = [], dependencies: some Collection<AUParameter> = []) {
		self.init(retain: AUParameterTree.createParameter(withIdentifier: identifier,
														  name: name,
														  address: address,
														  min: range.lowerBound, max: range.upperBound,
														  unit: unit,
														  unitName: unitName.isEmpty ? .none : .some(unitName),
														  flags: flags,
														  valueStrings: valueStrings.isEmpty ? .none : .some(.init(valueStrings)),
														  dependentParameters: dependencies.isEmpty ? .none : .some(dependencies.map(\.address).map(NSNumber.init(value:)))))
	}
	@_disfavoredOverload
	public convenience init<T: BinaryInteger>(identifier: String, name: String, address: AUParameterAddress, range: ClosedRange<T>, unit: AudioUnitParameterUnit = .generic, unitName: String = "", flags: AudioUnitParameterOptions = [], valueStrings: some Collection<String> = [], dependencies: some Collection<AUParameter> = []) {
		self.init(identifier: identifier,
				  name: name,
				  address: address,
				  range: AUValue(range.lowerBound)...AUValue(range.upperBound),
				  unit: unit,
				  unitName: unitName,
				  flags: flags,
				  valueStrings: valueStrings,
				  dependencies: dependencies)
	}
	@_disfavoredOverload
	public convenience init<T: BinaryFloatingPoint>(identifier: String, name: String, address: AUParameterAddress, range: ClosedRange<T>, unit: AudioUnitParameterUnit = .generic, unitName: String = "", flags: AudioUnitParameterOptions = [], valueStrings: some Collection<String> = [], dependencies: some Collection<AUParameter> = []) {
		self.init(identifier: identifier,
				  name: name,
				  address: address,
				  range: AUValue(range.lowerBound)...AUValue(range.upperBound),
				  unit: unit,
				  unitName: unitName,
				  flags: flags,
				  valueStrings: valueStrings,
				  dependencies: dependencies)
	}
}
extension AUParameterGroup {
	public convenience init(@AUParameterNodeBuilder template: () -> Array<AUParameterNode>) {
		self.init(retain: AUParameterTree.createGroupTemplate(template()))
	}
	public convenience init(identifier: String, name: String, @AUParameterNodeBuilder children: () -> Array<AUParameterNode>) {
		self.init(retain: AUParameterTree.createGroup(withIdentifier: identifier, name: name, children: children()))
	}
}
extension AUParameterTree {
	public convenience init(@AUParameterNodeBuilder children: () -> Array<AUParameterNode>) {
		self.init(retain: AUParameterTree.createTree(withChildren: children()))
	}
}
//@dynamicMemberLookup
//protocol AUParameterObservableDynamicMemberLookup {
//	subscript<T: AUParameterNode>(dynamicMember dynamicMember: String) -> AUParameterNode.Observable<T>! { get }
//}
//extension AUParameterObserverToken {
//	@usableFromInline
//	final class Signature { // to share observation token
//		@usableFromInline let root: AUParameterNode
//		@usableFromInline let originator: AUParameterObserverToken
//		@inlinable init(node: AUParameterNode, observer: @escaping AUParameterObserver) {
//			root = node
//			originator = root.token(byAddingParameterObserver: observer)
//		}
//		@inlinable deinit {
//			root.removeParameterObserver(originator)
//		}
//	}
//}
//extension AUParameterNode {
//	public final class Observable<Node: AUParameterNode>: Observation.Observable {
//		@usableFromInline let root: ObservationRegistrar
//		@usableFromInline let node: Node
//		@usableFromInline let sign: AUParameterObserverToken.Signature
//		@inlinable
//		init(root: ObservationRegistrar, node: Node, sign: AUParameterObserverToken.Signature) {
//			self.root = root
//			self.node = node
//			self.sign = sign
//		}
//	}
//}
//extension AUParameterNode.Observable where Node: AUParameter {
//	public convenience init(parameter: Node) {
//		let registrar = ObservationRegistrar()
//		self.init(root: registrar, node: parameter, sign: AUParameterObserverToken.Signature(node: parameter) { (address, value: AUValue) in
//			registrar.willSet(parameter, keyPath: \.value)
//			registrar.didSet(parameter, keyPath: \.value)
//		})
//	}
//}
//extension AUParameterNode.Observable where Node: AUParameterTree {
//	public convenience init(root tree: Node) {
//		let registrar = ObservationRegistrar()
//		self.init(root: registrar, node: tree, sign: AUParameterObserverToken.Signature(node: tree) { (address, value: AUValue) in
//			switch tree.parameter(withAddress: address) {
//			case.some(let parameter):
//				registrar.willSet(parameter, keyPath: \.value)
//				registrar.didSet(parameter, keyPath: \.value)
//			case.none:
//				break
//			}
//		})
//	}
//}
//extension AUParameterNode.Observable where Node: AUParameter {
//	public var value: AUValue {
//		get {
//			root.access(node, keyPath: \.value)
//			return node.value
//		}
//		set {
//			root.withMutation(of: node, keyPath: \.value) {
//				node.setValue(newValue, originator: sign.originator)
//			}
//		}
//	}
//	public var valueDescription: String {
//		withUnsafePointer(to: value, node.string(fromValue:))
//	}
//	public var range: ClosedRange<AUValue> {
//		node.minValue...node.maxValue
//	}
//}
//extension AUParameterNode.Observable: AUParameterObservableDynamicMemberLookup where Node: AUParameterGroup {
//	public subscript<T: AUParameterNode>(dynamicMember dynamicMember: String) -> AUParameterNode.Observable<T>! {
//		switch node[dynamicMember: dynamicMember] {
//		case.some(let node as T):
//			root.access(node, keyPath: \.self)
//			return.init(root: root, node: node, sign: sign)
//		case.some,.none:
//			assertionFailure("parameter \(node.keyPath) does not have \(dynamicMember) as a \(T.self)")
//			return.none
//		}
////		_read {
////			let node = node.value(forKey: dynamicMember)as!T
////			root.access(node, keyPath: \.self)
////			yield.init(root: root, node: node, token: .none)
////		}
////		_modify {
////			let node = node.value(forKey: dynamicMember)as!T
////			root.access(node, keyPath: \.self)
////			root.willSet(node, keyPath: \.self)
////			defer {
////				root.didSet(node, keyPath: \.self)
////			}
////			var mutating = AUParameterNode.Observable<T>(root: root, node: node, token: .none)
////			yield &mutating
////		}
//	}
//}
//public typealias AUParameterObservable = AUParameterNode.Observable<AUParameter>
//public typealias AUParameterTreeObservable = AUParameterNode.Observable<AUParameterTree>
