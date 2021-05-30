// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
public typealias URLBaseImageView = NSImageView
#else
public typealias URLBaseImageView = UIImageView
#endif

public final class URLImageView: URLBaseImageView {
    
}
