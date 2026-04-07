# A MotchillTV

Flutter mobile app for the public Motchill API, built with GetX.

## What this app uses

- `GET /api/moviehomepage`
- `GET /api/movie/:slug`
- `GET /api/movie/preview/:slug`
- `GET /api/navbar`
- `GET /api/ads/popup`
- `GET /api/filter`
- `GET /api/search`
- `GET /api/play/get?movieId=...&episodeId=...&server=...`

## Architecture

- `app/`: app shell, routes, bindings
- `core/`: config, HTTP client, and local storage helpers
- `data/`: models, repositories, and API payloads
- `features/`: feature-first screens and controllers

## Feature Notes

- The search and category experience is a single screen driven by `GET /api/filter` and `GET /api/search`.
- `GET /api/search` returns encrypted payloads; the client decrypts them before mapping to models.
- Search results can also be filtered locally by `Đã thích` using cached liked movie snapshots, so favorites still appear even if the API search returns no matches.
- The search result header keeps the current count and page navigation fixed above the grid for easier paging.
- Detail content is organized into horizontal tabs, with Episodes shown first when available.
- Likes are persisted locally with `SharedPreferences` and shared between detail and search.
- `core/storage/liked_movie_store.dart` owns the local liked snapshot cache.
- Images use cached network loading to reduce scroll jank and repeated downloads.
- Launcher icons are generated from `assets/app_icon.png`.

## Stack

- Flutter
- GetX
- `http`
- `media_kit`
- `webview_flutter`

## Run

```bash
cd mobile-api-base
flutter pub get
flutter run
```

## Launcher Icons

```bash
cd mobile-api-base
dart run flutter_launcher_icons
```

This regenerates Android and iOS launcher icons from `assets/app_icon.png`.

## Notes

- The app talks directly to `https://motchilltv.taxi` by default.
- Override the base URL with `MOTCHILL_PUBLIC_API_BASE_URL` if you need a mirror or test host.
- The Android build currently supports API 24+ (Android 7.0 and newer) through Flutter's default `minSdk`.
- Direct stream sources play inline with `media_kit`.
- Embed sources open in `webview_flutter` on Android/iOS with browser-like headers when needed.
- Display name on both Android and iOS is `A MotchillTV`.
