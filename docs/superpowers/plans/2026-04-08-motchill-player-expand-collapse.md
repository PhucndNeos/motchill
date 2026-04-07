# Motchill Player Expand/Collapse Implementation Notes

**Goal:** Keep the player compact for browsing sources and expand it into a full-screen viewing mode without losing playback state or timeline sync.

## What changed

- `PlayerView` now owns a two-state shell: `collapsed` and `expanded`.
- The expanded state hides the top app bar / navigation chrome and lets the player fill the full screen.
- The player surface itself stays in a shared layout so playback state is preserved when toggling between modes.
- The top-right corner now has a single expand/collapse toggle.
- The center overlay contains the three transport controls:
  - `-10s`
  - `play/pause`
  - `+10s`
- The bottom progress row is present in both states and tracks the current timeline.
- The progress row shows:
  - current time on the left
  - a draggable progress slider in the middle
  - total duration on the right
- Scrubbing the slider seeks the stream.
- Tapping the player surface toggles the chrome visibility.
- Chrome auto-hides after 3 seconds when visible.
- The collapsed layout still shows the source rail and secondary helper text so the user can pick another stream.

## Playback behavior

- Stream sources use `VideoPlayerController` and keep their position, duration, and play state synced through the controller listener plus a periodic timer.
- Play/pause updates optimistically so the icon responds quickly.
- Embedded/webview sources still render through the same shell, but their internal timeline is not exposed by the webview surface itself.

## Verification

- `flutter test test/player_view_test.dart`
- `flutter test`

Both passed after the player refactor.
