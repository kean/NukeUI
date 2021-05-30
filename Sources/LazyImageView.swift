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

/// Lazily loads and displays an image with the given source.
public final class LazyImageView: _PlatformBaseView {

    // MARK: Placeholder View

    #if os(macOS)
    /// An image to be shown while the request is in progress.
    public var placeholderImage: NSImage? { didSet { setPlaceholderImage(placeholderImage) } }

    /// A view to be shown while the request is in progress. For example, can be a spinner.
    public var placeholderView: NSView? { didSet { setPlaceholderView(placeholderView) } }
    #else
    /// An image to be shown while the request is in progress.
    public var placeholderImage: UIImage? { didSet { setPlaceholderImage(placeholderImage) } }

    /// A view to be shown while the request is in progress. For example, can be a spinner.
    public var placeholderView: UIView? { didSet { setPlaceholderView(placeholderView) } }
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
    public var failureView: NSView? { didSet { setFailureView(failureView) } }
    #else
    /// An image to be shown if the request fails.
    public var failureImage: UIImage? { didSet { setFailureImage(failureImage) } }

    /// A view to be shown if the request fails.
    public var failureView: UIView? { didSet { setFailureView(failureView) } }
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
        _animatedImageView = animatedImageView
        return animatedImageView
    }

    private var _animatedImageView: GIFImageView?
    #endif

    // MARK: Managing Image Tasks

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
    public var onStarted: ((_ task: ImageTask) -> Void)?

    /// Gets called when the request progress is updated.
    public var onProgress: ((_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void)?

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

    // MARK: Initializers

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

    #if os(iOS) || os(tvOS)
    /// Cancels current request and prepares the view for reuse.
    public func prepareForReuse() {
        _prepareForReuse()
    }
    #else
    /// Cancels current request and prepares the view for reuse.
    public override func prepareForReuse() {
        _prepareForReuse()
    }
    #endif

    private func _prepareForReuse() {
        cancel()

        placeholderView?.isHidden = true
        failureView?.isHidden = true
        imageView.isHidden = true
        imageView.image = nil

        #if os(iOS) || os(tvOS)
        _animatedImageView?.isHidden = true
        _animatedImageView?.image = nil
        #endif
    }

    /// Cancels current request.
    public func cancel() {
        imageTask?.cancel()
        imageTask = nil
    }

    // MARK: Loading

    /// Loads an image with the given request.
    private func load(_ request: ImageRequestConvertible?) {
        assert(Thread.isMainThread, "Must be called from the main thread")

        cancel()

        if isPrepareForReuseEnabled {
            prepareForReuse()
        }

        guard var request = request?.asImageRequest() else {
            let result: Result<ImageResponse, ImagePipeline.Error> = .failure(.dataLoadingFailed(URLError(.unknown)))
            handle(result, isFromMemory: true)
            onCompletion?(result)
            return
        }

        // Quick synchronous memory cache lookup.
        if let image = pipeline.cache[request] {
            display(image, isFromMemory: true)
            if !image.isPreview { // Final image was downloaded
                onCompletion?(.success(ImageResponse(container: image, cacheType: .memory)))
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
                self.onCompletion?(result)
            }
        )
        imageTask = task
        onStarted?(task)
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
    }

    private func display(_ container: Nuke.ImageContainer, isFromMemory: Bool) {
        // TODO: Add support for animated transitions and other options
        #if os(iOS) || os(tvOS)
        if isAnimatedImageRenderingEnabled, let data = container.data, container.type == .gif {
            if animatedImageView.superview == nil {
                insertSubview(animatedImageView, belowSubview: imageView)
                animatedImageView.pinToSuperview()
            }
            animatedImageView.animate(withGIFData: data)
            visibleView = .animated
        } else {
            imageView.image = container.image
            visibleView = .regular
        }
        #else
        imageView.image = container.image
        #endif

        if !isFromMemory, let transition = transition {
            runTransition(transition)
        }
    }

    var visibleView: ContentViewType = .regular {
        didSet {
            switch visibleView {
            case .regular:
                imageView.isHidden = false
                #if os(iOS) || os(tvOS)
                animatedImageView.isHidden = true
                #endif
            case .animated:
                imageView.isHidden = true
                #if os(iOS) || os(tvOS)
                animatedImageView.isHidden = false
                #endif
            }
        }
    }

    enum ContentViewType {
        case regular, animated
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

    private func setPlaceholderView(_ view: _PlatformBaseView?) {
        if let previousView = placeholderView {
            previousView.removeFromSuperview()
        }
        if let newView = view {
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

        if let placeholderView = self.placeholderView {
            switch placeholderViewPosition {
            case .center: placeholderViewConstraints = placeholderView.centerInSuperview()
            case .fill: placeholderViewConstraints = placeholderView.pinToSuperview()
            }
        }
    }

    // MARK: Private (Failure View)

    private func setFailureImage(_ failureImage: _PlatformImage?) {
        guard let failureImage = failureImage else {
            failureView = nil
            return
        }
        failureView = _PlatformImageView(image: failureImage)
    }

    private func setFailureView(_ view: _PlatformBaseView?) {
        if let previousView = failureView {
            previousView.removeFromSuperview()
        }
        if let newView = view {
            addSubview(newView)
            setNeedsUpdateConstraints()
        }
    }

    private func updateFailureViewConstraints() {
        NSLayoutConstraint.deactivate(failureViewConstraints)

        if let failureView = self.failureView {
            switch failureViewPosition {
            case .center: failureViewConstraints = failureView.centerInSuperview()
            case .fill: failureViewConstraints = failureView.pinToSuperview()
            }
        }
    }

    // MARK: Private (Transitions)

    private func runTransition(_ transition: Transition) {
        switch transition.style {
        case .fadeIn(let parameters):
            runFadeInTransition(params: parameters)
        }
    }

    #if os(iOS) || os(tvOS)

    private func runFadeInTransition(params: Transition.Parameters) {
        imageView.alpha = 0
        _animatedImageView?.alpha = 0
        UIView.animate(withDuration: params.duration, delay: 0, options: params.options) {
            self.imageView.alpha = 1
            self._animatedImageView?.alpha = 1
        }
    }

    #elseif os(macOS)

    private func runFadeInTransition(params: Transition.Parameters) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.duration = params.duration
        animation.fromValue = 0
        animation.toValue = 1
        #if os(iOS) || os(tvOS)
        imageView?.layer?.add(animation, forKey: "imageTransition")
        _animatedImageView?.layer?.add(animation, forKey: "imageTransition")
        #endif
    }

    #endif
}


#endif
