
# NukeUI 0.x

## NukeUI 0.5.0

- Rework `LazyImage` to use `FetchImage` on all platforms
- Add new `init(source:content:)` initializer to `LazyImage`:

```swift
LazyImage(source: $0) { state in
    if let image = state.image {
        // Use `AnimatedImage(image:)` if you need support for animated images.
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
    } else if state.error != nil {
        Color.red.frame(width: 128, height: 128)
    } else {
        Color.blue.frame(width: 128, height: 128)
    }
}
```

- Add `AnimatedImage` component for SwitUI for rendering animates image (currently supports GIF and MP4)
- Add default placeholder (gray background)
- Remove `LazyImage` initializer that take `ImageContainer` – use `AnimatedImage` instead if you need to display GIFs 
- Temporarily increase `LazyImage` supported platforms to iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 10.16
- Add more functionality to `LazyImage` on watchOS 

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
