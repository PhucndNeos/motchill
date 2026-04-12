# iOS Subtitle Runtime

## Goal

Implement Android-like subtitle behavior for direct stream playback on iOS without depending on native `AVPlayer` subtitle track rendering.

## Why sidecar subtitles

- Current subtitle sources are external files rather than embedded media selections.
- We need deterministic toggle behavior even when the stream itself has no native subtitle metadata.
- We want subtitle updates to stay cheap in a SwiftUI player rooted in a single observable view model.

## Implementation summary

- `PlayerViewModel` owns user-facing subtitle state:
  - `selectedSubtitleTrack`
  - `currentSubtitleText`
  - `hasSubtitleTracks`
  - `isSubtitleEnabled`
- `PlayerSubtitleLoader` downloads the selected subtitle file and parses it with `SwiftSubtitles`.
- `PlayerSubtitleResolver` resolves the active subtitle cue from the current playback timestamp.
- High-frequency runtime fields such as loaded cues, cursor index, and in-flight tasks remain non-observable.

## UI behavior

- If the selected source has subtitle tracks, the subtitle button is visible.
- If subtitle is enabled, the subtitle button uses the active yellow state.
- If subtitle is disabled but tracks are available, the button remains visible in a neutral state.
- If the selected source has no subtitle tracks, the button is hidden.
- Subtitle text is rendered in a dedicated overlay view bound only to `currentSubtitleText`.

## Selection rules

- On initial source load, select `defaultSubtitleTrack` when available.
- If there is no explicit default, select the first subtitle track.
- If the new source has no subtitle tracks, clear subtitle selection and runtime state immediately.
- Toggling subtitles off clears selection, cues, text, and any active loader task.
- Toggling subtitles on restores the default or first subtitle track for the selected source.

## Sync rules

- Subtitle sync runs from the player time observer at `0.25s`.
- Cue resolution first checks the previous cue neighborhood, then falls back to binary search.
- Subtitle text is assigned only when it changes, which reduces unnecessary SwiftUI invalidations.
- After seek completion, the player forces an immediate subtitle resync for the new timestamp.

## Dependencies

- Swift package: `SwiftSubtitles`
- Added package resolution entries for:
  - `SwiftSubtitles`
  - `BytesParser`
  - `DSFRegex`
  - `TinyCSV`

## Tests and verification

- Unit tests cover:
  - `.vtt` cue decoding
  - `.srt` cue decoding with preserved line breaks
  - cue lookup inside active ranges and empty gaps
  - default subtitle selection fallback
  - subtitle toggle off/on behavior
  - subtitle reset when switching to a source without subtitles
- Verified with:
  - app build
  - test target build
  - simulator test run for `PlayerSubtitleSupportTests`

## Current limitations

- No subtitle picker UI yet
- No subtitle styling preferences yet
- No embedded subtitle integration through `AVPlayerItem`
- Runtime tests currently focus on subtitle support helpers rather than full end-to-end playback fixtures
