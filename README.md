# NukeUI

A missing piece in SwiftUI that provides lazy image loading on Apple platforms. 

The library provides two components with equivalent APIs:

- `LazyImage` for SwiftUI
- `LazyImageView` for UIKit and AppKit

It uses [Nuke](https://github.com/kean/Nuke) for loading images and has many customization options. It also supports GIF rendering thanks to [Gifu](https://github.com/kaishin/Gifu). But GIF is [not the most](https://web.dev/replace-gifs-with-videos/) efficient format, so NukeUI also supports playing short videos out of the box.

> **WARNING**. It's work-in-progress. Feel free to try it at your own risk by installing the package from the `main` branch.

## Usage

The view is instantiated with a source.

```swift
struct ContainerView: View {
    var body: some View {
        LazyImage(source: "https://example.com/image.jpeg")
    }
}
```

The view is called "lazy" because it loads the image from the source only when it appears on the screen. And when it disappears (or is deallocated), the current request automatically gets canceled. When the view reappears, the download picks up where it left off, thanks to [resumable downloads](https://kean.blog/post/resumable-downloads). 

The source can be anything from a `String` to a full `ImageRequest`.

```swift
LazyImage(source: "https://example.com/image.jpeg")
LazyImage(source: URL(string: "https://example.com/image.jpeg"))
LazyImage(source: URLRequest(url: URL(string: "https://example.com/image.jpeg")!))

let request = ImageRequest(
    url: URL(string: "https://example.com/image.jpeg"),
    processors: [ImageProcessors.Resize(width: 44)]
)
LazyImage(source: request)
```

> Learn more about customizing image requests in ["Image Requests."](https://kean.blog/nuke/guides/customizing-requests)

If you already have an image ready to be displayed, use a dedicated initializer.

```swift
// Display a regular image
LazyImage(image: UIImage("my-image"))

// Display an animated GIF
LazyImage(image: ImageContainer(image: UIImage(), type: .gif, data: data))
```

`LazyImage` is highly customizable. For example, it allows you to display a placeholder while the image is loading and display a custom view on failure.

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .placeholder {
        Circle()
            .foregroundColor(.blue)
            .frame(width: 30, height: 30)
    }
    .failure { Image("empty") }
}
```

The image view is lazy and doesn't know the size of the image before it downloads it. Thus, you must specify the view size before loading the image. By default, the image will resize preserving the aspect ratio to fill the available space. You can change this behavior by passing a different content mode.

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .contentMode(.center) // .aspectFit, .aspectFill, .center, .fill
    .frame(height: 300)
```

When the image is loaded, you can add an optional transition.

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .transition(.fadeIn(duration: 0.33))
```

You can pass a complete `ImageRequest` as a source, but you can also configure the download via convenience modifiers.

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .processors([ImageProcessors.Resize(width: 44])
    .priority(.high)
    .pipeline(customPipeline)
```

You can also monitor the status of the download.

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .onStart { print("Task started \($0)")
    .onProgress { ... }
    .onSuccess { ... }
    .onFailure { ... }
    .onCompletion { ... }
```

And if some API isn't exposed yet, you can always access the underlying `LazyImageView` instance. For example, you are currently going to need to access the underlying view to enable experimental video playback support:

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .onCreated { view in 
        view.isExperimentalVideoSupportEnabled = true
        view.videoGravity = .resizeAspect
    }
```

`LazyImageView` is a `LazyImage` counterpart for UIKit and AppKit with the equivalent set of APIs.

```swift
let imageView = LazyImageView()
imageView.placeholderView = UIActivityIndicatorView()
imageView.priority = .high
imageView.pipeline = customPipeline
imageView.onCompletion = { print("Request completed")

imageView.source = "https://example.com/image.jpeg"
````

## Limitations

- GIF support is currently limited to iOS and tvOS (macOS support in progress)
- There is a known race condition in Gifu with an outsdanting PR with a fix https://github.com/kaishin/Gifu/pull/176
- The support for watchOS is there but is currently limited

## Minimum Requirements

| NukeUI          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| main branch   | Swift 5.3       | Xcode 12.0      | iOS 11.0 / watchOS 5.0 / macOS 10.13 / tvOS 11.0  |

> `LazyImage` is available on the following platforms: iOS 13.0 / watchOS 7.0 / macOS 10.15 / tvOS 13.0

## License

NukeUI is available under the MIT license. See the LICENSE file for more info.
