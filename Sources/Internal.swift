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

    func insertSubview(_ subivew: NSView, at index: Int) {
        addSubview(subivew, positioned: .below, relativeTo: subviews.first)
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
