# Native iOS Phase 2 Progress

## Status

Phase 2 is complete for the shell/navigation migration scope.

The app shell now runs on TCA tree-based navigation with placeholder feature reducers, while the older MVVM screens remain available for later migration phases.

## What Was Delivered

- The root app feature now owns app-wide navigation state with `StackState`.
- Home, Search, Detail, and Player are represented by separate TCA placeholder features.
- `AppShellView` now renders from the `StoreOf<AppFeature>` instead of the custom router.
- Auth presentation moved into a dedicated TCA feature and uses presentation state rather than a boolean flag.
- `AuthView` is now store-driven and uses direct TCA bindings instead of manual `Binding(get:set:)` wiring.
- `onOpenURL` and auth-session refresh flow through the reducer path instead of bypassing TCA.
- The TCA dependency bridge was modernized so the app boots through dependency values and client wiring, not SwiftUI environment injection.
- App navigation and auth presentation tests pass after the migration.

## Technical Decisions Locked In

- `StackState` is the shell navigation model for the TCA migration.
- Placeholder feature reducers are the temporary bridge for phase 2.
- Legacy MVVM screens stay in the repository until the feature migration phases replace them one by one.
- Auth sheet presentation uses TCA presentation state, not a separate boolean flag.
- Dependency injection stays inside the TCA dependency system.
- `AppRouter` is kept only for compatibility during the transition, not as the new source of truth.

## Known Gaps Kept Intentionally

- Home, Search, Detail, and Player placeholder reducers do not yet contain the real view model logic.
- The legacy MVVM screens are still compiled and available, but they are not part of the new shell flow.
- Router cleanup can happen later once all feature logic is migrated into TCA reducers.

## Cleanup Targets

These pieces are intentionally temporary and should be deleted once the later phases fully move the real feature logic into TCA:

- the placeholder feature reducers and views for Home, Search, Detail, and Player
- the legacy `AppRouter` shell path once no screen depends on it for navigation
- the compatibility bridge code in `AppDependencies+TCA.swift` if a cleaner dependency layout replaces it later
- any auth-shell glue that only exists to support the transition from boolean sheet state to TCA presentation state
- any report or note that still describes the placeholder shell as the active implementation after migration finishes

## Verification

- Reducer tests passed for shell routing, auth presentation, and auth callback handling.
- The app build passed after the shell swap.
- The auth sheet warning from the old `sheet(store:)` API was removed.

## Phase 3 Input

Phase 3 should migrate the actual feature behavior into the placeholder reducers one screen at a time:

- Home first
- then Search
- then Detail
- then Player

Each feature can reuse its placeholder shell entry point while the real view model logic is moved behind TCA state and actions.

## Ready For Phase 3

The shell migration is now stable enough to start moving actual screen behavior into the new feature reducers without reopening the navigation foundation.
