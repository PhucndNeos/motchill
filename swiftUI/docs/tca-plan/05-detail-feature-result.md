# Phase 5 Result: Detail Feature Migrated to TCA

## What This Phase Was For

This phase moved the Detail screen from the legacy `DetailViewModel` path into a reducer-owned TCA feature.

The key goals were:

- keep the current Detail UI structure stable
- move async loading, retry, like toggling, and episode progress into reducer effects
- route player navigation through the app shell instead of the view model

## What Was Done

### 1. Replaced the Detail view model with `DetailFeature`

`DetailFeature` now owns the screen state and effect orchestration for Detail.

The reducer state holds:

- the seed `movie`
- loaded `detail`
- `screenState`
- `selectedTab`
- `isLiked`
- `episodeProgressById`

It also exposes the computed values the UI needs:

- title and subtitle
- summary and overview text
- metadata pills
- available tabs and effective tab selection
- backdrop and trailer URLs

### 2. Moved loading, retry, like, and progress work into reducer effects

The Detail reducer now handles:

- initial load
- retry
- tab selection
- like toggling
- episode progress refresh

The load effect:

- loads the detail record first
- then loads liked state and episode progress
- keeps the screen cancellable so a retry can replace an in-flight load

Like toggling stays pessimistic:

- the reducer waits for the store response before changing `isLiked`

### 3. Converted the Detail UI to store-driven SwiftUI

`DetailView` now takes `StoreOf<DetailFeature>`.

The view:

- reads the title, metadata, tabs, and loading state from store state
- sends user intent back through reducer actions
- keeps the current overlay and iPad layout structure stable

`DetailsIpadScreen` now reads from the store too, including:

- tab selection
- episode progress
- related movie navigation intent

### 4. Routed Detail -> Player through `AppFeature`

`AppFeature` now intercepts `playEpisodeTapped` from the Detail path element.

When that action arrives, the shell appends a `PlayerFeature.State` built from the current Detail state and the tapped episode.

This keeps navigation centralized in the shell and avoids pushing Player directly from the view.

### 5. Removed the legacy Detail view model

`DetailViewModel.swift` was deleted after the TCA Detail screen was wired up.

Preview helpers were moved into shared Detail fixture code so SwiftUI previews and tests can keep using the same sample data.

## Test Coverage

The new reducer tests cover:

- successful load
- load failure
- retry cancellation and reload
- like toggling
- valid and invalid tab selection
- episode progress refresh
- play episode intent without local mutation

`AppFeature` tests also verify that tapping an episode on Detail pushes a Player route with the correct payload.

## What Stayed The Same

- The Detail screen layout stayed visually close to the existing UI.
- The repository, liked movie store, and playback store were reused.
- The shell remains the only place that creates navigation path elements.

