# Native iOS Player

## Player Goal

The first iOS player should behave like the Android player for direct streams:

- load episode sources
- filter to playable direct streams
- start from resume position when available
- support source switching
- support audio and subtitle tracks when present

Embedded sources are intentionally out of scope for this version.

## Player Architecture

Use a split between:

- a feature state holder that owns source selection, loading state, and errors
- a playback engine that owns AVPlayer and runtime playback state
- a small UI layer that binds controls to state

That separation keeps source selection and playback side effects easy to test independently.

## Playback Flow

1. The detail screen opens the player for a specific episode.
2. The player asks the repository for the decrypted source list.
3. The feature layer filters the list to `isFrame=false` sources only.
4. The first playable source becomes the default selection.
5. The playback engine loads the selected source through AVPlayer.
6. Resume position is applied if it exists.
7. Audio and subtitle tracks are shown only when the selected source exposes them.

## Source Switching

- Switching source should reload playback from the current position when possible.
- Track selection should stay attached to the selected source.
- If a source fails to initialize, the UI should surface a retryable error instead of silently continuing.

## Resume Behavior

- Resume should be stored per episode.
- Resume should be flushed when the player exits or pauses in a way that risks losing position.
- A missing resume record should simply start from zero.

## Track Rules

### Audio

- Audio tracks appear only when the selected source includes audio metadata.
- Default audio should be selected from explicit track defaults first.

### Subtitles

- Subtitle tracks appear only when the selected source exposes subtitle metadata or a fallback subtitle file.
- Default subtitle should be selected from explicit track defaults first.
- Subtitle rendering runs as a sidecar pipeline and does not use `AVPlayerItem` legible media tracks for this iteration.
- The selected subtitle file should be downloaded separately, decoded with `SwiftSubtitles`, and mapped into normalized cue ranges.
- Subtitle text should stay in lightweight runtime state so high-frequency time updates do not fan out across the entire player UI.

## Subtitle Runtime

The current iOS implementation mirrors Android behavior for direct stream subtitles while keeping playback and subtitle handling loosely coupled.

### Runtime flow

1. When the selected source changes, the player picks the default subtitle track if present, otherwise the first subtitle track.
2. If the source has no subtitle track, the subtitle button is hidden and subtitle runtime state is cleared immediately.
3. If a subtitle track is selected, the app downloads the sidecar subtitle file and decodes it with `SwiftSubtitles`.
4. Parsed cues are normalized into millisecond ranges and cached in memory for the active source.
5. The player time observer ticks every `0.25s` and resolves the active cue using an incremental cursor with binary-search fallback.
6. `currentSubtitleText` is published only when the rendered text actually changes.

### Toggle behavior

- Subtitle is enabled by default when the selected source has a default track or any subtitle track.
- The subtitle side button is shown only when the selected source exposes subtitle tracks.
- Tapping the button toggles subtitle on and off without reconfiguring `AVPlayer`.
- Disabling subtitle clears selected track, loaded cues, current text, and in-flight subtitle loading work.

### Performance notes

- Subtitle download and parsing should stay off the main actor.
- Only minimal UI-facing subtitle state should remain observable.
- Cue lookup should never linearly rescan the full subtitle list on every tick.

### Current scope

- Formats validated in tests: `.vtt`, `.srt`
- Subtitle UI scope: toggle only
- Not yet implemented: subtitle picker, styling settings, track language menu, embedded subtitle support

## Error Handling

The player should distinguish between:

- loading failures
- no playable source found
- playback initialization failures
- runtime playback failures

User-facing responses should be specific enough that the user can tell whether to retry, select another source, or go back.

## UI Expectations

- Keep player chrome separate from playback engine state.
- Keep controls simple and focus on stability over visual complexity.
- Match Android behavior closely for source rail visibility, track buttons, and resume.

## Validation

- Unit test source filtering.
- Unit test default track selection.
- Unit test playback state transitions.
- Unit test subtitle cue decoding and lookup behavior.
- Unit test subtitle default selection and toggle behavior.
- Run simulator playback checks against at least one direct stream source.
