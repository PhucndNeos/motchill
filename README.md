# Motchill MVP

## Start Here

For the current app and playback investigation, read:

- [`HANDOFF_PLAYER_DEBUG.md`](./HANDOFF_PLAYER_DEBUG.md)

That file contains:
- the current `mobile-api-base` app architecture
- the current playback flow for direct streams and embed sources
- verified good/bad source behavior
- the latest debugging findings
- the next follow-up items for player stability

## Repository Layout

- `mobile-api-base/`: Flutter mobile app for Android/iOS that talks directly to the public Motchill API and renders the catalog, detail, search, and player screens.
- `docs/`: Specs, plans, and archived investigation notes.
- `docs/release/`: Release artifacts such as APK builds for handoff or testing.

The old `backend/` and `mobile/` split has been removed from the current codebase. Historical notes may still exist in `docs/superpowers/` for context.

## Local Development

Flutter app:

```bash
cd mobile-api-base
fvm use 3.41.6
fvm flutter pub get
fvm flutter run
```

If you are not using `fvm`, install Flutter `3.41.6` first, then run:

```bash
cd mobile-api-base
flutter pub get
flutter run
```

The app reads the public API base from `MOTCHILL_PUBLIC_API_BASE_URL` and defaults to:

- `https://motchilltv.taxi`

Override with:

```bash
flutter run --dart-define=MOTCHILL_PUBLIC_API_BASE_URL=https://your-mirror.example
```

## Key Endpoints Used By The App

- `GET /api/moviehomepage`
- `GET /api/movie/:slug`
- `GET /api/movie/preview/:slug`
- `GET /api/navbar`
- `GET /api/ads/popup`
- `GET /api/play/get?movieId=...&episodeId=...&server=...`
