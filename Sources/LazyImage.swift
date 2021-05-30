// The MIT License (MIT)
//
// Copyright (c) 2015-2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Nuke
import SwiftUI

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
public struct LazyImage: View {
    private let source: ImageRequestConvertible?
    @State private var loadedSource: ImageRequestConvertible?

    // Options
    private var placeholder: AnyView?
    private var onImageViewCreated: ((LazyImageView) -> Void)?
    private var onStarted: ((_ task: ImageTask) -> Void)?
    private var onProgress: ((_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void)?
    private var onFinished: ((_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void)?
    private var priority: ImageRequest.Priority?

    public init(source: ImageRequestConvertible?) {
        self.source = source
    }

    #warning("impl")
    /// Displayed while the image is loading.
    public func placeholder<Placeholder: View>(_ view: Placeholder?) -> Self {
        map { $0.placeholder = placeholder }
    }

    public func priority(_ priority: ImageRequest.Priority?) -> Self {
        map { $0.priority = priority }
    }

    /// Gets called when the request is started.
    public func onStarted(_ closure: @escaping (_ task: ImageTask) -> Void) -> Self {
        map { $0.onStarted = closure }
    }

    /// Gets called when the request progress is updated.
    public func onProgress(_ closure: @escaping (_ response: ImageResponse?, _ completed: Int64, _ total: Int64) -> Void) -> Self {
        map { $0.onProgress = closure }
    }

    /// Gets called when the request is completed.
    public func onFinished(_ closure: @escaping (_ result: Result<ImageResponse, ImagePipeline.Error>) -> Void) -> Self {
        map { $0.onFinished = closure }
    }

    /// Returns an underlying image view.
    ///
    /// - parameter configure: A closure that gets called once when the view is
    /// created and allows you to configure it based on your needs.
    public func onImageViewCreated(_ configure: @escaping (LazyImageView) -> Void) -> Self {
        map { $0.onImageViewCreated = configure }
    }

    public var body: some View {
        LazyImageViewWrapper(source: $loadedSource, configure: configure)
            .onAppear { loadedSource = source }
    }

    private func map(_ closure: (inout LazyImage) -> Void) -> Self {
        var copy = self
        closure(&copy)
        return copy
    }

    private func configure(_ view: LazyImageView) {
        onImageViewCreated?(view)

        view.onStarted = onStarted
        view.onProgress = onProgress
        view.onFinished = onFinished
        view.priority = priority
    }
}

#warning("add onSuccess/onFailure callbacks")

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
private struct LazyImageViewWrapper: UIViewRepresentable {
    @Binding var source: ImageRequestConvertible?
    var configure: ((LazyImageView) -> Void)?

    func makeUIView(context: Context) -> LazyImageView {
        let view = LazyImageView()
        configure?(view)
        return view
    }

    func updateUIView(_ imageView: LazyImageView, context: Context) {
        imageView.source = source
    }
}
