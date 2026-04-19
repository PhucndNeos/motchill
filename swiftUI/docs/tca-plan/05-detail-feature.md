# Phase 5: Migrate Detail Feature to TCA

## Summary

- `fit`: Detail is the next high-value migration because it still owns async loading, like toggling, episode progress, tab selection, and player navigation.
- The foundation is already in place from the previous phases:
  - Phase 1 added the TCA dependency system.
  - Phase 2 moved the shell navigation into `AppFeature`.
  - Phase 3 migrated Home to TCA.
  - Phase 4 migrated Search to TCA and moved Search detail taps through the shell.
- Detail is now the last major screen still on the old MVVM path.

## Current State

- `DetailFeature.swift` contains only a placeholder reducer/view.
- `DetailView.swift` is still the legacy MVVM screen with a local `DetailViewModel`.
- `DetailViewModel.swift` still owns:
  - detail loading
  - retry
  - like toggling
  - episode progress loading
  - tab selection
  - player navigation intent
- `AppShellView.swift` already routes to `DetailFeatureView(store:)`, so the shell destination is ready for replacement once the real Detail screen is built.
- `AppFeature.swift` already owns the navigation path, so Detail should continue to navigate through the shell instead of pushing routes directly.

## Goal

Move all Detail screen state, loading, like/progress behavior, and player navigation into TCA. Replace the legacy `DetailViewModel` with a reducer-backed `DetailFeature`, then retire the placeholder `DetailFeatureView`.

## Files to Touch

- `swiftUI/Features/Detail/DetailFeature.swift`
- `swiftUI/Features/Detail/DetailView.swift`
- `swiftUI/Features/Detail/DetailViewModel.swift`
- `swiftUI/Features/Detail/DetailPresentation.swift`
- `swiftUI/App/AppFeature.swift`
- `swiftUI/App/AppShellView.swift`
- `swiftUI/PhucTVTests/DetailFeatureTests.swift`
- `swiftUI/PhucTVTests/AppFeatureTests.swift`
- `swiftUI/docs/tca-plan/05-detail-feature-result.md`

## Implementation Steps

1. Expand `DetailFeature` into the real reducer-owned screen state.
2. Move the initial load and retry flow into cancellable reducer effects.
3. Keep the selected tab and visible tab validation in reducer state.
4. Move like toggling into reducer actions with the liked-movie store dependency.
5. Move episode progress loading into reducer-owned state/effects.
6. Keep presentation helpers pure so `DetailPresentation.swift` can still be reused.
7. Route player navigation through an explicit reducer action that the shell converts into a `PlayerFeature` path element.
8. Update `AppShellView` to render the final Detail screen entry point instead of the placeholder view.
9. Remove `DetailViewModel.swift` only after the reducer-backed screen is verified.

## Test Plan

- Add reducer tests for:
  - detail load success
  - detail load failure
  - retry after failure
  - like toggle success
  - invalid tab selection ignored
  - episode progress refresh
  - open-player navigation intent
  - back button behavior
- Update shell navigation tests to confirm:
  - Search detail taps still reach Detail through `AppFeature`
  - Detail -> Player routing continues to go through the navigation path

## Acceptance Criteria

- Detail behavior matches the current UI and data flow.
- The feature no longer depends on `DetailViewModel` for state ownership.
- `DetailFeature` becomes the source of truth for the screen.
- The shell remains the only place that creates navigation path elements.
- The old MVVM detail path can be deleted after tests and smoke checks pass.
