# Task 7: Cleanup and Stabilization

This phase is complete. See [07-cleanup-stabilization-result.md](./07-cleanup-stabilization-result.md) for the finished state.

## Goal

After the core screens have moved to TCA, remove the remaining MVVM and router leftovers, then standardize the codebase so the TCA path is the only active architecture for migrated screens.

This phase is intentionally post-migration cleanup. It should happen only after Home, Search, Detail, and Player are stable.

## Current Baseline

At this point:

- the shell already routes through TCA
- Home, Search, Detail, and Player are reducer-backed
- legacy view models are being removed feature by feature
- preview helpers are gradually moving into fixture files
- binding and effect patterns should now be consistent across features

## Files to Touch

- `swiftUI/App/AppRouter.swift`
- `swiftUI/App/AppRoute.swift`
- `swiftUI/App/AppRootViewModel.swift`
- any remaining `*ViewModel.swift` files
- any now-unused presentation helpers
- previews that still instantiate legacy view models
- tests that still assume the old MVVM path

## Cleanup Steps

1. Remove dead code that is no longer referenced by migrated features.
   - delete obsolete view models only after their TCA replacements are stable
   - remove stale router branches and unused presentation helpers

2. Standardize preview and fixture usage.
   - move reusable preview data into feature-specific fixture files
   - make previews construct `Store` values instead of legacy view models

3. Normalize binding and reducer patterns.
   - keep `BindingReducer()` and `BindableAction` usage consistent
   - prefer binding-driven source selection and state selection updates where appropriate
   - keep runtime-heavy objects out of observed business state

4. Convert remaining tests to reducer tests where applicable.
   - keep behavior coverage close to the feature reducer
   - preserve runtime identity tests for media/player-style objects when needed

5. Verify shell and side-effect routing.
   - ensure navigation, playback, and async work continue to flow through TCA
   - confirm no migrated screen still depends on the old architecture path

## Test Plan

- Run the full `swiftUI/PhucTVTests` suite.
- Do a simulator smoke test through:
  - Home
  - Search
  - Detail
  - Player
- Fix any regressions before deleting the next batch of legacy code.

## Acceptance Criteria

- The app builds without the legacy router/view-model path for migrated screens.
- The TCA path is the only active architecture for the main feature flow.
- Shared patterns across features feel consistent instead of mixed between old and new styles.
- The test suite remains green.
