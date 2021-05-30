// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Nuke
import SwiftUI

#warning("should it be based on URLImageView?")
@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
public struct URLImage: View {
    private var placeholder: AnyView?

    #warning("impl")
    /// Displayed while the image is loading.
    public func placeholder<Placeholder: View>(_ view: Placeholder?) -> URLImage {
        var copy = self
        copy.placeholder = placeholder
        return self
    }

    public var body: some View {
        Text("Placeholder")
    }
}
