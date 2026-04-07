# Player Position Resume Design

## Problem

The current player keeps playback controls and layout state well enough across expand/collapse, but the watch position can still drift back to `0:00` when the player shell is rebuilt or when the user returns to the same episode later.

We want two things:

1. Expand/collapse should continue showing the live playback position immediately, without any visible reset.
2. Returning to the same episode later should resume near the last watched position.

## Goals

- Keep the current playback position in sync while toggling collapsed and expanded layouts.
- Persist the last watched position per episode so the user can resume where they left off.
- Keep the solution lightweight and local to the app.
- Avoid changing the playback engine or stream resolver behavior.

## Non-goals

- No server-side watch history.
- No multi-device sync.
- No playlist-level resume across different episodes.
- No new playback UI redesign beyond the existing player shell.

## Design Overview

We will split resume behavior into two layers:

1. **Live session state**
   - Keeps the current `position`, `duration`, and `isPlaying` values in memory while the player stays open.
   - Used when the user switches between collapsed and expanded states.

2. **Persistent episode cache**
   - Stores the last known playback position locally per episode.
   - Used when the user leaves the player and later reopens the same episode.

The key idea is that expand/collapse should not reset the shared player surface. Layout changes only update the chrome and framing, while the playback state stays attached to the same source.

## Storage Key

The cached position will be keyed by:

- `movieId`
- `episodeId`

This means:

- The same episode resumes from the same point regardless of which source was used last.
- Different episodes do not overwrite each other.

Example cache key:

```text
player_position:10:20
```

## Persistence Rules

The cache should be updated when:

- The player is paused.
- The player is disposed or the user leaves the screen.
- A periodic sync timer fires every 5 seconds while playback is active.
- The user switches between expand and collapse, so the latest live position is immediately captured.

The cache should be read when:

- The player screen opens for an episode.
- The selected source changes and the player needs to restore the most recent position for that episode.

## Restore Rules

When restoring a cached position:

- Seek to the saved position once the stream controller is initialized.
- Ignore the saved value if it is invalid, negative, or beyond the current media duration.
- If there is no valid cache entry, start from `0:00`.

## Session Sync Rules

During the active player session:

- The in-memory playback state is the source of truth.
- Expand/collapse should read the latest `position` immediately before repainting the shell.
- The progress bar should continue to show the current position and duration without resetting.

## Proposed Implementation Shape

### 1. `PlaybackPositionStore`

A small local storage abstraction will handle saving and loading positions.

Responsibilities:

- Save the last known position for an episode.
- Load the saved position for an episode.
- Clear or ignore stale values when needed.

Recommended backend:

- `shared_preferences`

Why:

- Very small dependency footprint.
- Sufficient for a few resume values.
- Easy to test and easy to reason about.

### 2. Player session sync

The player frame should keep a live snapshot of:

- `position`
- `duration`
- `isPlaying`

This state should update from the controller listener and periodic timer, and it should be reused when switching between collapsed and expanded views.

### 3. Restore on init

When the stream controller becomes ready, the player should:

- load the cached position for the current episode
- seek to that position if valid
- continue playback from there

## Edge Cases

- If the cached position is near the end of the episode, the player should still clamp to the valid duration.
- If the user switches source inside the same episode, the most recent live position should be preserved.
- If the stream duration is unknown at first load, the player should defer clamping until duration is available.
- If the cache is missing or corrupted, playback should fall back to the beginning without blocking the UI.

## Testing Plan

We should add tests for:

- expand/collapse keeps the same live position
- cache read returns the saved episode position
- cache write happens on pause/dispose
- invalid cached values are ignored
- progress UI still reflects the controller position after layout toggles

## Implementation Order

1. Add the local persistence abstraction.
2. Wire the player frame to update and restore positions.
3. Keep expand/collapse using the same session state.
4. Add tests for resume and cache behavior.

## Success Criteria

- Switching between collapsed and expanded views never resets the visible position to `0:00`.
- Reopening the same episode resumes from the last saved position.
- The implementation stays lightweight and does not require a backend change.
