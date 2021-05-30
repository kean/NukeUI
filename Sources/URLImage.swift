// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Nuke
import SwiftUI

#warning("should it be based on URLImageView?")
@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
public struct URLImage: View {
    private var placeholder: AnyView?
    private let source: ImageRequestConvertible?
    @StateObject private var model = URLImageViewModel()
    private var configure: ((URLImageView) -> Void)?

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
    public func imageView(_ configure: @escaping (URLImageView) -> Void) -> Self {
        var copy = self
        copy.configure = configure
        return copy
    }

    public var body: some View {
        URLImageViewWrapper(model: model, configure: configure)
            .onAppear { model.source = source }
    }
}

#warning("add onSuccess/onFailure callbacks")

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
private final class URLImageViewModel: ObservableObject {
    @Published var source: ImageRequestConvertible?
}

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
private struct URLImageViewWrapper: UIViewRepresentable {
    @ObservedObject var model: URLImageViewModel
    var configure: ((URLImageView) -> Void)?

    func makeUIView(context: Context) -> URLImageView {
        let view = URLImageView()
        configure?(view)
        return view
    }

    func updateUIView(_ imageView: URLImageView, context: Context) {
        imageView.load(model.source)
    }
}
