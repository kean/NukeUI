// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation

#if !os(watchOS)

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import SwiftUI
import Nuke

#if os(macOS)
public typealias _PlatformBaseView = NSView
typealias _PlatformImage = NSImage
typealias _PlatformImageView = NSImageView
#else
public typealias _PlatformBaseView = UIView
typealias _PlatformImage = UIImage
typealias _PlatformImageView = UIImageView
#endif

extension _PlatformBaseView {
    @discardableResult
    func pinToSuperview() -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            topAnchor.constraint(equalTo: superview!.topAnchor),
            bottomAnchor.constraint(equalTo: superview!.bottomAnchor),
            leftAnchor.constraint(equalTo: superview!.leftAnchor),
            rightAnchor.constraint(equalTo: superview!.rightAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints
    }

    @discardableResult
    func centerInSuperview() -> [NSLayoutConstraint] {
        translatesAutoresizingMaskIntoConstraints = false
        let constraints = [
            centerXAnchor.constraint(equalTo: superview!.centerXAnchor),
            centerYAnchor.constraint(equalTo: superview!.centerYAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
        return constraints
    }

    @discardableResult
    func layout(with position: LazyImageView.SubviewPosition) -> [NSLayoutConstraint] {
        switch position {
        case .center: return centerInSuperview()
        case .fill: return pinToSuperview()
        }
    }

    func getLayer() -> CALayer? {
        layer // Optional on macOS but not on iOS
    }
}

extension CALayer {
    func animateOpacity(duration: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.duration = duration
        animation.fromValue = 0
        animation.toValue = 1
        add(animation, forKey: "imageTransition")
    }
}

#if os(macOS)
extension NSView {
    func setNeedsUpdateConstraints() {
        needsUpdateConstraints = true
    }
}
#endif

#if os(iOS) || os(tvOS)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
extension UIView.ContentMode {
    init(_ contentMode: LazyImage.ContentMode) {
        switch contentMode {
        case .aspectFill: self = .scaleAspectFill
        case .aspectFit: self = .scaleAspectFit
        case .fill: self = .scaleToFill
        case .center: self = .center
        }
    }
}
#endif

// MARK: Video (Private)

import Foundation
import AVFoundation

// This allows LazyImage to play video from memory.
final class DataAssetResourceLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let data: Data
    private let contentType: String

    init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        if let contentRequest = loadingRequest.contentInformationRequest {
            contentRequest.contentType = contentType
            contentRequest.contentLength = Int64(data.count)
            contentRequest.isByteRangeAccessSupported = true
        }

        if let dataRequest = loadingRequest.dataRequest {
            if dataRequest.requestsAllDataToEndOfResource {
                dataRequest.respond(with: data[dataRequest.requestedOffset...])
            } else {
                let range = dataRequest.requestedOffset..<(dataRequest.requestedOffset + Int64(dataRequest.requestedLength))
                dataRequest.respond(with: data[range])
            }
        }

        loadingRequest.finishLoading()

        return true
    }
}

extension ImageType {
    static let mp4: ImageType = "public.mp4"
}

extension ImageDecoders {
    struct MP4: ImageDecoding {
        func decode(_ data: Data) -> ImageContainer? {
            ImageContainer(image: _PlatformImage(), type: .mp4, data: data)
        }

        private static func _match(_ data: Data, offset: Int = 0, _ numbers: [UInt8]) -> Bool {
            guard data.count >= numbers.count + offset else { return false }
            return !zip(numbers.indices, numbers).contains { (index, number) in
                data[index + offset] != number
            }
        }

        private static var isRegistered: Bool = false

        static func register() {
            guard !isRegistered else { return }
            isRegistered = true

            ImageDecoderRegistry.shared.register {
                // TODO: extened support for other image formats
                // ftypisom - ISO Base Media file (MPEG-4) v1
                // There are a bunch of other ways to create MP4
                // https://www.garykessler.net/library/file_sigs.html
                guard _match($0.data, offset: 4, [0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6F, 0x6D]) else {
                    return nil
                }
                return MP4()
            }
        }
    }
}

extension AVLayerVideoGravity {
    @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
    init(_ contentMode: LazyImage.ContentMode) {
        switch contentMode {
        case .aspectFit: self = .resizeAspect
        case .aspectFill: self = .resizeAspectFill
        case .center: self = .resizeAspect
        case .fill: self = .resize
        }
    }
}

#endif

extension ImageRequest {
    struct ID: Hashable {
        let imageId: String?
        let priority: ImageRequest.Priority
        let options: ImageRequest.Options

        init(_ request: ImageRequest) {
            self.imageId = request.imageId
            self.priority = request.priority
            self.options = request.options
        }
    }
}
