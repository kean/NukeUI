// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Nuke
import SwiftUI

public typealias ImageRequest = Nuke.ImageRequest
public typealias ImagePipeline = Nuke.ImagePipeline

/// Lazily loads and displays an image with the given source.
///
/// Because the view is lazy, the image view doesn't know its size before the
/// image is downloaded. The user must specify the size for the view and the
/// image will take all of the available space. By default, it fills the space,
/// but you can change the content mode.
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public struct LazyImage: View {
    private let source: ImageRequest?
    @State private var proxy = LazyImageViewProxy()

    // Options
    private var placeholderView: AnyView?
    private var failureView: AnyView?
    private var processors: [ImageProcessing]?
    private var transition: Transition?
    private var priority: ImageRequest.Priority?
    private var pipeline: ImagePipeline = .shared
    private var onStarted: ((_ task: ImageTask) -> Void)?
    private var onProgress: ((_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void)?
    private var onCompletion: ((_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void)?
    private var onImageViewCreated: ((LazyImageView) -> Void)?
    private var contentMode: ContentMode?

    // MARK: Content Mode

    /// Sets the displayed image content mode.
    public func contentMode(_ contentMode: ContentMode?) -> Self {
        map { $0.contentMode = contentMode }
    }

    public enum ContentMode {
        case aspectFit
        case aspectFill
        case center
        case fill
    }

    // MARK: Placeholder View

    #warning("this probably needs to be redone in SwiftUI")

    /// An image to be shown while the request is in progress.
    public func placeholder<Placeholder: View>(@ViewBuilder _ content: () -> Placeholder?) -> Self {
        map { $0.placeholderView = AnyView(content()) }
    }

    // MARK: Failure View

    /// A view to be shown if the request fails.
    public func failure<Failure: View>(@ViewBuilder _ content: () -> Failure?) -> Self {
        map { $0.failureView = AnyView(content()) }
    }

    // MARK: Transition

    /// A transition to be run when displaying an image.
    public func transition(_ transition: Transition?) -> Self {
        map { $0.transition = transition }
    }

    /// An animated image transition.
    public struct Transition {
        var style: Style

        enum Style { // internal representation
            case fadeIn(parameters: Parameters)
        }

        struct Parameters { // internal representation
            let duration: TimeInterval
        }

        /// Fade-in transition (cross-fade in case the image view is already
        /// displaying an image).
        public static func fadeIn(duration: TimeInterval) -> Transition {
            Transition(style: .fadeIn(parameters: Parameters(duration: duration)))
        }
    }

    // MARK: Managing Image Tasks

    public func processors(_ processors: [ImageProcessing]?) -> Self {
        map { $0.processors = processors }
    }

    public func priority(_ priority: ImageRequest.Priority?) -> Self {
        map { $0.priority = priority }
    }

    /// Changes the underlying pipeline used for image loading.
    public func pipeline(_ pipeline: ImagePipeline) -> Self {
        map { $0.pipeline = pipeline }
    }

    // MARK: Callbacks

    /// Gets called when the request is started.
    public func onStarted(_ closure: @escaping (_ task: ImageTask) -> Void) -> Self {
        map { $0.onStarted = closure }
    }

    /// Gets called when the request progress is updated.
    public func onProgress(_ closure: @escaping (_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void) -> Self {
        map { $0.onProgress = closure }
    }

    /// Gets called when the request is completed.
    public func onCompletion(_ closure: @escaping (_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void) -> Self {
        map { $0.onCompletion = closure }
    }

    /// Returns an underlying image view.
    ///
    /// - parameter configure: A closure that gets called once when the view is
    /// created and allows you to configure it based on your needs.
    public func onImageViewCreated(_ configure: @escaping (LazyImageView) -> Void) -> Self {
        map { $0.onImageViewCreated = configure }
    }

    // MARK: Initializers

    public init(source: ImageRequestConvertible?) {
        self.source = source?.asImageRequest()
    }

    public var body: some View {
        LazyImageViewWrapper(onCreated: onCreated)
            .onAppear { proxy.load(source) }
            .onDisappear(perform: proxy.reset)
            // Making sure it reload if the source changes
            .id(source.map(ImageRequest.ID.init))
    }

    private func map(_ closure: (inout LazyImage) -> Void) -> Self {
        var copy = self
        closure(&copy)
        return copy
    }

    private func onCreated(_ view: LazyImageView) {
        proxy.imageView = view
        onImageViewCreated?(view)

        #if os(iOS) || os(tvOS)
        if let contentMode = contentMode {
            view.imageView.contentMode = .init(contentMode)
            view.animatedImageView.contentMode = .init(contentMode)
        }
        #endif
        view.placeholderView = placeholderView.map(toPlatformView)
        view.failureView = failureView.map(toPlatformView)
        view.transition = transition.map(LazyImageView.Transition.init)
        view.processors = processors
        view.priority = priority
        view.pipeline = pipeline
        view.onStarted = onStarted
        view.onProgress = onProgress
        view.onCompletion = onCompletion
    }
}

private extension ImageRequest {
    struct ID: Hashable {
        let imageId: String?
        let priority: ImageRequest.Priority
        let options: ImageRequest.Options

        init(_ request: ImageRequest) {
            self.imageId = request.imageId
            self.priority = request.priority
            self.options = request.options
        }
    }
}

private final class LazyImageViewProxy {
    var imageView: LazyImageView?

    func load(_ request: ImageRequest?) {
        imageView?.source = request
    }

    func reset() {
        imageView?.reset()
    }
}

#if os(macOS)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
private struct LazyImageViewWrapper: NSViewRepresentable {
    var onCreated: (LazyImageView) -> Void

    func makeNSView(context: Context) -> LazyImageView {
        let view = LazyImageView()
        onCreated(view)
        return view
    }

    func updateNSView(_ imageView: LazyImageView, context: Context) {
        // Do nothing
    }
}
#else
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
private struct LazyImageViewWrapper: UIViewRepresentable {
    var onCreated: (LazyImageView) -> Void

    func makeUIView(context: Context) -> LazyImageView {
        let view = LazyImageView()
        onCreated(view)
        return view
    }

    func updateUIView(_ imageView: LazyImageView, context: Context) {
        // Do nothing
    }
}
#endif
