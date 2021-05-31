// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation

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

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
typealias _PlatformHostingController<T: View> = NSHostingController<T>
#else
public typealias _PlatformBaseView = UIView
typealias _PlatformImage = UIImage
typealias _PlatformImageView = UIImageView

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
typealias _PlatformHostingController<T: View> = UIHostingController<T>
#endif

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
func toPlatformView<T: View>(_ view: T) -> _PlatformBaseView {
    _PlatformHostingController(rootView: view).view
}

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

// AVPlayer doesn't support playing videos from memory
final class TempVideoStorage {
    private let path: URL
    private let _queue = DispatchQueue(label: "com.github.kean.Nuke.TempVideoStorage.Queue")

    // Ignoring error handling for simplicity.
    static let shared = TempVideoStorage()

    init() {
        guard let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            self.path = URL(fileURLWithPath: "/dev/null") // Should never happen
            return
        }
        self.path = root.appendingPathComponent("com.github.kean.NukeUI.TemporaryVideoStorage", isDirectory: true)
        // Clear the contents that could potentially was left from the previous session.
        try? FileManager.default.removeItem(at: path)
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
    }

    func storeData(_ data: Data, _ completion: @escaping (URL) -> Void) {
        _queue.async {
            let url = self.path.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
            try? data.write(to: url) // Ignore that write may fail in some cases
            DispatchQueue.main.async {
                completion(url)
            }
        }
    }

    func removeData(for url: URL) {
        _queue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func removeAll() {
        _queue.async {
            // Clear the contents that could potentially was left from the previous session.
            try? FileManager.default.removeItem(at: self.path)
            try? FileManager.default.createDirectory(at: self.path, withIntermediateDirectories: true, attributes: nil)
        }
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
