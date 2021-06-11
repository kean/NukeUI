// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import AVKit
import Foundation

#if !os(watchOS)

public final class VideoPlayerView: _PlatformBaseView {
    // MARK: Configuration

    /// `.resizeAspectFill` by default.
    public var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }

    /// `true` by default. If disabled, will only play a video once.
    public var isLooping = true

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
    }

    public override func layout() {
        super.layout()

        playerLayer.frame = bounds
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
        if isLooping {
            self.playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        }
        self.player = player

        playerLayer.player = player

        playerObserver = player.observe(\.status, options: [.new, .initial]) { player, change in
            if player.status == .readyToPlay {
                player.play()
            }
        }
    }
}

extension AVLayerVideoGravity {
    init(_ contentMode: ImageResizingMode) {
        switch contentMode {
        case .aspectFit: self = .resizeAspect
        case .aspectFill: self = .resizeAspectFill
        case .center: self = .resizeAspect
        case .fill: self = .resize
        }
    }
}

// MARK: Private

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

#endif
