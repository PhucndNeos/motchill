# Supabase Auth and Sync Flow

This document describes the current login and data sync behavior used by the native app, with an Android implementation in mind. The goal is to keep the contract clear enough that the Android version can match behavior without copying iOS code.

## 1. Scope

This flow covers two synced data domains:

- Liked movies
- Playback progress per episode

The auth layer is based on Supabase Email OTP. After a successful sign-in, the app migrates any pending local data into Supabase and clears the synced local records.

## 2. High-Level Behavior

- The app uses Supabase Auth for login, session restore, and sign-out.
- The app listens to auth state changes.
- When the user becomes signed in, the app runs a local-data migration step.
- Playback progress is written locally first.
- Playback progress is synced to Supabase only at chosen moments.
- Remote data remains the primary read path for the rest of the app.

In practice:

- `save` goes to local storage
- `load` stays remote-first
- `sync` happens at explicit points

This keeps continuous playback updates cheap while preserving cross-device sync.

## 3. Authentication Flow

### 3.1 Sign in

1. User enters an email address.
2. App requests an OTP from Supabase.
3. User enters the OTP.
4. App verifies the OTP with Supabase.
5. Supabase emits an authenticated session.
6. App updates its auth state and triggers the migration/sync step.

### 3.2 Session restore

On app startup or app foregrounding, the app restores the current Supabase session if it exists.

If the restored session is valid:

- auth state becomes signed in
- migration/sync runs again

### 3.3 Sign out

On sign out:

- Supabase session is cleared
- auth state becomes signed out
- no migration is triggered

## 4. Sync Responsibilities

### 4.1 Liked Movies

Liked movies are stored remotely in Supabase and also cached locally.

On sign-in:

- the app reads any local liked movie payloads
- it upserts them into Supabase
- it clears the local legacy liked-movie keys after success

### 4.2 Playback Progress

Playback progress follows a write-buffer pattern:

- the player writes progress to local storage
- sync happens later at selected points
- when sync succeeds, the local pending record is cleared or marked synced

This reduces write pressure while keeping resume state and cross-device sync available.

## 5. Playback Progress Lifecycle

### 5.1 Save path

Playback progress should be saved locally when:

- the player time observer reaches the next checkpoint bucket
- the user pauses playback
- the user seeks to a new position and the seek completes
- the user changes source
- the player screen disappears

The time observer should not write to Supabase every tick.

Recommended behavior:

- update UI every `0.25s`
- checkpoint local progress about every `15s` of playback delta

### 5.2 Sync path

Playback progress should be synced to Supabase when:

- the user pauses playback
- a seek operation completes
- the user changes source
- the player screen disappears
- auth restore or sign-in completes and the migrator runs

If sync fails:

- keep the local pending record
- retry on the next explicit sync opportunity

## 6. Conflict Resolution

Playback progress uses a simple rule:

- furthest position wins
- if positions are equal, longer duration wins
- if both values are identical, skip the write

This is intentionally simple and deterministic for multi-device use.

### Why this rule

- It preserves the farthest watched position.
- It avoids repeated writes when data is unchanged.
- It is easy to implement in Android and iOS consistently.

## 7. Data Model

### 7.1 Supabase Auth

Auth uses email OTP and the active Supabase session.

Android should treat the session as the source of truth for authenticated user identity.

### 7.2 Liked Movies Table

Expected columns:

- `user_id`
- `movie_id`
- `movie_snapshot`
- `created_at`

Expected conflict key:

- `user_id, movie_id`

### 7.3 Playback Positions Table

Expected columns:

- `user_id`
- `movie_id`
- `episode_id`
- `position_ms`
- `duration_ms`
- `updated_at`

Expected conflict key:

- `user_id, movie_id, episode_id`

## 8. Suggested Android Architecture

The cleanest Android mapping is:

- `AuthManager` or `AuthRepository` for Supabase login/session state
- `LocalPlaybackStore` for local episode progress writes
- `RemotePlaybackStore` for Supabase reads and upserts
- `LegacyDataMigrator` or `SyncCoordinator` for auth-triggered migration
- `PlayerViewModel` for UI state only, not direct Supabase orchestration

Recommended dependency direction:

`PlayerViewModel -> LocalPlaybackStore`

`AuthManager -> Migrator -> RemotePlaybackStore + LocalPlaybackStore`

`DetailViewModel -> RemotePlaybackStore`

This keeps the player simple while still preserving the remote source of truth for reads.

## 9. Sync Timing Matrix

| Event | Local save | Remote sync |
| --- | --- | --- |
| Time observer tick | Yes | No |
| Pause | Yes | Yes |
| Seek complete | Yes | Yes |
| Source change | Yes | Yes |
| Player disappear | Yes | Yes |
| Login/session restore | Maybe already pending | Yes via migrator |
| Sign out | No | No |

## 10. Error Handling

### 10.1 Auth failures

- Show a visible auth error state.
- Keep the current session signed out.
- Do not clear local progress unless the user explicitly signs out.

### 10.2 Sync failures

- Preserve local pending playback progress.
- Retry on the next sync opportunity.
- Do not block playback.

### 10.3 Partial migration

If liked movies sync succeeds but playback sync fails, the app should:

- keep playback pending locally
- still clear the liked-movie payload if that part succeeded

This avoids re-uploading already completed data.

## 11. Android Implementation Checklist

- [ ] Supabase OTP sign-in
- [ ] Session restore listener
- [ ] Auth state change listener
- [ ] Local playback store
- [ ] Remote playback store
- [ ] Liked movies sync on sign-in
- [ ] Playback progress local save
- [ ] Playback progress explicit sync points
- [ ] Furthest-position conflict rule
- [ ] Pending retry after failed sync
- [ ] Clear synced local data

## 12. Notes

- Remote remains the primary read path for the rest of the app.
- Local data is a write buffer, not the main canonical store.
- The player should never write Supabase on every 0.25-second tick.
- The migration flow is reused for login/session restore so the app does not need a separate “sync everything now” code path.
