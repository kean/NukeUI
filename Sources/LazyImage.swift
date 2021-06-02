// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Nuke
import SwiftUI

public typealias ImageRequest = Nuke.ImageRequest
public typealias ImagePipeline = Nuke.ImagePipeline

#if !os(watchOS)

/// Lazily loads and displays an image with the given source.
///
/// The image view is lazy and doesn't know the size of the image before it is
/// downloaded. You must specify the size for the view before loading the image.
/// By default, the image will resize to fill the available space but preserve
/// the aspect ratio. You can change this behavior by passing a different content mode.
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
public struct LazyImage: View {
    private let source: ImageRequest?
    @State private var proxy = LazyImageViewProxy()
    @State private var isPlaceholderHidden = true
    @State private var isFailureViewHidden = true

    // Options
    private var placeholderView: AnyView?
    private var failureView: AnyView?
    private var processors: [ImageProcessing]?
    private var transition: Transition?
    private var priority: ImageRequest.Priority?
    private var pipeline: ImagePipeline = .shared
    private var onStart: ((_ task: ImageTask) -> Void)?
    private var onProgress: ((_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void)?
    private var onSuccess: ((_ response: ImageResponse) -> Void)?
    private var onFailure: ((_ response: ImagePipeline.Error) -> Void)?
    private var onCompletion: ((_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void)?
    private var onCreated: ((LazyImageView) -> Void)?
    private var contentMode: ContentMode?

    // MARK: Content Mode

    #if os(iOS) || os(tvOS)
    /// Sets the content mode for all types of media displayed by the view.
    ///
    /// To change content mode for individual image types, access the underlying
    /// `LazyImageView` instance and update the respective view.
    public func contentMode(_ contentMode: ContentMode?) -> Self {
        map { $0.contentMode = contentMode }
    }
    #endif

    public enum ContentMode {
        case aspectFit
        case aspectFill
        case center
        case fill
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
    public func onStart(_ closure: @escaping (_ task: ImageTask) -> Void) -> Self {
        map { $0.onStart = closure }
    }

    /// Gets called when the request progress is updated.
    public func onProgress(_ closure: @escaping (_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void) -> Self {
        map { $0.onProgress = closure }
    }

    /// Gets called when the requests finished successfully.
    public func onSuccess(_ closure: @escaping (_ response: ImageResponse) -> Void) -> Self {
        map { $0.onSuccess = closure }
    }

    /// Gets called when the requests fails.
    public func onFailure(_ closure: @escaping (_ response: ImagePipeline.Error) -> Void) -> Self {
        map { $0.onFailure = closure }
    }

    /// Gets called when the request is completed.
    public func onCompletion(_ closure: @escaping (_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void) -> Self {
        map { $0.onCompletion = closure }
    }

    /// Returns an underlying image view.
    ///
    /// - parameter configure: A closure that gets called once when the view is
    /// created and allows you to configure it based on your needs.
    public func onCreated(_ configure: ((LazyImageView) -> Void)?) -> Self {
        map { $0.onCreated = configure }
    }

    // MARK: Initializers

    public init(source: ImageRequestConvertible?) {
        self.source = source?.asImageRequest()
    }

    public var body: some View {
        ZStack {
            if !isPlaceholderHidden {
                placeholderView
            }
            if !isFailureViewHidden {
                failureView
            }
            LazyImageViewWrapper(onCreated: onCreated)
        }
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
        onCreated?(view)

        #if os(iOS) || os(tvOS)
        if let contentMode = contentMode {
            view.imageView.contentMode = .init(contentMode)
            view.animatedImageView.contentMode = .init(contentMode)
            view.videoGravity = .init(contentMode)
        }
        #endif

        view.transition = transition.map(LazyImageView.Transition.init)
        view.processors = processors
        view.priority = priority
        view.pipeline = pipeline
        view.onStart = onStart
        view.onProgress = onProgress
        view.onSuccess = onSuccess
        view.onFailure = onFailure
        view.onCompletion = onCompletion

        view.onPlaceholdeViewHiddenUpdated = { isPlaceholderHidden = $0 }
        view.onFailureViewHiddenUpdated = { isFailureViewHidden = $0 }
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
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
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
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
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

#else
/// Lazily loads and displays an image with the given source.
///
/// The image view is lazy and doesn't know the size of the image before it is
/// downloaded. You must specify the size for the view before loading the image.
/// By default, the image will resize to fill the available space but preserve
/// the aspect ratio. You can change this behavior by passing a different content mode.
@available(watchOS 7.0, *)
public struct LazyImage: View {
    // This component offers a limited watchOS support.
    // Eventually the "main" LazyImage should probably also be writetn
    // using jus Swift.

    private let request: ImageRequest?
    private var placeholderView: AnyView?
    private var failureView: AnyView?
    @StateObject private var image = FetchImage()

    public init(source: ImageRequestConvertible?) {
        self.request = source?.asImageRequest()
    }

    private func map(_ closure: (inout LazyImage) -> Void) -> Self {
        var copy = self
        closure(&copy)
        return copy
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
}
#endif
