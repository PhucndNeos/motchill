# Phase 3 Result: Home Feature Migrated to TCA

## What This Phase Was For

This phase moved the Home screen from the legacy MVVM path into a real TCA feature while keeping the current UI and behavior stable.

If you are new to TCA, the core idea is:

- the reducer owns the screen state
- the view sends actions instead of mutating business state directly
- asynchronous work happens through reducer effects
- dependencies are injected so the feature can be tested without real network or storage

Home was the right first real feature after the shell because it already had:

- async loading
- retry
- selection synchronization between sections and hero movies
- navigation side effects to search and detail

That made it a good candidate for TCA, because the reducer can own all of those flows more cleanly than a view model plus view callbacks.

## What Was Done

### 1. Replaced `HomeViewModel` with `HomeFeature`

The file [HomeFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Home/HomeFeature.swift) now contains the Home reducer.

The feature state now owns:

- `status: HomeScreenState`
- `selectedSection`
- `selectedMovie`

It also exposes computed helpers that mirror the old view model behavior:

- `loadedContent`
- `sections`
- `heroSection`
- `heroMovies`
- `contentSections`
- `hasRenderableContent`

Why this matters:

- the feature has one source of truth
- the view no longer has to reach into a separate object to know what should render
- the logic is now easier to test because the computed output comes directly from reducer state

### 2. Moved loading and retry into reducer effects

`HomeFeature` now handles:

- `onTask`
- `retryTapped`

Both actions start the same cancellable load effect.

The loading flow is:

1. fetch remote config
2. write the remote config into the shared store
3. call the repository to load home sections
4. send a load response back into the reducer

If remote config fails, the repository is not called.

Why this matters:

- the feature obeys the same flow as the old implementation
- duplicate retry requests can cancel the previous in-flight load
- the view does not need to know anything about remote config or repository details

### 3. Kept selection behavior aligned with the old Home screen

The reducer now owns the selected section and selected movie.

The important behaviors preserved here are:

- when the section changes, the hero movie is rebound to the first valid movie in that section
- when the home data reloads, the reducer tries to keep the current section and movie if they still exist
- if the old selection no longer exists, the reducer falls back to the first valid section and movie

Why this matters:

- SwiftUI components often depend on identity staying stable
- keeping selection reconciliation inside the reducer prevents the view from drifting out of sync
- the behavior stays close to the old `HomeViewModel`, so the UI does not visibly change

### 4. Switched the Home view to store-driven rendering

The file [HomeView.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Home/HomeView.swift) now takes `StoreOf<HomeFeature>`.

The file [HomeIpadComponents.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Home/HomeIpadComponents.swift) was also updated so the iPad layout reads from the store instead of a view model or router.

The UI now sends actions like:

- `.onTask`
- `.retryTapped`
- `.searchTapped`
- `.sectionSelected(...)`
- `.movieSelected(...)`
- `.detailTapped(movie: ...)`

Why this matters:

- the view is thinner
- the state flow is easier to reason about
- previewing and testing become simpler because the screen is driven by explicit state

### 5. Wired shell navigation to the actual tapped movie

The shell reducer in [AppFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/App/AppFeature.swift) now accepts `.home(.detailTapped(movie:))`.

That movie is passed into [DetailFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Detail/DetailFeature.swift), so the detail screen is no longer built from a hardcoded placeholder.

Why this matters:

- navigation stays in the app shell, but the payload comes from the actual Home state
- the Home feature does not push screens directly
- the reducer decides what navigation should happen

### 6. Removed the legacy Home MVVM file

The old `HomeViewModel.swift` file was removed after the reducer-backed UI was in place.

Why this matters:

- there is no second source of truth left for Home state
- future changes are forced through the reducer instead of accidentally going back to MVVM
- the cleanup lowers long-term maintenance cost

### 7. Added reducer tests for the migrated behavior

The new file [HomeFeatureTests.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/PhucTVTests/HomeFeatureTests.swift) covers the most important flows:

- remote config success
- remote config failure
- repository success
- repository failure
- retry flow
- section selection and hero rebinding
- selection reconciliation after reload

The app shell tests were also updated so route creation now uses the tapped movie payload.

Why this matters:

- TCA is strongest when behavior is locked down with reducer tests
- these tests describe the screen behavior in a way that is independent of UIKit or SwiftUI rendering details
- future refactors can use the tests as a safety net

## The Architecture Stack

This phase follows the same stack pattern as the earlier shell migration, but now the feature layer is real.

### App layer

Responsible for:

- app entry point
- shell navigation
- auth presentation
- route construction for Search, Detail, and Player

Relevant files:

- [AppFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/App/AppFeature.swift)
- [AppShellView.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/App/AppShellView.swift)

### Feature layer

Responsible for:

- screen state
- user actions
- loading and retry effects
- selection behavior
- navigation intents sent upward to the shell

Relevant files:

- [HomeFeature.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Home/HomeFeature.swift)
- [HomeView.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Home/HomeView.swift)
- [HomeIpadComponents.swift](/Users/inyourdream./Work/swift-projects/motchill/motchill/swiftUI/Features/Home/HomeIpadComponents.swift)

### Dependency layer

Responsible for:

- repository access
- remote config access
- remote config persistence
- test overrides

In this phase, Home uses the same live services as before, but through TCA dependency injection.

### Data and core layers

Responsible for:

- networking
- models
- logging
- remote image loading
- storage and auth infrastructure

These layers were intentionally left intact.

## How The TCA Data Flow Works Here

If you are not familiar with TCA, this is the easiest way to think about the Home screen now:

1. SwiftUI renders the current `HomeFeature.State`.
2. The user taps something or the view appears.
3. The view sends a `HomeFeature.Action`.
4. The reducer updates the state immediately if it can.
5. If it needs to do work, it starts an effect.
6. The effect finishes and sends back a response action.
7. The reducer updates the state again.
8. SwiftUI redraws from the new state.

That means the reducer is the place where the business rules live.

The view still matters, but only for presentation and user interaction.

## Technical Decisions Locked In

- Home uses TCA state, action, and effects as its new source of truth.
- Loading is cancellable so retry can replace an in-flight request.
- The current selection model stays object-backed for now, because it matches the existing SwiftUI controls and keeps the migration low risk.
- Navigation continues to flow through `AppFeature`, not directly from the Home view.
- Detail receives the tapped movie payload instead of a placeholder movie.
- The old MVVM implementation is removed once the reducer-backed version is verified.

## What Stayed The Same

- UI copy and visual design did not change.
- Remote config and repository implementations were reused.
- iPad-specific layout behavior was preserved.
- Loading, empty, error, and loaded states still map to the same screen states the app already had.
- The shell navigation structure from phase 2 stayed in place.

## Why This Design Is Easier To Continue

This phase makes the next feature migrations much cheaper.

Search, Detail, and Player can now follow the same playbook:

- make a reducer own the state
- move async work into effects
- keep the view thin
- send navigation intents to the shell
- cover behavior with `TestStore`

That is much easier to maintain than having each screen invent its own flow pattern.

## Verification

The migration was verified with targeted reducer tests:

- `HomeFeatureTests`
- `AppFeatureTests`

The build and tests passed after the migration.

## What Comes Next

The next phase can migrate Search, then Detail, then Player using the same pattern.

At this point, Home is no longer a placeholder TCA screen. It is a real reducer-backed feature with the same behavior as before, but much clearer ownership of state and effects.
