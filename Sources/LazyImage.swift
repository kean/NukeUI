// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Nuke
import SwiftUI
import Combine

public typealias ImageRequest = Nuke.ImageRequest
public typealias ImagePipeline = Nuke.ImagePipeline
public typealias ImageContainer = Nuke.ImageContainer

/// Lazily loads and displays images.
///
/// The image view is lazy and doesn't know the size of the image before it is
/// downloaded. You must specify the size for the view before loading the image.
/// By default, the image will resize to fill the available space but preserve
/// the aspect ratio. You can change this behavior by passing a different content mode.
@available(iOS 13.0, tvOS 13.0, watchOS 7.0, macOS 10.15, *)
public struct LazyImage: View {
    private let source: ImageRequest?
    private let imageContainer: ImageContainer?

    #if os(watchOS)
    @StateObject private var image = FetchImage()
    #else
    private var imageView: LazyImageView?
    private var proxy = LazyImageViewProxy()
    private var onCreated: ((LazyImageView) -> Void)?
    @State private var isPlaceholderHidden = true
    @State private var isFailureViewHidden = true
    #endif

    // Options
    private var placeholderView: AnyView?
    private var failureView: AnyView?
    private var processors: [ImageProcessing]?
    private var transition: Transition?
    private var priority: ImageRequest.Priority?
    private var pipeline: ImagePipeline = .shared
    private var onDisappearBehavior: DisappearBehavior? = .reset
    private var onStart: ((_ task: ImageTask) -> Void)?
    private var onProgress: ((_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void)?
    private var onSuccess: ((_ response: ImageResponse) -> Void)?
    private var onFailure: ((_ response: ImagePipeline.Error) -> Void)?
    private var onCompletion: ((_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void)?
    private var contentMode: ContentMode?

    // MARK: Initializers

    /// Initializes the image with the given source to be displayed later.
    public init(source: ImageRequestConvertible?) {
        self.source = source?.asImageRequest()
        self.imageContainer = nil
    }

    /// Initializes the image with the given image to be displayed immediately.
    ///
    /// Supports platform images (`UIImage`) and `ImageContainer`. Use `ImageContainer`
    /// if you need to pass additional parameters alongside the image, like
    /// original image data for GIF rendering.
    public init(image: ImageContainer) {
        self.source = nil
        self.imageContainer = image
    }

    #if os(macOS)
    /// Initializes the image with the given image to be displayed immediately.
    public init(image: NSImage) {
        self.init(image: ImageContainer(image: image))
    }
    #else
    /// Initializes the image with the given image to be displayed immediately.
    public init(image: UIImage) {
        self.init(image: ImageContainer(image: image))
    }
    #endif

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

    #if !os(watchOS)

    /// A transition to be run when displaying an image.
    public func transition(_ transition: Transition?) -> Self {
        map { $0.transition = transition }
    }

    #endif

    /// An animated transition.
    public enum Transition {
        /// Fade-in transition.
        case fadeIn(duration: TimeInterval)
    }

    // MARK: Managing Image Tasks

    /// Sets processors to be applied to the image.
    ///
    /// If you pass an image requests with a non-empty list of processors as
    /// a source, your processors will be applied instead.
    public func processors(_ processors: [ImageProcessing]?) -> Self {
        map { $0.processors = processors }
    }

    /// Sets the priority of the requests.
    public func priority(_ priority: ImageRequest.Priority?) -> Self {
        map { $0.priority = priority }
    }

    /// Changes the underlying pipeline used for image loading.
    public func pipeline(_ pipeline: ImagePipeline) -> Self {
        map { $0.pipeline = pipeline }
    }

    public enum DisappearBehavior {
        /// Resets the image clearing all the used memory along with the
        /// presentation state.
        case reset
        /// Cancels the current request but keeps the presentation state of
        /// the already displayed image.
        case cancel
    }

    /// Override the behavior on disappear. By default, the view is reset.
    public func onDisappear(_ behavior: DisappearBehavior?) -> Self {
        map { $0.onDisappearBehavior = behavior }
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

    #if !os(watchOS)

    /// Returns an underlying image view.
    ///
    /// - parameter configure: A closure that gets called once when the view is
    /// created and allows you to configure it based on your needs.
    public func onCreated(_ configure: ((LazyImageView) -> Void)?) -> Self {
        map { $0.onCreated = configure }
    }
    #endif

    // MARK: Body

    #if !os(watchOS)

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
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        // Making sure it reloads and onAppear/onDisappear callbacks are called
        // when the source changes
        .id(source.map(ImageRequest.ID.init))
    }

    private func onAppear() {
        if let container = self.imageContainer {
            proxy.imageView?.imageContainer = container
        } else {
            proxy.imageView?.source = source
        }
    }

    private func onDisappear() {
        guard let behavior = onDisappearBehavior,
              let imageView = proxy.imageView else { return }
        switch behavior {
        case .reset: imageView.reset()
        case .cancel: imageView.cancel()
        }
    }

    #else

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
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        // Making sure it reload if the source changes
        .id(source.map(ImageRequest.ID.init))
    }

    private func onAppear() {
        image.pipeline = pipeline

        // TODO: Make sure we don't need setFailureType
        if let imageContainer = self.imageContainer {
            image.load(Just(ImageResponse(container: imageContainer)).setFailureType(to: ImagePipeline.Error.self))
        } else {
            if let processors = processors { image.processors = processors }
            if let priority = priority { image.priority = priority }
            image.onStart = onStart
            image.onProgress = onProgress
            image.onSuccess = onSuccess
            image.onFailure = onFailure
            image.onCompletion = onCompletion
            image.load(source)
        }
    }

    private func onDisappear() {
        guard let behavior = onDisappearBehavior else { return }
        switch behavior {
        case .reset: image.reset()
        case .cancel: image.cancel()
        }
    }

    #endif

    // MARK: Private

    private func map(_ closure: (inout LazyImage) -> Void) -> Self {
        var copy = self
        closure(&copy)
        return copy
    }

    #if !os(watchOS)

    private func onCreated(_ view: LazyImageView) {
        proxy.imageView = view

        #if os(iOS) || os(tvOS)
        if let contentMode = contentMode {
            view.imageView.contentMode = .init(contentMode)
            view.animatedImageView.contentMode = .init(contentMode)
            view.videoPlayerView.videoGravity = .init(contentMode)
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

        onCreated?(view)
    }

    #endif
}

#if !os(watchOS)

private final class LazyImageViewProxy {
    var imageView: LazyImageView?
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

#endif
