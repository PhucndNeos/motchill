# Task 2: Move App Shell and Navigation to TCA

## Status

Done.

The shell now uses TCA tree-based navigation with placeholder feature reducers, while the legacy MVVM screens remain in the repo for later phases.
This phase file is the current source of truth for the TCA migration; the older non-TCA docs may be stale until they are refreshed later.

## Goal

Replace the custom router with TCA-driven app state and navigation.

## Files Updated

- [swiftUI/App/AppFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/App/AppFeature.swift)
- [swiftUI/App/AppShellView.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/App/AppShellView.swift)
- [swiftUI/App/PhucTvSwiftUIApp.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/App/PhucTvSwiftUIApp.swift)
- [swiftUI/App/AppDependencies+TCA.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/App/AppDependencies+TCA.swift)
- [swiftUI/Features/Auth/AuthFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Auth/AuthFeature.swift)
- [swiftUI/Features/Auth/AuthView.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Auth/AuthView.swift)
- [swiftUI/Features/Home/HomeFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Home/HomeFeature.swift)
- [swiftUI/Features/Search/SearchFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Search/SearchFeature.swift)
- [swiftUI/Features/Detail/DetailFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Detail/DetailFeature.swift)
- [swiftUI/Features/Player/PlayerFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Player/PlayerFeature.swift)
- [swiftUI/Features/Common/PlaceholderFeatureScreen.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Common/PlaceholderFeatureScreen.swift)

## What Was Implemented

1. Root shell state now owns a `StackState`-backed navigation path.
2. The shell presents `HomeFeature`, `SearchFeature`, `DetailFeature`, and `PlayerFeature` as placeholder reducers instead of forwarding to the old router.
3. Auth sheet presentation moved into TCA presentation state with `@Presents`.
4. `AuthFeature` became a standalone reducer and `AuthView` now binds directly to the store.
5. `onOpenURL` now flows through `AppFeature` so the shell can react through reducer logic.
6. The dependency bridge uses TCA dependency clients, not SwiftUI environment injection.
7. The legacy `AppRouter` and MVVM screens were kept intact for later phases, but the shell no longer depends on them as the source of truth.

## Test Plan

- Reducer tests cover:
  - push search route
  - push detail route
  - push player route
  - pop route
  - pop-to-root
  - present and dismiss auth sheet
  - handle auth callback URL
- Shell smoke coverage confirms the root still launches and reaches the placeholder feature flow.

## Cleanup Targets

These pieces are intentionally temporary and should be deleted once the later phases fully move the real feature logic into TCA:

- the placeholder feature reducers and views for Home, Search, Detail, and Player
- the legacy `AppRouter` shell path once no screen depends on it for navigation
- the compatibility bridge code in `AppDependencies+TCA.swift` if a cleaner dependency layout replaces it later
- any auth-shell glue that only exists to support the transition from boolean sheet state to TCA presentation state
- any report or note that still describes the placeholder shell as the active implementation after migration finishes

## Acceptance Criteria

- App navigation is controlled by TCA state.
- `AppRouter` is no longer the shell source of truth.
- Search/detail/player are reachable through the TCA navigation stack.
- Auth banner and auth sheet are driven by reducer state.
