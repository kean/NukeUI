
# NukeUI 0.x

*Jun 4, 2021*

- Allow user interaction during animated transitions
- Animated transitions are now supported for video
- Add access to the underlying `videoPlayerView`, remove separate `videoGravity` property
- Add `isLooping` property to `VideoPlayerView` which is `true` by default
- Add `contentView` where all content views (both images and video) are displayed. It simplified animations.

## Nuke 0.2.0

*Jun 3, 2021*

- Display the first frame of the video as a preview until the video is downloaded and ready to be played
- Enable video rendering by default. The option renamed from `isExperimentalVideoSupportEnabled` to `isVideoRenderingEnabled`.
- Make sure video doesn't prevent the display from sleeping by setting `preventsDisplaySleepDuringVideoPlayback` to `false`
- Add video support on macOS
- Optimize performance during scrolling

## Nuke 0.1.0

*Jun 1, 2021*

- Initial release

