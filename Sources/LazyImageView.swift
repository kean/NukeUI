// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Nuke

#if !os(watchOS)

#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if canImport(Gifu)
import Gifu
#endif

import AVKit

/// Lazily loads and displays an image with the given source.
public final class LazyImageView: _PlatformBaseView {

    // MARK: Placeholder View

    #if os(macOS)
    /// An image to be shown while the request is in progress.
    public var placeholderImage: NSImage? { didSet { setPlaceholderImage(placeholderImage) } }

    /// A view to be shown while the request is in progress. For example, can be a spinner.
    public var placeholderView: NSView? { didSet { setPlaceholderView(oldValue, placeholderView) } }
    #else
    /// An image to be shown while the request is in progress.
    public var placeholderImage: UIImage? { didSet { setPlaceholderImage(placeholderImage) } }

    /// A view to be shown while the request is in progress. For example, can be a spinner.
    public var placeholderView: UIView? { didSet { setPlaceholderView(oldValue, placeholderView) } }
    #endif

    /// `.fill` by default.
    public var placeholderViewPosition: SubviewPosition = .fill {
        didSet {
            guard oldValue != placeholderViewPosition, placeholderView != nil else { return }
            setNeedsUpdateConstraints()
        }
    }

    private var placeholderViewConstraints: [NSLayoutConstraint] = []

    // MARK: Failure View

    #if os(macOS)
    /// An image to be shown if the request fails.
    public var failureImage: NSImage? { didSet { setFailureImage(failureImage) } }

    /// A view to be shown if the request fails.
    public var failureView: NSView? { didSet { setFailureView(oldValue, failureView) } }
    #else
    /// An image to be shown if the request fails.
    public var failureImage: UIImage? { didSet { setFailureImage(failureImage) } }

    /// A view to be shown if the request fails.
    public var failureView: UIView? { didSet { setFailureView(oldValue, failureView) } }
    #endif

    /// `.fill` by default.
    public var failureViewPosition: SubviewPosition = .fill {
        didSet {
            guard oldValue != failureViewPosition, failureView != nil else { return }
            setNeedsUpdateConstraints()
        }
    }

    private var failureViewConstraints: [NSLayoutConstraint] = []

    // MARK: Transition

    /// `nil` by default.
    public var transition: Transition?

    /// An animated image transition.
    public struct Transition {
        var style: Style

        init(style: Style) {
            self.style = style
        }

        enum Style { // internal representation
            case fadeIn(parameters: Parameters)
            case custom(closure: (LazyImageView, Nuke.ImageContainer) -> Void)
        }

        struct Parameters { // internal representation
            let duration: TimeInterval
            #if os(iOS) || os(tvOS)
            let options: UIView.AnimationOptions
            #endif
        }

        #if os(iOS) || os(tvOS)
        /// Fade-in transition (cross-fade in case the image view is already
        /// displaying an image).
        public static func fadeIn(duration: TimeInterval, options: UIView.AnimationOptions = .allowUserInteraction) -> Transition {
            Transition(style: .fadeIn(parameters: Parameters(duration: duration, options: options)))
        }
        #else
        /// Fade-in transition (cross-fade in case the image view is already
        /// displaying an image).
        public static func fadeIn(duration: TimeInterval) -> Transition {
            Transition(style: .fadeIn(parameters: Parameters(duration: duration)))
        }
        #endif

        /// Fade-in transition (cross-fade in case the image view is already
        /// displaying an image).
        public static func custom(_ closure: @escaping (LazyImageView, Nuke.ImageContainer) -> Void) -> Transition {
            Transition(style: .custom(closure: closure))
        }

        @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
        init(_ transition: LazyImage.Transition) {
            switch transition.style {
            case .fadeIn(let parameters): self = .fadeIn(duration: parameters.duration)
            }
        }
    }

    // MARK: Underlying Views

    #if os(macOS)
    /// Returns an underlying image view.
    public let imageView = NSImageView()
    #else
    /// Returns an underlying image view.
    public let imageView = UIImageView()
    #endif

    #if os(iOS) || os(tvOS)
    /// Returns an underlying animated image view used for rendering animated images.
    public var animatedImageView: GIFImageView {
        if let animatedImageView = _animatedImageView {
            return animatedImageView
        }
        let animatedImageView = GIFImageView()
        animatedImageView.contentMode = .scaleAspectFill
        animatedImageView.clipsToBounds = true
        _animatedImageView = animatedImageView
        return animatedImageView
    }

    private var _animatedImageView: GIFImageView?
    #endif

    // MARK: Managing Image Tasks

    /// Processors to be applied to the image. `nil` by default.
    public var processors: [ImageProcessing]?

