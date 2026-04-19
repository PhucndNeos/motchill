# Task 3: Migrate Home Feature

## Goal

Replace `HomeViewModel` with a TCA feature while preserving current Home behavior.

## Files to Touch

- `swiftUI/Features/Home/HomeView.swift`
- `swiftUI/Features/Home/HomeViewModel.swift`
- `swiftUI/Features/Home/HomeScreenState.swift`
- Home-specific helper files only if they become feature-owned state helpers

## Implementation Steps

1. Create a `HomeFeature` reducer with observable state.
2. Move loading, retry, and selection logic into reducer actions.
3. Preserve current section/hero selection behavior.
4. Keep remote config fetch and repository load as effects.
5. Keep loading, empty, error, and loaded states aligned with current UI.
6. Update the view to use `StoreOf<HomeFeature>`.
7. Remove the old view model only after the reducer-backed view is stable.

## Test Plan

- Add reducer tests for:
  - remote config success
  - remote config failure
  - repository success
  - repository failure
  - selection persistence after reload
  - retry flow
- Keep the current Home expectations covered by tests before deleting the old model.

## Acceptance Criteria

- Home renders from a TCA store.
- There is no user-visible regression in loading or selection behavior.
- `HomeViewModel` can be removed safely after the migration.
