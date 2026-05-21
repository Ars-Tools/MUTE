//
//  Canvas.swift
//  MUTE
//
//  Created by Kota on 12/2/25.
//
//@preconcurrency import SwiftUI
//@preconcurrency import MetalKit
//import protocol GSP.Artwork
//import os.log
//@usableFromInline
//final class MTLView: NSView {
//    override func makeBackingLayer() -> CALayer {
//        CAMetalLayer()
//    }
//}
//@usableFromInline
//final class MTLViewController: NSViewController {
//    @usableFromInline var link: Optional<CAMetalDisplayLink> = .none
//    @usableFromInline var draw: Optional<(@Sendable (CFTimeInterval, CAMetalDrawable) -> Void)> = .none
//    @inlinable
//    override func loadView() {
//        view = MTLView()
//        view.wantsLayer = true
//        guard
//            case.some(let layer) = view.layer as?CAMetalLayer,
//            case.some(let device) = layer.device ?? MTLCreateSystemDefaultDevice(),
//            case.some(let buffer) = device.makeCommandBuffer(),
//            case.some(let queue) = device.makeMTL4CommandQueue() else {
//            return
//        }
//        view.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(tap)))
//        view.addGestureRecognizer(NSPressGestureRecognizer(target: self, action: #selector(tap)))
//        view.addGestureRecognizer(NSPanGestureRecognizer(target: self, action: #selector(tap)))
//        
//        link = CAMetalDisplayLink(metalLayer: layer)
//     
//        link?.delegate = self
//    }
//    @inlinable@objc
//    func tap(gesture: NSGestureRecognizer) {
//        print(gesture)
//    }
//    @inlinable
//    override func viewDidAppear() {
//        super.viewDidAppear()
//        link?.add(to: .main, forMode: .default)
//    }
//    @inlinable
//    override func viewWillDisappear() {
//        link?.remove(from: .main, forMode: .default)
//        super.viewWillDisappear()
//    }
//}
//extension MTLViewController: CAMetalDisplayLinkDelegate {
//    @inlinable
//    nonisolated func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate update: CAMetalDisplayLink.Update) {
//        draw?(update.targetPresentationTimestamp, update.drawable)
//    }
//}
//struct Canvas: NSViewControllerRepresentable {
//    typealias NSViewControllerType = MTLViewController
//    let artwork: Artwork
//    func makeNSViewController(context: Context) -> NSViewControllerType {
//        let controller = MTLViewController()
//        do {
//            enum Error: Swift.Error {
//                case layer
//                case device
//                case queue
//                case buffer
//            }
//            let layer = switch controller.view.layer {
//            case let layer as CAMetalLayer:
//                layer
//            default:
//                throw Error.layer
//            }
//            guard case.some(let device) = layer.preferredDevice ?? MTLCreateSystemDefaultDevice() else {
//                throw Error.device
//            }
//            guard case.some(let buffer) = device.makeCommandBuffer() else {
//                throw Error.buffer
//            }
//            guard case.some(let queue) = device.makeMTL4CommandQueue() else {
//                throw Error.queue
//            }
//            layer.device = device
//            let allocators = try repeatElement(MTL4CommandAllocatorDescriptor(), count: layer.maximumDrawableCount).compactMap(device.makeCommandAllocator(descriptor:))
//            let function = try artwork(as: layer.pixelFormat, in: layer.residencySet)
//            layer.residencySet.commit()
//            queue.addResidencySet(layer.residencySet)
//            controller.draw = { current, drawable in
//                let allocator = allocators[drawable.drawableID % allocators.count]
//                allocator.reset()
//                //
//                buffer.beginCommandBuffer(allocator: allocator)
//                function(current, buffer, drawable.texture)
//                buffer.endCommandBuffer()
//                //
//                queue.waitForDrawable(drawable)
//                queue.commit([buffer])
//                queue.signalDrawable(drawable)
//                //
//                drawable.present()
//            }
//            
//            
//        } catch {
//            os_log(.error, log: .default, "%{public}@", String(describing: error))
//        }
//        return controller
//    }
//    func updateNSViewController(_ nsViewController: NSViewControllerType, context: Context) {
//        
//    }
//}
