# Task 4: Migrate Search Feature

## Goal

Move all Search screen state and actions into TCA, including filters, paging, and liked-only mode.

## Files to Touch

- `swiftUI/Features/Search/SearchView.swift`
- `swiftUI/Features/Search/SearchViewModel.swift`
- `swiftUI/Features/Search/SearchPresentation.swift`
- search UI state helpers and picker helpers

## Implementation Steps

1. Create a `SearchFeature` reducer.
2. Move search text, committed query, filters, liked-only mode, pagination, and picker state into reducer state.
3. Convert text input to binding actions.
4. Keep the current load/refresh/error overlay behavior.
5. Keep picker sheets and filter chips working from reducer state.
6. Route detail navigation through the app shell instead of calling the router directly.
7. Remove the old view model only after the store-backed screen is stable.

## Test Plan

- Add reducer tests for:
  - initial load
  - initial query submission
  - category/country/type/year/order filter changes
  - liked-only mode behavior
  - paging forward/back
  - error state handling
- Verify the repository is not called again when liked-only mode is toggled.

## Acceptance Criteria

- Search is fully store-driven.
- Filter and paging behavior remains unchanged.
- The old MVVM Search path can be deleted after replacement.
