
# NukeUI 0.x

## NukeUI 0.6.5

*Jul 26, 2021*

- Fix an issue with incorrect `source` change handling - [#14](https://github.com/kean/NukeUI/issues/14) 

## NukeUI 0.6.4

*Jul 18, 2021*

- Fix an issue with video decoder not being registered automatically for `LazyImage` - [#495](https://github.com/kean/Nuke/issues/495)

## NukeUI 0.6.3

*Jul 8, 2021*

- Revert the changes to `Image` sizing behavior. Now it again simply takes all the available space and you can use `resizingMode` to change the image rendering behavior. 

## NukeUI 0.6.1

*Jun 11, 2021*

- Fix default placeholder color for `LazyImage`
- Update `LazyImageView` to match `LazyImage` in terms of the default parameters: placeholder and animation

## NukeUI 0.6.0

*Jun 11, 2021*

- Add `ImageView` (UIKit, AppKit) and `Image` (SwiftUI) components that support animated images and are now used by `LazyImageView`
- Remove `LazyImageView` API for setting image, use `ImageView` directly instead
- Fix reloading when the source changes but view identity is the same
- All views now support video rendering by default
- Rename `contentMode` to `resizingMode`
- `LazyImage` custom initialized now suggest `NukeUI.Image`

## NukeUI 0.5.0

*Jun 10, 2021*

- Rework `LazyImage` to use `FetchImage` on all platforms
- Add new `init(source:content:)` initializer to `LazyImage`:

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

- Add default placeholder to `LazyImage` (gray background) 
- Temporarily increase `LazyImage` supported platforms to iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 10.16
- `LazyImage` on watchOS now has an almost complete feature parity with other platforms. The main exception is the support for animated images which is currently missing.
- Remove `LazyImage` initializer that take `ImageContainer` – use `LazyImageView` directly instead
- Add infrastructure for registering custom rendering engines:

```swift
import SwiftSVG

// Affects both all `LazyImage` and `LazyImageView` instances
LazyImageView.registerContentView {
    if $0.type == .svg, let string = $0.data.map( {
        UIView(SVGData: data)
    }
    return nil
}
```

## NukeUI 0.4.0

*Jun 6, 2021*

- Extend watchOS support
- Add animated images support on macOS
- Display a GIF preview until it is ready to be played (Nuke 10.2 feature)
- Fix how images are displayed on macOS by default

## NukeUI 0.3.0

*Jun 4, 2021*

- Allow user interaction during animated transitions
- Animated transitions are now supported for video
- Add access to the underlying `videoPlayerView`, remove separate `videoGravity` property
- Add `isLooping` property to `VideoPlayerView` which is `true` by default
- Add `contentView` where all content views (both images and video) are displayed. It simplified animations.

## NukeUI 0.2.0

*Jun 3, 2021*

- Display the first frame of the video as a preview until the video is downloaded and ready to be played
- Enable video rendering by default. The option renamed from `isExperimentalVideoSupportEnabled` to `isVideoRenderingEnabled`.
- Make sure video doesn't prevent the display from sleeping by setting `preventsDisplaySleepDuringVideoPlayback` to `false`
- Add video support on macOS
- Optimize performance during scrolling

## NukeUI 0.1.0

*Jun 1, 2021*

- Initial release
