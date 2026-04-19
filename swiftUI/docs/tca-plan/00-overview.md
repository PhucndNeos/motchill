# TCA Migration Overview

## Status

- Phase 1 is complete.
- Phase 2 is complete.
- TCA package integration is in place.
- The app has a root `AppFeature`, dependency registration, and a TCA shell navigation stack.

## Goal

Move the SwiftUI app from `@Observable` MVVM and custom routing to TCA in a controlled, incremental way.

## Current State

- App shell uses `AppShellView`, `AppRoute`, and TCA navigation state.
- Remaining feature screens still driven by view models:
  - `DetailViewModel`
  - `PlayerViewModel`
- Feature screens that have already moved to TCA:
  - `HomeFeature`
  - `SearchFeature`
- Core services already exist and should be reused:
  - repository
  - liked movie store
  - playback position store
  - remote config client/store
  - auth manager
  - screen idle manager

## Migration Strategy

- Build a small TCA foundation first. This is now complete.
- Convert the shell and routing layer before migrating feature logic.
- Migrate the real feature logic into the placeholder reducers in this order:
  1. Home
  2. Search
  3. Detail
  4. Player
- Keep UI structure and copy stable while changing state management.
- Use reducer tests to prove behavior before deleting the old implementation.

## Non-Goals for the First Pass

- Do not rewrite the data layer.
- Do not rewrite Supabase integration.
- Do not refactor the design system at the same time.
- Do not split the project into multiple modules yet.

## Success Criteria

- Phase 1 adds TCA foundation code without changing visible app behavior.
- Each migrated feature has a TCA reducer and tests.
- Navigation works through TCA state instead of `AppRouter`.
- The app builds and runs after each task.
- The old MVVM code can be deleted only after its replacement is stable.

## Phase 1 Summary

Phase 1 established the minimum TCA runtime boundary needed for the rest of the migration:

- added the `swift-composable-architecture` package to the Xcode project
- registered the package product on the app target
- added a TCA dependency bridge in `AppDependencies+TCA.swift`
- exposed app services through `DependencyValues`
- created a root `AppFeature` reducer scaffold
- verified the app still builds after the integration

## Phase 2 Summary

Phase 2 moved the shell and navigation into TCA without migrating the legacy screen logic yet:

- added a `StackState`-backed navigation path to `AppFeature`
- introduced placeholder reducers for Home, Search, Detail, and Player
- moved auth sheet presentation into TCA presentation state
- refactored `AuthView` to use direct store bindings
- kept the MVVM screens compile-ready for later phase-by-phase migration
- verified shell routing, auth presentation, and auth callback handling with reducer tests

This phase prepares the app to migrate the real screen logic safely in later phases.
