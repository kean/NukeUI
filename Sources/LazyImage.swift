// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Nuke
import SwiftUI

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public struct LazyImage: View {
    private let source: ImageRequestConvertible?
    private var placeholder: AnyView?
    @State private var loadedSource: ImageRequestConvertible?
    private var configure: ((LazyImageView) -> Void)?

    public init(source: ImageRequestConvertible?) {
        self.source = source
    }

    #warning("impl")
    /// Displayed while the image is loading.
    public func placeholder<Placeholder: View>(_ view: Placeholder?) -> Self {
        var copy = self
        copy.placeholder = placeholder
        return copy
    }

    #warning("options to customize image view")

    /// Returns an underlying image view.
    ///
    /// - parameter configure: A closure that gets called once when the view is
    /// created and allows you to configure it based on your needs.
    public func imageView(_ configure: @escaping (LazyImageView) -> Void) -> Self {
        var copy = self
        copy.configure = configure
        return copy
    }

    public var body: some View {
        LazyImageViewWrapper(source: $loadedSource, configure: configure)
            .onAppear { loadedSource = source }
    }
}

#warning("add onSuccess/onFailure callbacks")

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
private struct LazyImageViewWrapper: UIViewRepresentable {
    @Binding var source: ImageRequestConvertible?
    var configure: ((LazyImageView) -> Void)?

    func makeUIView(context: Context) -> LazyImageView {
        let view = LazyImageView()
        configure?(view)
        return view
    }

    func updateUIView(_ imageView: LazyImageView, context: Context) {
        imageView.load(source)
    }
}
