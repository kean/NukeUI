// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import SwiftUI
import Nuke

/// Lazily loads and displays an image with the given source.
///
/// The image view is lazy and doesn't know the size of the image before it is
/// downloaded. You must specify the size for the view before loading the image.
/// By default, the image will resize to fill the available space but preserve
/// the aspect ratio. You can change this behavior by passing a different content mode.
@available(watchOS 7.0, *)
public struct LazyImage: View {
    // This component offers a limited watchOS support.
    // Eventually the "main" LazyImage should probably also be written
    // using only SwiftUI.

    private let request: ImageRequest?
    private var placeholderView: AnyView?
    private var failureView: AnyView?
    @StateObject private var image = FetchImage()

    public init(source: ImageRequestConvertible?) {
        self.request = source?.asImageRequest()
    }

    public var body: some View {
        ZStack {
            if image.isLoading {
                placeholderView
            }
            if let result = image.result, case .failure = result, !image.isLoading {
                failureView
            }
            image.view?
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
        }
        .onAppear { request.map(image.load) }
        .onDisappear(perform: image.reset)
        // Making sure it reload if the source changes
        .id(request.map(ImageRequest.ID.init))
    }

    // MARK: Placeholder View

    /// An image to be shown while the request is in progress.
    public func placeholder<Placeholder: View>(@ViewBuilder _ content: () -> Placeholder?) -> Self {
        map { $0.placeholderView = AnyView(content()) }
    }

    // MARK: Failure View

    /// A view to be shown if the request fails.
    public func failure<Failure: View>(@ViewBuilder _ content: () -> Failure?) -> Self {
        map { $0.failureView = AnyView(content()) }
    }

    // MARK: Private

    private func map(_ closure: (inout LazyImage) -> Void) -> Self {
        var copy = self
        closure(&copy)
        return copy
    }
}

#endif
