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
@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 10.16, *)
public struct LazyImage<Content: View>: View {
    @StateObject private var model = FetchImage()

    private let source: ImageRequest?
    private let imageContainer: ImageContainer?
    private var makeContent: ((LazyImageState) -> Content)?

    #if !os(watchOS)
    private var proxy = LazyImageViewProxy()
    private var onCreated: ((LazyImageView) -> Void)?
    #endif

    // Options
    private var placeholderView: AnyView? = AnyView(Rectangle().foregroundColor(Color(UIColor.secondarySystemBackground)))
    private var failureView: AnyView?
    private var processors: [ImageProcessing]?
    private var priority: ImageRequest.Priority?
    private var pipeline: ImagePipeline = .shared
    private var onDisappearBehavior: DisappearBehavior? = .reset
    private var onStart: ((_ task: ImageTask) -> Void)?
    private var onProgress: ((_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void)?
    private var onSuccess: ((_ response: ImageResponse) -> Void)?
    private var onFailure: ((_ response: Error) -> Void)?
    private var onCompletion: ((_ result: Result<ImageResponse, Error>) -> Void)?
    private var contentMode: LazyImageContentMode?

    // MARK: Initializers

    /// Initializes the image with the given source to be displayed when downloaded.
    public init(source: ImageRequestConvertible?) where Content == Image {
        self.source = source?.asImageRequest()
        self.imageContainer = nil
    }

    /// Initializes the image with the given source to be displayed when downloaded.
    public init(source: ImageRequestConvertible?, @ViewBuilder content: @escaping (LazyImageState) -> Content) {
        self.source = source?.asImageRequest()
        self.imageContainer = nil
        self.makeContent = content
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
    public func contentMode(_ contentMode: LazyImageContentMode?) -> Self {
        map { $0.contentMode = contentMode }
    }
    #endif

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
    public func onFailure(_ closure: @escaping (_ response: Error) -> Void) -> Self {
        map { $0.onFailure = closure }
    }

    /// Gets called when the request is completed.
    public func onCompletion(_ closure: @escaping (_ result: Result<ImageResponse, Error>) -> Void) -> Self {
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

    public var body: some View {
        content
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
            // Making sure it reload if the source changes
            .id(source.map(ImageRequest.ID.init))
            .onReceive(model.$imageContainer) {
                proxy.imageView?.imageContainer = $0
            }
    }

    @ViewBuilder private var content: some View {
        if let makeContent = makeContent {
            makeContent(LazyImageState(model))
        } else {
            makeDefaultContent()
        }
    }

    @ViewBuilder private func makeDefaultContent() -> some View {
        if model.imageContainer != nil {
#if os(watchOS)
            model.view?
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()
#else
            LazyImageViewWrapper(onCreated: onCreated)
                .onReceive(model.$imageContainer) {
                    proxy.imageView?.imageContainer = $0
                }
#endif
        } else if case .failure = model.result {
            failureView
        } else {
            placeholderView
        }
    }

    private func onAppear() {
        model.pipeline = pipeline

        if let imageContainer = self.imageContainer {
            model.load(Just(ImageResponse(container: imageContainer)))
        } else {
            if let processors = processors { model.processors = processors }
            if let priority = priority { model.priority = priority }
            model.onStart = onStart
            model.onProgress = onProgress
            model.onSuccess = onSuccess
            model.onFailure = onFailure
            model.onCompletion = onCompletion
            model.load(source)
        }
    }

    private func onDisappear() {
        guard let behavior = onDisappearBehavior else { return }
        withoutAnimation {
            switch behavior {
            case .reset: model.reset()
            case .cancel: model.cancel()
            }
        }
    }

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

        onCreated?(view)
    }

    #endif
}

@available(iOS 13.0, tvOS 13.0, watchOS 7.0, macOS 10.15, *)
public struct LazyImageState {
    /// Returns the current fetch result.
    public let result: Result<ImageResponse, Error>?

    /// Returns a current error.
    public var error: Error? {
        if case .failure(let error) = result {
            return error
        }
        return nil
    }

    /// Returns the fetched image.
    ///
    /// - note: In case pipeline has `isProgressiveDecodingEnabled` option enabled
    /// and the image being downloaded supports progressive decoding, the `image`
    /// might be updated multiple times during the download.
    public var image: PlatformImage? { imageContainer?.image }

    /// Returns the fetched image.
    ///
    /// - note: In case pipeline has `isProgressiveDecodingEnabled` option enabled
    /// and the image being downloaded supports progressive decoding, the `image`
    /// might be updated multiple times during the download.
    public let imageContainer: ImageContainer?

    /// Returns `true` if the image is being loaded.
    public let isLoading: Bool

    /// The download progress.
    public struct Progress: Equatable {
        /// The number of bytes that the task has received.
        public let completed: Int64

        /// A best-guess upper bound on the number of bytes the client expects to send.
        public let total: Int64
    }

    /// The progress of the image download.
    public let progress: Progress

    init(_ fetchImage: FetchImage) {
        self.result = fetchImage.result
        self.imageContainer = fetchImage.imageContainer
        self.isLoading = fetchImage.isLoading
        self.progress = Progress(completed: fetchImage.progress.completed, total: fetchImage.progress.total)
    }
}

#if !os(watchOS)

public enum LazyImageContentMode {
    case aspectFit
    case aspectFill
    case center
    case fill
}

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
