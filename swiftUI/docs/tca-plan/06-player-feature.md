# Task 6: Migrate Player Feature

## Goal

Move the Player screen from the legacy `PlayerViewModel` path into a reducer-owned TCA feature while keeping playback smooth.

The core constraint for this phase is that `AVPlayer` must stay stable across state updates. The reducer may mutate screen state, but the same player instance must continue to power `VideoPlayer` so playback does not reset or flicker.

## Current Baseline

This plan follows the state of the codebase after Phases 3 to 5:

- Home, Search, and Detail are already reducer-owned.
- Detail -> Player navigation is already centralized in `AppFeature`.
- Tapping an episode in Detail already pushes a `PlayerFeature.State` route element.
- `PlayerFeature` is the owner of Player screen state and effects.
- `PlayerView` and `PlayerOverlay` are store-driven SwiftUI views.
- The legacy `PlayerViewModel.swift` has been removed.

## Scope

The Player feature now owns:

- movie and episode identity
- load phase and error state
- playback source selection
- audio and subtitle selection
- overlay visibility
- current playback position and duration
- subtitle text rendered on top of the player
- runtime playback resources such as `AVPlayer`, time observation, and seek coordination

## Implementation Notes

1. Keep `AVPlayer` out of observed business state.
   - `PlayerFeature.State` stores `AVPlayer` as runtime storage with observation ignored.
   - State mutations should copy the same player reference forward instead of creating a new player.
   - Equality should ignore runtime-only fields so reducer updates stay focused on UI state.

2. Route all Player lifecycle and user intent through reducer actions.
   - `onAppear`
   - `onDisappear`
   - `retryTapped`
   - `backButtonTapped`
   - `playPauseTapped`
   - `seek(deltaMillis:)`
   - `seekTo(positionMillis:playAfterSeek:)`
   - `timeUpdated`
   - `overlayTapped`
   - `hideOverlay`
   - `showOverlayTemporarily`
   - `sourceSelected`
   - `subtitleSelected`
   - `subtitleLoaded`
   - `syncProgress`
   - `syncProgressToRemote`

3. Bridge player timing into TCA effects.
   - Use a periodic time observer on `AVPlayer`.
   - Convert the callback into an `AsyncStream`.
   - Feed the stream into the reducer with a cancellable effect so teardown is deterministic on disappear or source changes.

4. Keep the view layer stable.
   - `PlayerView` should read from `StoreOf<PlayerFeature>`.
   - `VideoPlayer(player: store.player)` should receive the same player reference across UI updates.
   - `PlayerOverlay` should send intents back through the store instead of mutating local view model state.

5. Keep fallback behavior intact.
   - If a source needs iframe handling, preserve the fallback path.
   - Keep subtitle loading and empty/error handling in the reducer flow.

6. Keep shell routing unchanged.
   - `AppFeature` remains responsible for creating the `PlayerFeature.State` route payload.
   - Player should not be pushed directly from the view layer.

## Files Involved

- `swiftUI/Features/Player/PlayerFeature.swift`
- `swiftUI/Features/Player/PlayerView.swift`
- `swiftUI/Features/Player/PlayerOverlay.swift`
- `swiftUI/Features/Player/PlayerSubtitleSupport.swift`
- `swiftUI/Features/Player/PlayerFixtures.swift`
- `swiftUI/App/AppDependencies+TCA.swift`
- `swiftUI/App/AppFeature.swift`
- `swiftUI/docs/tca-plan/06-player-feature-result.md`

## Test Plan

- Reducer tests for:
  - load success and load failure
  - retry cancellation
  - source switching
  - subtitle enable/disable
  - overlay show/hide
  - seek and play/pause
  - progress persistence and resume
  - disappear cleanup
- Runtime identity test:
  - ensure the same `AVPlayer` reference survives state mutations.
- Manual smoke test:
  - open Player
  - play, seek, and switch source/subtitle
  - toggle overlay
  - leave and return
  - verify playback stays smooth and does not reset

## Acceptance Criteria

- Player behavior continues to work under manual testing.
- Store state owns the visible UI behavior.
- `AVPlayer` remains a stable runtime object across reducer updates.
- Detail -> Player navigation continues to work through `AppFeature`.
- Subtitle rendering, source switching, and progress persistence remain functional.
