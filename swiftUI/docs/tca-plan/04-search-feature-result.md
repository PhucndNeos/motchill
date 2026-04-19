# Phase 4 Result: Search Feature Migrated to TCA

## What This Phase Was For

This phase moved the Search screen from `SearchViewModel` into a real TCA feature while keeping the existing UI structure and presentation helpers intact.

Search was a good fit for TCA because it combines:

- async bootstrap loading
- filter and sort orchestration
- pagination
- liked-only local filtering
- detail navigation through the app shell

## What Was Done

### 1. Replaced the Search view model with `SearchFeature`

`SearchFeature` now owns the screen state and effect orchestration.

The reducer state keeps:

- `uiState: SearchUIState`
- `routeInput: SearchRouteInput`
- `activePicker: SearchPickerKind?`
- a bootstrap guard so the initial load only runs once per presentation

Why this matters:

- the Search screen now has a single source of truth
- presentation helpers in `SearchPresentation.swift` could be reused instead of rewritten
- async side effects are testable through reducer actions

### 2. Moved bootstrap, pagination, and filter changes into reducer effects

The reducer now handles:

- initial bootstrap
- retry
- refresh
- search submit and clear
- category, country, type, year, and order changes
- page navigation
- liked-only toggle

Why this matters:

- the old view model no longer owns screen behavior
- search requests can be cancelled and replaced cleanly
- local liked-only mode stays local and does not hit the repository again

### 3. Converted the Search view to store-driven SwiftUI

`SearchView` now reads directly from `StoreOf<SearchFeature>`.

The view now:

- binds search text through the store
- drives picker sheets through reducer state
- sends detail taps and back actions as reducer actions
- keeps the existing layout, filter strip, overlay, and results grid stable

Why this matters:

- the UI layer is now thin
- screen interactions are explicit and easy to trace
- SwiftUI only reflects reducer state instead of managing its own copy

### 4. Routed Search detail navigation through the shell

The app shell now handles Search detail taps by pushing `DetailFeature.State(movie:)` onto the TCA navigation path.

Why this matters:

- Search no longer pushes routes directly
- navigation remains centralized in `AppFeature`
- the shell can now test Search -> Detail flow in the same style as Home

### 5. Removed the legacy Search MVVM implementation

`SearchViewModel.swift` and its old tests were deleted after the TCA version was in place.

Why this matters:

- there is no second source of truth left for Search
- all future Search behavior changes must go through the reducer
- the codebase is smaller and easier to reason about

## Test Coverage

The new reducer tests cover:

- bootstrap success
- bootstrap failure
- search submit and pagination
- filter changes
- liked-only local behavior
- cancellation when a newer search replaces an in-flight request

The shell tests also cover Search detail routing.

## Technical Decisions Locked In

- `SearchUIState` stays as the reusable presentation state container.
- `SearchRouteInput` remains the route seeding input.
- `SearchFeatureView` was only a temporary placeholder and has been retired.
- Search detail routing continues to flow through `AppFeature`.

## What Comes Next

The next migration phase can continue with Detail using the same TCA playbook:

- reducer-owned screen state
- cancellable async effects
- explicit navigation actions
- reducer tests before deleting the legacy view model
