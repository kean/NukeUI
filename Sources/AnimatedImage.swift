// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Nuke
import SwiftUI

#if os(macOS)
/// Displays an animated image.
///
/// Currently supports GIF and MP4.
@available(macOS 10.15, *)
public struct AnimatedImage: NSViewRepresentable {
    private let image: ImageContainer

    public init(data: Data, type: ImageType) {
        self.image = ImageContainer(image: .init(), type: type, data: data)
    }

    public init(image: ImageContainer) {
        self.image = image
    }

    public func makeNSView(context: Context) -> LazyImageView {
        let view = LazyImageView()
        view.imageContainer = image
        return view
    }

    public func updateNSView(_ imageView: LazyImageView, context: Context) {
        // Do nothing
    }
}
#else
/// Displays an animated image.
///
/// Currently supports GIF and MP4.
@available(iOS 13.0, tvOS 13.0, *)
public struct AnimatedImage: UIViewRepresentable {
    private let image: ImageContainer

    public init(data: Data, type: ImageType) {
        self.image = ImageContainer(image: .init(), type: type, data: data)
    }

    public init(image: ImageContainer) {
        self.image = image
    }

    public func makeUIView(context: Context) -> LazyImageView {
        let view = LazyImageView()
        view.imageContainer = image
        return view
    }

    public func updateUIView(_ imageView: LazyImageView, context: Context) {
        // Do nothing
    }
}
#endif
