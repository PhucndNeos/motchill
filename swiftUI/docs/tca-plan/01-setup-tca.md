# Task 1: Add TCA Foundation

## Status

Done.

## Goal

Add the Composable Architecture package and prepare the app for feature-by-feature migration.

## Files to Touch

- `swiftUI/PhucTvSwiftUI.xcodeproj/project.pbxproj`
- `swiftUI/PhucTvSwiftUI.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- new TCA support files under `swiftUI/App/` or `swiftUI/Core/`

## Implementation Steps

1. Add `swift-composable-architecture` to the Xcode project.
2. Confirm the package resolves cleanly in the existing workspace.
3. Create a shared app dependency layer for TCA use.
4. Define dependency clients for the current service boundaries:
   - repository
   - liked movie store
   - playback position store
   - remote config
   - auth
   - screen idle control
5. Keep the existing `AppDependencies` type working while the new TCA layer is introduced.
6. Add a small TCA root feature scaffold that can compile without replacing any screens yet.

## What Was Implemented

1. Added `swift-composable-architecture` to the app project and linked the product into the main target.
2. Resolved the package graph successfully and pinned the package in `Package.resolved`.
3. Created [AppDependencies+TCA.swift](/Users/phucnd/Documents/motchill/swiftUI/App/AppDependencies+TCA.swift) as the TCA dependency bridge.
4. Exposed the current service boundaries as `DependencyValues` entries:
   - `phucTvRemoteConfigClient`
   - `phucTvRemoteConfigStore`
   - `phucTvRepository`
   - `phucTvLikedMovieStore`
   - `phucTvPlaybackPositionStore`
   - `phucTvLocalPlaybackPositionStore`
   - `phucTvAuthManager`
   - `phucTvScreenIdleManager`
5. Kept the live implementation backed by the existing runtime services so the app behavior stayed unchanged.
6. Created [AppFeature.swift](/Users/phucnd/Documents/motchill/swiftUI/App/AppFeature.swift) as the root reducer scaffold for later shell migration.
7. Verified the app still builds successfully after the integration.

## Test Plan

- Run a clean build after package integration.
- Verify the app target still compiles.
- Confirm the app still launches with the old MVVM screens unchanged.

## Result

- The TCA package is available to the app target.
- The app has a root feature entry point prepared for future migration.
- Existing UI and routing were left untouched in this phase.
- The dependency layer is ready for feature reducers to use via `@Dependency`.

## Acceptance Criteria

- `ComposableArchitecture` can be imported by the app target.
- TCA dependency wiring exists but is not yet used by feature screens.
- No user-facing behavior changes in this step.
- Phase 1 is complete and documented before moving on to shell/navigation migration.
