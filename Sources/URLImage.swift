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

    public init(source: ImageRequestConvertible?) {
        self.source = source
    }

    #warning("impl")
    /// Displayed while the image is loading.
    public func placeholder<Placeholder: View>(_ view: Placeholder?) -> URLImage {
        var copy = self
        copy.placeholder = placeholder
        return self
    }

    #warning("options to customize image view")

    public var body: some View {
        URLImageViewWrapper(model: model)
            .onAppear { model.source = source }
    }
}

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
private final class URLImageViewModel: ObservableObject {
    @Published var source: ImageRequestConvertible?
}

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
private struct URLImageViewWrapper: UIViewRepresentable {
    @ObservedObject var model: URLImageViewModel

    func makeUIView(context: Context) -> URLImageView {
        URLImageView()
    }

    func updateUIView(_ imageView: URLImageView, context: Context) {
        imageView.load(model.source)
    }
}
