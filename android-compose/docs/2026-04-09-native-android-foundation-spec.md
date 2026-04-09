# Native Android Foundation Spec

## Summary

This document defines the initial architecture for the native Android version of Motchill in `android-compose/`. The goal is to reproduce the current Flutter app behavior on Android while keeping the codebase easy to extend in later phases.

The first implementation phase keeps the app intentionally small:

- one Android app module
- one Compose UI shell
- explicit package boundaries for app, core, data, and features
- a data flow that matches the current Flutter app: API -> repository -> state holder -> UI

The spec is written to support incremental delivery. Phase 0 builds the project foundation only; later phases add real data flow and feature parity screen by screen.

## Goals

- Create a standalone Android app in `android-compose/`.
- Keep parity with the current Flutter app's core behavior:
  - home feed
  - search/category
  - detail page
  - player
  - liked-only local state
  - playback resume
  - direct stream plus embedded source handling
- Use a conventional Android architecture that can scale without large rewrites.
- Keep all business rules visible and testable in Kotlin.

## Non-goals

- No iOS native work.
- No backend redesign in phase 0.
- No UI redesign beyond what is needed for the native shell.
- No attempt to port every Flutter implementation detail line by line.

## Architecture

### Project shape

`android-compose/` is a standalone Android application workspace. It starts as a single app module to reduce setup overhead, but the package structure is deliberately layered so features can later be extracted into Gradle modules if the codebase grows.

### Internal layers

- `app/`: application entry point, app graph, navigation shell, and top-level theme
- `core/`: shared config, network, security, storage, utilities, and design system
- `data/`: DTOs, mappers, repository implementations, and API integrations
- `domain/`: stable business models and use cases when the app needs an explicit boundary
- `feature/<name>/`: screen state, UI, and screen-specific logic

### State flow

The default flow is:

`UI -> ViewModel -> Repository -> Remote API / Local Storage -> mapped domain state -> UI`

Rules:

- UI should render state only and emit user events.
- ViewModels own screen state and orchestration.
- Repositories hide transport, encryption, and persistence details.
- Screen models should be stable enough to survive API shape changes.

### Recommended stack

- Kotlin
- Jetpack Compose + Material 3
- Navigation Compose
- ViewModel + StateFlow
- Retrofit + OkHttp
- kotlinx.serialization or Moshi, chosen once and used consistently
- Coil for images
- A persistent local storage abstraction for likes and resume data, swappable behind a stable interface
- DataStore for small settings only
- ExoPlayer / Media3 for direct streams
- WebView for embedded sources

## Behavioral contracts

The Android app must preserve the current product rules:

- Home renders sections from the public API and navigates to detail.
- Search supports filters, paging, and local liked-only filtering.
- Detail shows all real fields that exist in the API response and hides empty sections.
- Player distinguishes between direct streams and embedded sources.
- Playback resume is stored per episode.
- Liked items remain available locally even when the search API returns no result.

## Data contracts

The native app should preserve the same conceptual entities the Flutter app already uses:

- Home section and movie card
- Navbar/category item
- Popup ad config
- Movie detail
- Movie episode
- Search filter data
- Search result and pagination
- Play source and track

The actual Kotlin model names can differ, but their responsibilities should remain the same.

## Navigation

The app should expose the same navigation intent as the Flutter version:

- home
- search
- category preset search
- detail
- player

Category should behave like a preset search entry rather than a separate feature island.

## Phase plan

### Phase 0: Foundation

- Create the Android project scaffold.
- Add the top-level architecture spec.
- Add the app shell, theme, and navigation placeholders.
- Prepare package boundaries for core, data, and features.
- Keep the implementation small enough that the next phase can add data flow without undoing the shell.

### Phase 1: Data foundation

- Add API client, config, and request headers.
- Add payload decryption for search and playback responses.
- Add models and repository contracts.
- Add local storage for likes and resume behind a swappable persistence adapter.

### Phase 2: Home

- Render the home feed.
- Wire navigation to detail and search.
- Add loading, empty, and error states.

### Phase 3: Detail

- Render the cinematic detail screen.
- Show episodes, gallery, related items, and like/unlike behavior.
- Keep the UI data-first and hide empty sections.

### Phase 4: Player

- Add direct stream playback.
- Add embedded source playback.
- Add source switching, resume, and track selection.

### Phase 5: Search and category

- Add filter sheets, paging, and category presets.
- Add liked-only local search behavior.
- Preserve route parameter parity with Flutter.

### Phase 6: Hardening

- Add tests for model mapping, decryption, and screen logic.
- Run emulator verification on the main flow.
- Polish edge cases and release packaging.

## Phase 0 acceptance criteria

- The `android-compose/` workspace exists.
- The project structure clearly shows the intended architecture boundaries.
- A Compose app shell can be opened and expanded in later phases.
- The spec lives inside `android-compose/docs/` and describes the long-term architecture clearly enough to guide later work.

## Assumptions

- The Android app will start as a standalone workspace, not a module inside the Flutter project.
- The backend stays unchanged for phase 0.
- The first implementation wave prioritizes parity and extensibility over micro-optimizations.
