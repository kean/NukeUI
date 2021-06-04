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

/// You must hold a strong reference to the returned loader.
func makeAVAsset(with data: Data) -> (AVAsset, DataAssetResourceLoader) {
    let loader = DataAssetResourceLoader(data: data, contentType: AVFileType.mp4.rawValue)
    // The URL is irrelevant
    let url = URL(string: "in-memory-data://\(UUID().uuidString)") ?? URL(fileURLWithPath: "/dev/null")
    let asset = AVURLAsset(url: url)
    asset.resourceLoader.setDelegate(loader, queue: .global())
    return (asset, loader)
}

/// MARK: - ImageDecoders.Video

extension ImageType {
    public static let mp4: ImageType = "public.mp4"
}

extension ImageDecoders {
    final class Video: ImageDecoding, ImageDecoderRegistering {
        private var didProducePreview = false

        var isAsynchronous: Bool {
            false
        }

        init?(data: Data, context: ImageDecodingContext) {
            guard Video.isVideo(data) else { return nil }
        }

        init?(partiallyDownloadedData data: Data, context: ImageDecodingContext) {
            guard Video.isVideo(data) else { return nil }
        }

        static func isVideo(_ data: Data) -> Bool {
            match(data, offset: 4, [0x66, 0x74, 0x79, 0x70])
        }

        func decode(_ data: Data) -> ImageContainer? {
            ImageContainer(image: _PlatformImage(), type: .mp4, data: data)
        }

        func decodePartiallyDownloadedData(_ data: Data) -> ImageContainer? {
            guard !didProducePreview else {
                return nil // We only need one preview
            }
            guard let preview = makePreview(for: data) else {
                return nil
            }
            didProducePreview = true
            return ImageContainer(image: preview, type: .mp4, isPreview: true, data: data)
        }

        private static var isRegistered: Bool = false

        static func register() {
            guard !isRegistered else { return }
            isRegistered = true

            ImageDecoderRegistry.shared.register(ImageDecoders.Video.self)
        }
    }
}

private func makePreview(for data: Data) -> _PlatformImage? {
    let (asset, loader) = makeAVAsset(with: data)
    let generator = AVAssetImageGenerator(asset: asset)
    guard let cgImage = try? generator.copyCGImage(at: CMTime(value: 0, timescale: 1), actualTime: nil) else {
        return nil
    }
    _ = loader // Retain loader until preview is generated.
    #if os(macOS)
    return _PlatformImage(cgImage: cgImage, size: .zero)
    #else
    return _PlatformImage(cgImage: cgImage)
    #endif
}

// TODO: extened support for other image formats
// ftypisom - ISO Base Media file (MPEG-4) v1
// There are a bunch of other ways to create MP4
// https://www.garykessler.net/library/file_sigs.html
private func match(_ data: Data, offset: Int = 0, _ numbers: [UInt8]) -> Bool {
    guard data.count >= numbers.count + offset else { return false }
    return !zip(numbers.indices, numbers).contains { (index, number) in
        data[index + offset] != number
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

public final class VideoPlayerView: _PlatformBaseView {
    // MARK: Configuration

    /// `.resizeAspectFill` by default.
    public var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }

    // MARK: Initialization
    #if !os(macOS)
    public override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    public var playerLayer: AVPlayerLayer {
        (layer as? AVPlayerLayer) ?? AVPlayerLayer() // The right side should never happen
    }
    #else
    public let playerLayer = AVPlayerLayer()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        // Creating a view backed by a custom layer on macOS is ... hard
        wantsLayer = true
        layer?.addSublayer(playerLayer)
        playerLayer.frame = bounds
        self.playerLayer = playerLayer
    }

    public override func layout() {
        super.layout()

        playerLayer?.frame = bounds
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    #endif

    // MARK: Private

    private var player: AVPlayer?
    private var playerLooper: AnyObject?
    private var assetResourceLoader: DataAssetResourceLoader?
    private var playerObserver: AnyObject?

    func reset() {
        playerLayer.player = nil
        player = nil
        assetResourceLoader = nil
        playerObserver = nil
    }

    func playVideo(_ data: Data) {
        let (asset, loader) = makeAVAsset(with: data)
        self.assetResourceLoader = loader

        let playerItem = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(playerItem: playerItem)
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        self.playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        self.player = player

        playerLayer.player = player

        playerObserver = player.observe(\.status, options: [.new, .initial]) { player, change in
            if player.status == .readyToPlay {
                player.play()
            }
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
