# Phase 6 Result: Player Feature Migrated to TCA

## What This Phase Was For

This phase moved the Player screen off the legacy `PlayerViewModel` path and into a reducer-owned TCA feature.

The main technical requirement was preserving playback smoothness while state updates were happening. To achieve that, the Player runtime now keeps a stable `AVPlayer` instance that is carried through `PlayerFeature.State` mutations instead of being recreated by the view.

## What Was Done

### 1. Replaced the Player view model with `PlayerFeature`

`PlayerFeature` now owns the screen-facing state and orchestration for Player.

The reducer state includes:

- movie and episode identity
- load state and error state
- playback sources
- selected source, audio track, and subtitle track
- current position and duration
- overlay visibility
- current subtitle text
- runtime playback storage such as `AVPlayer` and time-observer bookkeeping

The player runtime is intentionally kept out of ordinary observed business state so reducer updates do not reset playback.

### 2. Moved Player lifecycle and user intent into reducer actions

The Player reducer now handles:

- initial appearance and teardown
- retry
- back navigation
- play/pause
- seek and scrubbing
- source switching
- subtitle selection
- overlay visibility changes
- periodic time updates
- progress persistence and remote sync

### 3. Bridged `AVPlayer` timing into TCA effects

The periodic time observer is now bridged through an `AsyncStream` inside a cancellable `.run` effect.

That lets the reducer receive continuous playback updates while still cleaning up the observer correctly when the screen disappears or the active source changes.

### 4. Converted the Player UI to store-driven SwiftUI

`PlayerView` now reads from `StoreOf<PlayerFeature>`.

The view keeps the `VideoPlayer` subtree stable by reusing the same `AVPlayer` reference from state, which prevents playback reset when unrelated state changes.

`PlayerOverlay` also sends all user intent through the store instead of mutating a view model directly.

### 5. Preserved fallback and subtitle behavior

The existing fallback behavior for iframe-only content remains available.

Subtitle loading was moved into the dependency-driven reducer flow so the feature can still resolve and render subtitle cues without depending on the old view model path.

### 6. Removed the legacy Player view model and preview helpers

`PlayerViewModel.swift` was deleted after the reducer-backed flow was verified.

Preview fixtures now live in `PlayerFixtures.swift` so previews can keep using sample state without depending on the removed view model.

### 7. Added the missing TCA dependency for subtitle loading

`AppDependencies+TCA.swift` now provides a subtitle loader dependency for the Player feature.

That keeps subtitle cue parsing testable and decoupled from the view layer.

## Test Coverage

The Player test suite now covers:

- load success and failure
- retry cancellation
- source switching
- subtitle selection and cue loading
- overlay toggling
- time updates and progress persistence
- disappear cleanup
- AVPlayer identity staying stable across state updates

## What Stayed The Same

- The overall Player UI stays visually close to the existing experience.
- `AppFeature` remains the place where the Player route is created.
- Playback smoothness stays the priority over reshaping the UI architecture.

## Notes

The implementation deliberately treats `AVPlayer` as runtime storage, not business state.

That is the key reason the Player screen can now adopt TCA without paying the usual penalty of re-creating the media player on every state mutation.
