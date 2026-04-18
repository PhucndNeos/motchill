# Phase 2 Result: TCA Shell Navigation

## What This Phase Was For

This phase moved the app shell and navigation layer into TCA so the rest of the app could migrate one screen at a time without redesigning the foundation again.

If you are new to TCA, the important idea is simple:

- state lives in one reducer-owned place
- the UI sends actions instead of mutating app flow directly
- side effects happen through reducer effects
- dependencies are injected so they can be swapped in tests

Phase 2 does not try to finish Home, Search, Detail, or Player yet. It only gives the app a TCA-controlled shell that those features can plug into safely.

## What Was Done

### 1. Moved app-level navigation into `AppFeature`

The root app feature now owns the navigation path with `StackState`.

What that means in practice:

- the shell no longer depends on the old router as the source of truth
- navigation is driven by reducer state
- pushes and pops can be tested like any other business logic

Why this matters:

- the app has one clear place where screen flow is decided
- future feature logic can reuse the same navigation model
- deep links and auth-driven transitions can now go through the reducer path

### 2. Introduced placeholder TCA features for the main screens

Home, Search, Detail, and Player each now have a TCA reducer and view entry point.

What these placeholders do:

- they give each screen a stable TCA home
- they allow the shell to compile and navigate through reducer-backed screens
- they keep the migration incremental instead of forcing a big-bang rewrite

Why this matters:

- each future feature phase can replace one placeholder at a time
- the app can stay shippable while the migration continues
- the team can test the shell before real screen logic is moved over

### 3. Moved auth presentation into reducer state

Auth is now controlled with TCA presentation state instead of a loose boolean flag.

What changed:

- the auth sheet is owned by `AppFeature.State`
- presenting and dismissing auth now happens through actions
- the auth banner and auth sheet stay coordinated by the reducer

Why this matters:

- the shell no longer mixes view state and app flow state
- sheet behavior becomes explicit and testable
- auth can react to URL callbacks and session refreshes without bypassing TCA

### 4. Switched the shell view to render from the store

`AppShellView` now reads `StoreOf<AppFeature>` directly.

What changed in the UI:

- the shell uses `NavigationStack` with store-scoped path state
- the root screen is rendered from `HomeFeatureView`
- auth overlay and auth sheet are both driven from store state

Why this matters:

- the view layer is now thin and declarative
- UI only reflects state and forwards user intent as actions
- the navigation structure is easier to reason about and debug

### 5. Kept app services inside the TCA dependency system

The shell still uses the existing app services, but now through TCA dependencies.

The main injected services are:

- remote config client and store
- repository
- auth manager
- liked movie and playback stores
- screen idle manager

Why this matters:

- reducers do not create services themselves
- live, preview, and test implementations can differ safely
- the shell migration did not require rewriting networking or storage

### 6. Preserved the live app behavior during the swap

The app still boots with the same backend and storage layers under the hood.

What stayed the same:

- repository implementation
- remote config fetching and storage
- Supabase auth behavior
- liked movie and playback storage
- direct stream support and other feature-layer behavior outside the shell

Why this matters:

- users should not feel a shell migration
- only the architecture changes, not the product behavior
- the migration remains reversible and safer to review

### 7. Verified the shell migration with reducer tests

The shell phase was backed by tests for navigation and auth flow.

The tests covered:

- pushing routes
- popping routes
- popping back to root
- presenting and dismissing auth
- handling auth callback URLs

Why this matters:

- the shell behavior is now executable documentation
- future feature migrations can build on a tested baseline
- regressions are easier to catch when state is reducer-owned

## The Architecture Stack

This phase uses a layered stack that is intentionally simple and explicit.

### App layer

Responsible for:

- app entry point
- root reducer
- shell navigation
- auth presentation
- global coordination

In code, that is mainly `AppFeature` and `AppShellView`.

### Feature layer

Responsible for:

- screen state
- screen actions
- feature-specific UI
- user interactions for one screen

In this phase, Home/Search/Detail/Player are placeholders only. They are there so the shell has a destination, not because their full behavior is finished.

### Dependency layer

Responsible for:

- injecting services into reducers
- keeping the app testable
- allowing live, preview, and test implementations

This is where the repository, remote config, auth, and storage clients are wired into TCA.

### Data and core layers

Responsible for:

- networking
- storage
- auth integration
- remote config
- utility code

Phase 2 intentionally does not rewrite these layers. It reuses them.

## How The Data Flow Works

The easiest way to understand TCA here is to follow the message flow:

1. A SwiftUI view shows state from the store.
2. The user taps a button or opens a URL.
3. The view sends an action to the reducer.
4. The reducer updates state immediately when it can.
5. If work is needed, the reducer starts an effect.
6. The effect finishes and sends a new action back.
7. The reducer updates state again.
8. SwiftUI re-renders from the new state.

That cycle replaces the old pattern where views, router code, and view models all had to coordinate manually.

## Why This Is Easier To Maintain

If you have not used TCA before, the biggest benefit is not “more architecture”. It is fewer hidden decisions.

With the shell in TCA:

- screen flow is visible in one place
- side effects are easier to trace
- tests can describe behavior instead of reconstructing UI state
- feature migration becomes incremental instead of all-at-once

For example:

- tapping Search no longer means “some view somewhere pushes a route”
- it means “the Home reducer received `.searchTapped` and the shell appended a search destination”

That is easier to debug, easier to test, and easier to extend.

## Technical Decisions Locked In

- `StackState` is the shell navigation model for the migration.
- Placeholder feature reducers are the temporary bridge for Home, Search, Detail, and Player.
- Auth presentation uses TCA presentation state.
- Dependency injection stays inside TCA dependencies.
- `AppRouter` is no longer the shell source of truth.

## Known Gaps Kept Intentionally

- Home, Search, Detail, and Player still contain placeholder reducer logic only.
- The legacy MVVM feature implementations remain in the repository for later migration.
- The shell still uses placeholder destination content until each feature is migrated in its own phase.
- Router cleanup can wait until all feature logic has moved into TCA reducers.

## What Comes Next

Phase 3 should migrate real Home behavior into the placeholder `HomeFeature`:

- loading
- retry
- section selection
- hero selection
- remote config fetch
- repository load
- loading / empty / error / loaded UI states

After Home is stable, the same pattern can be repeated for Search, Detail, and Player.

## Acceptance Criteria

- App navigation is controlled by TCA state.
- `AppRouter` is no longer the shell source of truth.
- Search, detail, and player are reachable through the TCA navigation stack.
- Auth banner and auth sheet are driven by reducer state.
- A new reader can understand how the shell works without already knowing TCA.
