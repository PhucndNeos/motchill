# Phase 1 Result: TCA Foundation

## What This Phase Was For

This phase created the minimum TCA foundation needed to migrate the app safely, one feature at a time.

If you have never used TCA before, the idea is simple:

- the app should have one clear place where state and actions live
- each screen should become a reducer over time
- shared services like networking, storage, auth, and remote config should be injected instead of created directly inside views
- tests should be able to replace those services with mock versions

This phase does not convert any visible screen yet. It only prepares the app so the later migration steps can be done without breaking the whole project.

## What Was Done

### 1. Added the TCA package

The app project now includes `swift-composable-architecture`.

Why this matters:

- TCA provides the reducer, state, action, and dependency tools used in later phases
- the app target can now import `ComposableArchitecture`
- we can start building features in the TCA style instead of only MVVM

### 2. Registered the package on the app target

The project file links the `ComposableArchitecture` product into the main app target.

Why this matters:

- importing a package is not enough by itself
- the target that compiles the app must actually link the product
- this is what lets the app code use TCA types and macros, or the protocol-based reducer API when needed

### 3. Created a dependency bridge for TCA

The file [AppDependencies+TCA.swift](/Users/phucnd/Documents/motchill/swiftUI/App/AppDependencies+TCA.swift) connects the app's existing services to TCA's dependency system.

It exposes these dependencies:

- `phucTvRemoteConfigClient`
- `phucTvRemoteConfigStore`
- `phucTvRepository`
- `phucTvLikedMovieStore`
- `phucTvPlaybackPositionStore`
- `phucTvLocalPlaybackPositionStore`
- `phucTvAuthManager`
- `phucTvScreenIdleManager`

Why this matters:

- TCA reducers should not create services themselves
- the dependency system lets us swap live, preview, and test implementations
- future reducers can read these dependencies with `@Dependency(\.name)` or the equivalent TCA access style

### 4. Kept the live app behavior using the existing runtime services

The new TCA dependency bridge still uses the app's current implementations under the hood:

- repository still uses the current API client
- remote config still uses the current remote config store/client
- auth still uses the current Supabase auth manager
- playback and liked movie stores still use the existing storage layers
- screen idle control still uses the current live manager

Why this matters:

- Phase 1 should not change user-visible behavior
- we want to introduce TCA without rewriting the backend/data layer at the same time
- this reduces risk and keeps the migration reversible

### 5. Added a root TCA feature scaffold

The file [AppFeature.swift](/Users/phucnd/Documents/motchill/swiftUI/App/AppFeature.swift) is the first root reducer for the app.

At this stage it is intentionally minimal:

- it has a small `State`
- it has a small `Action`
- it proves the app can compile with a TCA reducer in place

Why this matters:

- every TCA app needs a root feature somewhere
- later we will move app-level state, shell navigation, and global side effects into this feature
- this file is the anchor point for the rest of the migration

### 6. Verified the app still builds

The project was built successfully after the integration.

Why this matters:

- a migration step is only safe if the app still compiles
- a green build confirms the package integration and dependency wiring are correct
- it gives us a stable base for the next phase

## The Mental Model

Before Phase 1:

- views and view models directly owned most of the app state
- services were created and passed around more manually
- there was no TCA root layer yet

After Phase 1:

- the app has a TCA root feature ready
- shared app services are registered in TCA's dependency system
- later reducers can ask for those services without knowing where they come from
- tests can override dependencies cleanly

## Why The Setup Is Useful Even Though No Screen Changed

This phase looks small, but it removes the hardest part of a TCA migration: getting the foundation wrong.

If we skipped this and started migrating screens immediately, we would risk:

- duplicating service creation in multiple reducers
- tightly coupling features to concrete implementations
- making tests harder to write
- having to redo the wiring later when shell navigation moves to TCA

By doing the foundation first, every later feature migration becomes mostly about screen logic, not infrastructure.

## What Did Not Change

- Home, Search, Detail, and Player still use their existing view models
- shell navigation still works the old way
- the design system is untouched
- Supabase and repository implementations are untouched
- no business logic was rewritten yet

## What Comes Next

The next phase will move the app shell and navigation into TCA.

That is the point where the root feature starts doing real work:

- app-level state
- navigation routing
- global side effects
- future deep links and presentation logic

In short, Phase 1 prepared the ground. Phase 2 starts using that ground for actual app flow.