    /// Sets the priority of the image task. The priorit can be changed
    /// dynamically. `nil` by default.
    public var priority: ImageRequest.Priority? {
        didSet {
            if let priority = self.priority {
                imageTask?.priority = priority
            }
        }
    }

    /// Current image task.
    public var imageTask: ImageTask?

    /// The pipeline to be used for download. `shared` by default.
    public var pipeline: ImagePipeline = .shared

    // MARK: Callbacks

    /// Gets called when the request is started.
    public var onStart: ((_ task: ImageTask) -> Void)?

    /// Gets called when the request progress is updated.
    public var onProgress: ((_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void)?

    /// Gets called when the requests finished successfully.
    public var onSuccess: ((_ response: ImageResponse) -> Void)?

    /// Gets called when the requests fails.
    public var onFailure: ((_ response: ImagePipeline.Error) -> Void)?

    /// Gets called when the request is completed.
    public var onCompletion: ((_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void)?

    // MARK: Other Options

    /// `true` by default. If disabled, progressive image scans will be ignored.
    public var isProgressiveImageRenderingEnabled = true

    /// `true` by default. If disabled, animated image rendering will be disabled.
    public var isAnimatedImageRenderingEnabled = true

    /// `true` by default. If enabled, the image view will be cleared before the
    /// new download is started.
    public var isPrepareForReuseEnabled = true

    // MARK: Short Videos

    /// Set to `true` to enable video support. `false` by default.
    public var isExperimentalVideoSupportEnabled = false

    private var videoURL: URL?
    private var videoPreprocessId = 0
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var playerLooper: AnyObject?

    private var isDisplayingContent = false

    // MARK: Initializers

    deinit {
        reset()
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        didInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        didInit()
    }

    private func didInit() {
        addSubview(imageView)
        imageView.pinToSuperview()

        #if !os(macOS)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        #endif
    }

    /// Sets the given source and immediately starts the download.
    public var source: ImageRequestConvertible? {
        didSet { load(source) }
    }

    public override func updateConstraints() {
        super.updateConstraints()

        updatePlaceholderViewConstraints()
        updateFailureViewConstraints()
    }

    /// Cancels current request and prepares the view for reuse.
    public func reset() {
        cancel()

        placeholderView?.isHidden = true
        failureView?.isHidden = true
        imageView.isHidden = true
        imageView.image = nil

        #if os(iOS) || os(tvOS)
        _animatedImageView?.isHidden = true
        _animatedImageView?.image = nil
        #endif

        videoURL.map(TempVideoStorage.shared.removeData(for:))
        videoURL = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil

        isDisplayingContent = false
    }

    /// Cancels current request.
    public func cancel() {
        imageTask?.cancel()
        imageTask = nil

        videoPreprocessId = 0
    }

    // MARK: Loading

    /// Loads an image with the given request.
    private func load(_ request: ImageRequestConvertible?) {
        assert(Thread.isMainThread, "Must be called from the main thread")

        if isExperimentalVideoSupportEnabled {
            ImageDecoders.MP4.register()
        }

        cancel()

        if isPrepareForReuseEnabled {
            reset()
        }

        guard var request = request?.asImageRequest() else {
            let result: Result<ImageResponse, ImagePipeline.Error> = .failure(.dataLoadingFailed(URLError(.unknown)))
            handle(result, isFromMemory: true)
            return
        }

        if let processors = self.processors, !request.processors.isEmpty {
            request.processors = processors
        }

        // Quick synchronous memory cache lookup.
        if let image = pipeline.cache[request] {
            display(image, isFromMemory: true)
            if !image.isPreview { // Final image was downloaded
                didComplete(.success(ImageResponse(container: image, cacheType: .memory)))
                return
            }
        }

        if let priority = self.priority {
            request.priority = priority
        }

        placeholderView?.isHidden = false

        let task = pipeline.loadImage(
            with: request,
            queue: .main,
            progress: { [weak self] response, completedCount, totalCount in
                guard let self = self else { return }
                if self.isProgressiveImageRenderingEnabled, let response = response {
                    self.placeholderView?.isHidden = true
                    self.display(response.container, isFromMemory: false)
                }
                self.onProgress?(response, completedCount, totalCount)
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                self.handle(result, isFromMemory: false)
            }
        )
        imageTask = task
        onStart?(task)
    }

    // MARK: Handling Responses

    private func handle(_ result: Result<ImageResponse, ImagePipeline.Error>, isFromMemory: Bool) {
        placeholderView?.isHidden = true
        switch result {
        case let .success(response):
            display(response.container, isFromMemory: isFromMemory)
        case .failure:
            failureView?.isHidden = false
        }
        self.imageTask = nil
        self.didComplete(result)
    }

    private func didComplete(_ result: Result<ImageResponse, ImagePipeline.Error>) {
        switch result {
        case .success(let response): onSuccess?(response)
        case .failure(let error): onFailure?(error)
        }
        onCompletion?(result)
    }


    private func display(_ container: Nuke.ImageContainer, isFromMemory: Bool) {
        #if os(iOS) || os(tvOS)
        if isAnimatedImageRenderingEnabled, let data = container.data, container.type == .gif {
            if animatedImageView.superview == nil {
                insertSubview(animatedImageView, belowSubview: imageView)
                animatedImageView.pinToSuperview()
            }
            animatedImageView.animate(withGIFData: data)
            animatedImageView.isHidden = false
        } else if isExperimentalVideoSupportEnabled, let data = container.data, container.type == .mp4 {
            playVideo(data)
        } else {
            imageView.image = container.image
            imageView.isHidden = false
        }
        #else
        imageView.image = container.image
        imageView.isHidden = false
        #endif

        if !isFromMemory, let transition = transition {
            runTransition(transition, container)
        }

        // It's used to determine when to perform certain transitions
        isDisplayingContent = true
    }

    public enum SubviewPosition {
        /// Center in the superview.
        case center

        /// Fill the superview.
        case fill
    }

    // MARK: Private (Placeholder View)

    private func setPlaceholderImage(_ placeholderImage: _PlatformImage?) {
        guard let placeholderImage = placeholderImage else {
            placeholderView = nil
            return
        }
        placeholderView = _PlatformImageView(image: placeholderImage)
    }

    private func setPlaceholderView(_ oldView: _PlatformBaseView?, _ newView: _PlatformBaseView?) {
        if let oldView = oldView {
            oldView.removeFromSuperview()
        }
        if let newView = newView {
            addSubview(newView)
            setNeedsUpdateConstraints()
            #if os(iOS) || os(tvOS)
            if let spinner = newView as? UIActivityIndicatorView {
                spinner.startAnimating()
            }
            #endif
        }
    }

    private func updatePlaceholderViewConstraints() {
        NSLayoutConstraint.deactivate(placeholderViewConstraints)
        placeholderViewConstraints = placeholderView?.layout(with: placeholderViewPosition) ?? []
    }

    // MARK: Private (Failure View)

    private func setFailureImage(_ failureImage: _PlatformImage?) {
        guard let failureImage = failureImage else {
            failureView = nil
            return
        }
        failureView = _PlatformImageView(image: failureImage)
    }

    private func setFailureView(_ oldView: _PlatformBaseView?, _ newView: _PlatformBaseView?) {
        if let oldView = oldView {
            oldView.removeFromSuperview()
        }
        if let newView = newView {
            addSubview(newView)
            setNeedsUpdateConstraints()
        }
    }

    private func updateFailureViewConstraints() {
        NSLayoutConstraint.deactivate(failureViewConstraints)
        failureViewConstraints = failureView?.layout(with: failureViewPosition) ?? []
    }

    // MARK: Private (Transitions)

    private func runTransition(_ transition: Transition, _ image: Nuke.ImageContainer) {
        switch transition.style {
        case .fadeIn(let parameters):
            runFadeInTransition(params: parameters)
        case .custom(let closure):
            closure(self, image)
        }
    }

    #if os(iOS) || os(tvOS)

    private func runFadeInTransition(params: Transition.Parameters) {
        guard !isDisplayingContent else { return }
        imageView.alpha = 0
        _animatedImageView?.alpha = 0
        UIView.animate(withDuration: params.duration, delay: 0, options: params.options) {
            self.imageView.alpha = 1
            self._animatedImageView?.alpha = 1
        }
    }

    #elseif os(macOS)

    private func runFadeInTransition(params: Transition.Parameters) {
        guard !isDisplayingContent else { return }
        imageView.layer?.animateOpacity(duration: params.duration)
    }

    #endif

    // MARK: Private (Video)

    private func playVideo(_ data: Data) {
        self.videoPreprocessId += 1
        let requestId = self.videoPreprocessId

        // TODO: Figure out how to optimize it. There should be a way to play
        // a video from memory. If there is none, we should optimize how we work
        // with a file storage.
        TempVideoStorage.shared.storeData(data) { [weak self] url in
            guard self?.videoPreprocessId == requestId else { return }
            self?._playVideoAtURL(url)
        }
    }

    private func _playVideoAtURL(_ url: URL) {
        let playerItem = AVPlayerItem(url: url)
        let player = AVQueuePlayer(playerItem: playerItem)
        let playerLayer = AVPlayerLayer(player: player)
        self.playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)

        getLayer()?.addSublayer(playerLayer)
        playerLayer.frame = bounds
        player.play()

        self.player = player
        self.playerLayer = playerLayer
    }
}

#endif
