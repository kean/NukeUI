// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Nuke

#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if canImport(Gifu)
import Gifu
#endif

#warning("should it be based on UIView instead?")
#warning("how will animated image rendering work?")
public final class LazyImageView: _PlatformBaseView {

    #if os(macOS)
    /// An image to be shown while the request is in progress.
    public var placeholder: NSImage? { didSet { setPlaceholder(placeholder )} }
    /// A view to be shown while the request is in progress. For example, can be a spinner.
    public var placeholderView: NSView? { didSet { setPlaceholderView(placeholderView)} }

    public var failureImage: NSImage?
    #else
    /// An image to be shown while the request is in progress.
    public var placeholder: UIImage? { didSet { setPlaceholder(placeholder )} }
    /// A view to be shown while the request is in progress. For example, can be a spinner.
    public var placeholderView: UIView? { didSet { setPlaceholderView(placeholderView)} }

    public var failureImage: UIImage?
    #endif

    #warning("impl")
    /// `.fill` by default.
    public var placeholderPosition: SubviewPosition = .fill {
        didSet {
            guard oldValue != placeholderPosition, placeholderView != nil else {
                return
            }
            setNeedsUpdateConstraints()
        }
    }

    private var placeholderConstraints: [NSLayoutConstraint] = []

    public enum ImageType {
        case success, placeholder, failure
    }

    #warning("impl")
    public var isPrepareForReuseEnabled = true

    #warning("impl")
    public var isProgressiveRenderingEnabled = true

    #warning("impl")
    public var isAnimatedImageRenderingEnabled = true

    public func setTransition(_ transition: Any, for type: ImageType) {
        #warning("implement")
    }

    #if os(iOS) || os(tvOS)

    /// Set a custom content mode to be used for each image type (placeholder, success,
    /// failure).
    public func setContentMode(_ contentMode: UIView.ContentMode, for type: ImageType = .success) {
        #warning("impl")
    }

    #endif

    #warning("other options like managing priority and auto-retrying")

    // MARK: Underlying Views

    #if os(macOS)
    /// Returns an underlying image view.
    public let imageView = NSImageView()
    #else
    /// Returns an underlying image view.
    public let imageView = UIImageView()
    #endif

    #if canImport(Gifu)
    /// Returns an underlying animated image view used for rendering animated images.
    public lazy var animatedImageView = GIFImageView()
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
    public var onFinished: ((_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void)?

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

    #warning("rework this")
    public var source: ImageRequestConvertible? {
        didSet {
            load(source)
        }
    }

    public override func updateConstraints() {
        super.updateConstraints()

        updatePlaceholderConstraints()
    }

    // MARK: Loading

    /// Loads an image with the given request.
    private func load(_ request: ImageRequestConvertible?) {
        assert(Thread.isMainThread, "Must be called from the main thread")

        cancel()

        guard var request = request?.asImageRequest() else {
            // TODO: handle as failure
            return
        }

        #warning("TODO: in-memory lookup")

        if let priority = self.priority {
            request.priority = priority
        }

        placeholderView?.isHidden = false

        let task = pipeline.loadImage(
            with: request,
            queue: .main,
            progress: { [weak self] response, completedCount, totalCount in
                #warning("TODO: implement progressive decoding")
                self?.onProgress?(response, completedCount, totalCount)
            },
            completion: { [weak self] result in
                #warning("temo")
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
                self?.handle(result, isFromMemory: false)
                self?.onFinished?(result)
                }
            }
        )
        imageTask = task
        onStarted?(task)
    }

    public func cancel() {
        imageTask?.cancel()
        imageTask = nil
    }

    // MARK: Handling Responses

    private func handle(_ result: Result<ImageResponse, ImagePipeline.Error>, isFromMemory: Bool) {
        placeholderView?.isHidden = true

        switch result {
        case let .success(response):
            display(response.container, isFromMemory, .success)
        case .failure:
            // TODO: Display failureImage
             break
        }
        self.imageTask = nil
    }

    private func display(_ container: Nuke.ImageContainer, _ isFromMemory: Bool, _ response: ImageType) {
        // TODO: Add support for animated transitions and other options
        #if canImport(Gifu)
        if let data = container.data, container.type == .gif {
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
    }

    var visibleView: ContentViewType = .regular {
        didSet {
            switch visibleView {
            case .regular:
                imageView.isHidden = false
                #if canImport(Gifu)
                animatedImageView.isHidden = true
                #endif
            case .animated:
                imageView.isHidden = true
                #if canImport(Gifu)
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

    // MARK: Placeholder

    private func setPlaceholder(_ placeholder: _PlatformImage?) {
        guard let placeholder = placeholder else {
            return
        }
        placeholderView = _PlatformImageView(image: placeholder)
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

    private func updatePlaceholderConstraints() {
        NSLayoutConstraint.deactivate(placeholderConstraints)

        if let placeholderView = self.placeholderView {
            switch placeholderPosition {
            case .center: placeholderConstraints = placeholderView.centerInSuperview()
            case .fill: placeholderConstraints = placeholderView.pinToSuperview()
            }
        }
    }
}
