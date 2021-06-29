# NukeUI

A missing piece in SwiftUI that provides lazy image loading.

- `Image` and `LazyImage` for SwiftUI (similar to the native [`AsyncImage`](https://developer.apple.com/documentation/SwiftUI/AsyncImage))
- `ImageView` and `LazyImageView` for UIKit and AppKit

`LazyImage` uses [Nuke](https://github.com/kean/Nuke) for loading images so you can take advantage of all of its advanced performance features, such as custom caches, prefetching, task coalescing, smart background decompression, request priorities, and more. And it's not just that. NukeUI also supports progressive images, has GIF support powered by [Gifu](https://github.com/kaishin/Gifu), and can even play short videos, which is [a more efficient](https://web.dev/replace-gifs-with-videos/) way to display animated images.

> **WARNING**. It's in early preview. The first stable release will be available soon.

## LazyImage

The view is instantiated with a source where a source can be a `String`, `URL`, `URLRequest`, or an [`ImageRequest`](https://kean.blog/nuke/guides/customizing-requests).

```swift
struct ContainerView: View {
    var body: some View {
        LazyImage(source: "https://example.com/image.jpeg")
    }
}
```

The view is called "lazy" because it loads the image from source only when it appears on the screen. And when it disappears, the current request automatically gets canceled. When the view reappears, the download picks up where it left off, thanks to [resumable downloads](https://kean.blog/post/resumable-downloads). 

The view doesn't know the size of the image before it downloads it. Thus, you must specify the view size before loading the image. By default, the image will resize preserving the aspect ratio to fill the available space. You can change this behavior by passing a different resizing mode.

```swift
LazyImage(source: "https://example.com/image.jpeg", resizingMode: .center)
    .frame(height: 300)
```

> **Important**. You can’t apply image-specific modifiers, like `aspectRatio()`, directly to a `LazyImage`.

Until the image loads, the view displays a standard placeholder that fills the available space, just like [AsyncImage](https://developer.apple.com/documentation/SwiftUI/AsyncImage) does. After the load completes successfully, the view updates to display the image.

<br>
<img src="https://user-images.githubusercontent.com/1567433/121760622-bf4b9080-caf9-11eb-8727-bb53eb1736ea.png" width="600px">
<br>

You can also specify a custom placeholder, a view to be displayed on failure, or even show a download progress.

```swift
LazyImage(source: $0) { state in
    if let image = state.image {
        image // Displays the loaded image
    } else if state.error != nil {
        Color.red // Indicates an error
    } else {
        Color.blue // Acts as a placeholder
    }
}
```

When the image is loaded, it is displayed with a default animation. You can change it using a custom `animation` option.

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .animation(nil) // Disable all animations
```

You can pass a complete `ImageRequest` as a source, but you can also configure the download via convenience modifiers.

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .processors([ImageProcessors.Resize(width: 44)])
    .priority(.high)
    .pipeline(customPipeline)
```

> `LazyImage` is built on top of Nuke's [`FetchImage`](https://kean.blog/nuke/guides/swiftui#fetchimage). If you want even more control, you can use it directly instead.  

You can also monitor the status of the download.

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .onStart { print("Task started \($0)")
    .onProgress { ... }
    .onSuccess { ... }
    .onFailure { ... }
    .onCompletion { ... }
```

And if some API isn't exposed yet, you can always access the underlying `ImageView` instance.

```swift
LazyImage(source: "https://example.com/image.jpeg")
    .onCreated { view in 
        view.videoGravity = .resizeAspect
    }
```

## LazyImageView

`LazyImageView` is a `LazyImage` counterpart for UIKit and AppKit with the equivalent set of APIs.

```swift
let imageView = LazyImageView()
imageView.placeholderView = UIActivityIndicatorView()
imageView.priority = .high
imageView.pipeline = customPipeline
imageView.onCompletion = { print("Request completed")

imageView.source = "https://example.com/image.jpeg"
````

## Image and ImageView

`Image` and `ImageView` are image components that support the same image formats that lazy variants (including animated images and video), but you can use them to display an already available image.

```swift
let container = ImageContainer(image: UIImage(data: data), data: data, type: .gif)
Image(container)
```

## Animated Images

All image components in NukeUI support GIF playback powered by [Gifu](https://github.com/kaishin/Gifu) rendering engine. Please keep in mind that GIF rendering is expensive and can result in high CPU, battery, and memory usage. A best practice is to [replace GIF with video](https://web.dev/replace-gifs-with-videos/).

## Video

All image components in NukeUI support video playback. It's aimed to be a replacement for GIF, which is [inefficient](https://web.dev/replace-gifs-with-videos/). With video, you get an order of magnitude smaller files and hardware-accelerated playback. In practice, it means that instead of a 20 MB GIF you can now download a ~2 MB video of comparable quality. And instead of 60% CPU usage and high energy impact, you'll see 0%.

There is nothing you need to do to enable video playback. It does the right thing by default:

- It plays automatically
- It doesn't show any controls
- It loops continuously
- It's always silent
- It doesn't prevent the display from sleeping
- It displays a preview until the video is downloaded

> **Important:** The number of players you can have at once on-screen is limited. The limit is not documented and depends on the platform. In general, expect to have about four players playing at once.

## Extending Rendering System

NukeUI allows you to extend image rendering system in case you need to support additional image format. And there are only two simple steps to do that.

**Step 1**. Register a custom decoder with Nuke.

```swift
ImageDecoderRegistry.shared.register { context in
    let isSVG = context.urlResponse?.url?.absoluteString.hasSuffix(".svg") ?? false
    return isSVG ? ImageDecoders.Empty(imageType: .svg) : nil
}

extension ImageType {
    public static let svg: ImageType = "public.svg"
}
```

> Learn more about the decoding infrastructure in ["Image Formats."](https://kean.blog/nuke/guides/image-formats)

**Step 2**. Register a custom image view.

 ```swift
import SwiftSVG

// Affects both all image components, including `LazyImage` and `Image`
ImageView.registerContentView {
    if $0.type == .svg, let string = $0.data.map( {
        UIView(svgData: data)
    }
    return nil
}
```

## Minimum Requirements

| NukeUI          | Swift           | Xcode           | Platforms                                         |
|---------------|-----------------|-----------------|---------------------------------------------------|
| NukeUI 0.1    | Swift 5.3       | Xcode 12.0      | iOS 11.0 / watchOS 5.0 / macOS 10.13 / tvOS 11.0  |

> `LazyImage` and `Image` are available on the following platforms: iOS 14.0 / watchOS 7.0 / macOS 10.16 / tvOS 14.0

## License

NukeUI is available under the MIT license. See the LICENSE file for more info.
