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

    private let request: ImageRequest?
    private let requestId: ImageRequest.ID?

    #if !os(watchOS)
    private var onCreated: ((ImageView) -> Void)?
    #endif

    // Options
    private var makeContent: ((LazyImageState) -> Content)?
    private var animation: Animation? = .default
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

    #if !os(watchOS)
    /// Loads and displays an image from the given URL when the view appears on screen.
    ///
    /// - Parameters:
    ///   - source: The image source (`String`, `URL`, `URLRequest`, or `ImageRequest`)
    ///   - contentMode: Sets the content mode of the displayed media. By default, `aspectFill`.
    ///   The image is resizable by default.
    public init(source: ImageRequestConvertible?, contentMode: LazyImageContentMode = .aspectFill) where Content == SwiftUI.Image {
        self.request = source?.asImageRequest()
        self.requestId = request.map(ImageRequest.ID.init)
        self.contentMode = contentMode
    }
    #else
    /// Loads and displays an image from the given URL when the view appears on screen.
    ///
    /// - Parameters:
    ///   - source: The image source (`String`, `URL`, `URLRequest`, or `ImageRequest`)
    public init(source: ImageRequestConvertible?) where Content == Image {
        self.request = source?.asImageRequest()
        self.requestId = request.map(ImageRequest.ID.init)
    }
    #endif

    /// Loads and displays an image from the given URL when the view appears on screen.
    ///
    /// When an image is loaded, the `image` content is shown; when no image is
    /// available, the `placeholder` is shown.
    ///
    /// - Parameters:
    ///   - source: The image source (`String`, `URL`, `URLRequest`, or `ImageRequest`)
    ///   - content: The view to show when the image is loaded.
    ///   - placeholder: The view to show while the image is still loading.
    ///   - failure: The view to show when the image fails to load.
//    public init<I, P, F>(source: ImageRequestConvertible?, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P, @ViewBuilder failure: @escaping (Error) -> F) where Content == _ConditionalContent<_ConditionalContent<I, F>,  P>, I: View, P: View, F: View {
//        self.init(source: source) { state in
//            if let image = state.image {
//                content(image)
//            } else if let error = state.error {
//                failure(error)
//            } else {
//                placeholder()
//            }
//        }
//    }

    /// Loads and displays an image from the given URL when the view appears on screen.
    ///
    /// - Parameters:
    ///   - source: The image source (`String`, `URL`, `URLRequest`, or `ImageRequest`)
    ///   - content: The view to show for each of the image loading states.
    ///
    /// ```swift
    /// LazyImage(source: $0) { state in
    ///     if let image = state.image {
    ///         image // Displays the loaded image.
    ///     } else if state.error != nil {
    ///         Color.red // Indicates an error.
    ///     } else {
    ///         Color.blue // Acts as a placeholder.
    ///     }
    /// }
    /// ```
    public init(source: ImageRequestConvertible?, @ViewBuilder content: @escaping (LazyImageState) -> Content) {
        self.request = source?.asImageRequest()
        self.requestId = request.map(ImageRequest.ID.init)
        self.makeContent = content
    }

    // MARK: Animation

    /// Animations to be used when displaying the loaded images. By default, `.default`.
    ///
    /// - note: Animation isn't used when image is available in memory cache.
    public func animation(_ animation: Animation?) -> Self {
        map { $0.animation = animation }
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
    public func onCreated(_ configure: ((ImageView) -> Void)?) -> Self {
        map { $0.onCreated = configure }
    }
    #endif

    // MARK: Body

    public var body: some View {
        // Using ZStack to add an identity to the view to prevent onAppear from
        // getting called whenever the content changes.
        ZStack {
            content
        }
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onChange(of: requestId) { _ in model.load(request) }
    }

    @ViewBuilder private var content: some View {
        if let makeContent = makeContent {
            makeContent(LazyImageState(model))
        } else {
            makeDefaultContent()
        }
    }

    @ViewBuilder private func makeDefaultContent() -> some View {
        if model.image != nil {
            #if os(watchOS)
            model.view?
                .resizable()
                .aspectRatio(contentMode: contentMode == .aspectFit ? .fit : .fill)
            #else
            Image(onCreated: onCreated, model: model)
            #endif
        } else {
            Rectangle().foregroundColor(Color.secondary)
        }
    }

    private func onAppear() {
        // Unfortunately, you can't modify @State directly in the properties
        // that set these options.
        model.animation = animation
        if let processors = processors { model.processors = processors }
        if let priority = priority { model.priority = priority }
        model.pipeline = pipeline
        model.onStart = onStart
        model.onProgress = onProgress
        model.onSuccess = onSuccess
        model.onFailure = onFailure
        model.onCompletion = onCompletion

        model.load(request)
    }

    private func onDisappear() {
        guard let behavior = onDisappearBehavior else { return }
        switch behavior {
        case .reset: model.reset()
        case .cancel: model.cancel()
        }
    }

    // MARK: Private

    private func map(_ closure: (inout LazyImage) -> Void) -> Self {
        var copy = self
        closure(&copy)
        return copy
    }

    #if !os(watchOS)

    private func onCreated(_ view: ImageView) {
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

    /// Returns an image view.
    public var image: SwiftUI.Image? {
#if os(macOS)
        return imageContainer.map { SwiftUI.Image(nsImage: $0.image) }
#else
        return imageContainer.map { SwiftUI.Image(uiImage: $0.image) }
#endif
    }

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

#warning("TODO: get rid of this")
public enum LazyImageContentMode {
    case aspectFit
    case aspectFill
    case center
}

#if os(macOS)
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
private struct Image: NSViewRepresentable {
    var onCreated: (ImageView) -> Void
    @ObservedObject var model: FetchImage

    func makeNSView(context: Context) -> ImageView {
        let view = ImageView()
        onCreated(view)
        return view
    }

    func updateNSView(_ imageView: ImageView, context: Context) {
        guard imageView.imageContainer?.image !== model.imageContainer?.image else { return }
        imageView.imageContainer = model.imageContainer
    }
}
#else
@available(iOS 13.0, tvOS 13.0, macOS 10.15, *)
private struct Image: UIViewRepresentable {
    var onCreated: (ImageView) -> Void
    @ObservedObject var model: FetchImage

    func makeUIView(context: Context) -> ImageView {
        let imageView = ImageView()
        onCreated(imageView)
        return imageView
    }

    func updateUIView(_ imageView: ImageView, context: Context) {
        guard imageView.imageContainer?.image !== model.imageContainer?.image else { return }
        imageView.imageContainer = model.imageContainer
    }
}

final class ImageViewWrapper: _PlatformBaseView {
    let imageView = ImageView()

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.imageView
    }

    private var layoutConstraints: [NSLayoutConstraint] = []

    override func updateConstraintsIfNeeded() {
        super.updateConstraintsIfNeeded()
    }
}
#endif

#endif
