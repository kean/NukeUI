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

#warning("hide these?")
#if os(macOS)
public typealias PlatformImageView = NSImageView
#else
public typealias PlatformImageView = UIImageView
#endif

#warning("should it be based on UIView instead?")
#warning("how will animated image rendering work?")
public final class URLImageView: PlatformImageView {

    #warning("impl")
    #if os(macOS)
    public var placeholder: NSImage?
    #warning("note on that you can show an activity indicator view this way")
    public var placeholderView: NSView?
    #else
    public var placeholder: UIImage?
    public var placeholderView: UIView?
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

    /// Loads an image with the given request.
    public func load(
        _ request: ImageRequestConvertible?,
        completion: @escaping ((_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void)
    ) {
        load(request, progress: nil, completion: completion)
    }

    /// Loads an image with the given request.
    public func load(
        _ request: ImageRequestConvertible?,
        progress: ((_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void)? = nil,
        completion: ((_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void)? = nil
    ) {
        assert(Thread.isMainThread, "Must be called from the main thread")

        cancel()

        guard let request = request?.asImageRequest() else {
            // TODO: handle as failure
            return
        }

        imageTask = pipeline.loadImage(with: request, queue: .main, progress: { response, completedCount, totalCount in
            progress?(response, completedCount, totalCount)
        }, completion: { [weak self] result in
            self?.handle(result, isFromMemory: false)
            completion?(result)
        })
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

    private func display(_ container: ImageContainer, _ isFromMemory: Bool, _ response: ImageType) {
        // TODO: Add support for animated transitions and other options
        self.image = container.image
    }
}
