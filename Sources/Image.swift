// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public struct Image: NSViewRepresentable {
    let imageContainer: ImageContainer
    let onCreated: ((ImageView) -> Void)?

    public init(_ image: NSImage) {
        self.init(ImageContainer(image: image))
    }

    public init(_ imageContainer: ImageContainer, onCreated: ((ImageView) -> Void)? = nil) {
        self.imageContainer = imageContainer
        self.onCreated = onCreated
    }

    public func makeNSView(context: Context) -> ImageView {
        let view = ImageView()
        onCreated?(view)
        return view
    }

    public func updateNSView(_ imageView: ImageView, context: Context) {
        guard imageView.imageContainer?.image !== imageContainer.image else { return }
        imageView.imageContainer = imageContainer
    }
}
#elseif os(iOS) || os(tvOS)
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public struct Image: UIViewRepresentable {
    let imageContainer: ImageContainer
    let onCreated: ((ImageView) -> Void)?
    var resizingMode: ImageResizingMode?

    public init(_ image: UIImage) {
        self.init(ImageContainer(image: image))
    }

    public init(_ imageContainer: ImageContainer, onCreated: ((ImageView) -> Void)? = nil) {
        self.imageContainer = imageContainer
        self.onCreated = onCreated
    }

    public func makeUIView(context: Context) -> ImageView {
        let imageView = ImageView()
        if let resizingMode = self.resizingMode {
            imageView.resizingMode = resizingMode
        }
        onCreated?(imageView)
        return imageView
    }

    public func updateUIView(_ imageView: ImageView, context: Context) {
        guard imageView.imageContainer?.image !== imageContainer.image else { return }
        imageView.imageContainer = imageContainer
    }

    /// Sets the resizing mode for the image.
    public func resizingMode(_ mode: ImageResizingMode) -> Self {
        var copy = self
        copy.resizingMode = mode
        return copy
    }
}
#endif
