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
