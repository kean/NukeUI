# NukeUI

A comprehensive solution for displaying lazily loaded images on Apple platforms. 

It uses [Nuke](https://github.com/kean/Nuke) for loading images and has all customization options you can possibly imagine. It also supports animated GIFs rendering thanks to [Gifu](https://github.com/kaishin/Gifu).

The library contains two types:

- `LazyImage` for SwiftUI
- `LazyImageView` for UIKit and AppKit

Both views have an equivalent sets of APIs.

## Usage

Loading an image with a given source.

```swift
struct ContainerView: View {
    var body: some View {
        LazyImage(source: "https://example.com/image.jpeg")
    }
}
```

The source can be anything from a `String` to a full `ImageRequest`.

```swift
LazyImage(source: "https://example.com/image.jpeg")
LazyImage(source: URL(string: "https://example.com/image.jpeg"))
LazyImage(source: URLRequest(url: URL(string: "https://example.com/image.jpeg")!))
LazyImage(source: ImageRequest(url: URL(string: "https://example.com/image.jpeg"), processors: [ImageProcessors.Resize(width: 44)]))
```

Displays placeholders (while image is loading) and failure images (in case of failure).

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

> Learn more about customizing requests in ["Image Requests."](https://kean.blog/nuke/guides/customizing-requests)

The image view is lazy and doesn't know the size of the image before it is downloaded. You must specify the size for the view before loading the image. By default, the image will resize to fill the available space but preserve the aspect ratio. You can change this behavior by passing a different content mode.

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .contentMode(.center) // .aspectFit, .aspectFill, .center, .fill
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
    .onStart { print("task started \($0)")
    .onProgress { ... }
    .onSuccess { ... }
    .onFailure { ... }
    .onCompletion { ... }
```

And if some API isn't exposed yet, you can always get access to the underlying `LazyImageView` instance:

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .onImageViewCreated { view in 
        // ...
    }
```

`LazyImageView` is a `LazyImage` counterpart for UIKit and AppKit with the equivalent set of APIs. 


## Minimum Requirements

| Nuke          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| NukeUI Beta   | Swift 5.3       | Xcode 12.0      | iOS 11.0 / watchOS 4.0 / macOS 10.13 / tvOS 11.0  |

> `LazyImage` is available on the following platforms: iOS 13.0 / watchOS 5.0 / macOS 10.15 / tvOS 13.0

## License

NukeUI is available under the MIT license. See the LICENSE file for more info.
