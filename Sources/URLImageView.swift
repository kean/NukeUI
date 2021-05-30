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

#if os(macOS)
public typealias URLBaseImageView = NSImageView
public typealias URLPlatformImage = NSImage
#else
public typealias URLBaseImageView = UIImageView
public typealias URLPlatformImage = UIImage
#endif

public final class URLImageView: URLBaseImageView {

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

    #if os(iOS) || os(tvOS) || os(macOS)

    private func display(_ container: ImageContainer, _ isFromMemory: Bool, _ response: ResponseType) {
        // TODO: Add support for animated transitions and other options
        self.image = container.image
    }

    #elseif os(watchOS)

    private func display(_ image: ImageContainer, _ isFromMemory: Bool, _ response: ImageLoadingOptions.ResponseType) {
        self.image = container.image
    }

    #endif
}

private enum ResponseType {
    case success, failure, placeholder
}
