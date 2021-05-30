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

#if os(macOS)
public typealias _PlatformBaseView = NSView
#else
public typealias _PlatformBaseView = UIView
#endif

#warning("should it be based on UIView instead?")
#warning("how will animated image rendering work?")
public final class LazyImageView: _PlatformBaseView {

    #warning("impl")
    #if os(macOS)
    public var placeholder: NSImage?
    #warning("note on that you can show an activity indicator view this way")
    public var placeholderView: NSView?

    public var failureImage: NSImage?
    #else
    public var placeholder: UIImage?
    public var placeholderView: UIView?

    public var failureImage: UIImage?
    #endif

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

    /// Current image task.
    public var imageTask: ImageTask?

    /// The pipeline to be used for download. `shared` by default.
    public var pipeline: ImagePipeline = .shared

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

    /// Gets called when the request is started.
    public var onStarted: ((_ task: ImageTask) -> Void)?

    /// Gets called when the request progress is updated.
    public var onProgress: ((_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void)?

    /// Gets called when the request is completed.
    public var onFinished: ((_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void)?

    #warning("other options like managing priority and auto-retrying")

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

    /// Loads an image with the given request.
    private func load(_ request: ImageRequestConvertible?) {
        assert(Thread.isMainThread, "Must be called from the main thread")

        cancel()

        guard let request = request?.asImageRequest() else {
            // TODO: handle as failure
            return
        }


        let task = pipeline.loadImage(
            with: request,
            queue: .main,
            progress: { [weak self] response, completedCount, totalCount in
                self?.onProgress?(response, completedCount, totalCount)
            },
            completion: { [weak self] result in
                self?.handle(result, isFromMemory: false)
                self?.onFinished?(result)
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
                addSubview(animatedImageView)
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
}

private extension UIView {
    func pinToSuperview() {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview!.topAnchor),
            bottomAnchor.constraint(equalTo: superview!.bottomAnchor),
            leftAnchor.constraint(equalTo: superview!.leftAnchor),
            rightAnchor.constraint(equalTo: superview!.rightAnchor)
        ])
    }

    func centerInSuperview() {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: superview!.centerXAnchor),
            centerYAnchor.constraint(equalTo: superview!.centerYAnchor)
        ])
    }
}
