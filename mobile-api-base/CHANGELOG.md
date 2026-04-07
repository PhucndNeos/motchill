# Changelog

All notable changes to this project are documented here.

## Unreleased

### Added

- Combined category/search screen driven by `GET /api/filter` and `GET /api/search`.
- Search query and filter paging support with encrypted search payload decryption.
- Local liked-movie persistence plus liked-only filtering on search results.
- Liked favorites now use cached movie snapshots so they still appear when the API search returns nothing.
- Tabbed detail content with episodes-first ordering and a local like toggle.
- Cached network images for home, detail, and search screens.
- Launcher icon generation from `assets/app_icon.png` for Android and iOS.
- App display name updated to `A MotchillTV` on both platforms.

### Changed

- Direct stream playback now uses `media_kit` so Android TV can fall back to libmpv instead of ExoPlayer.
- Hero images now prefer full-size banner/backdrop art before falling back to thumbnails.
- Trailer buttons now open the trailer URL in the external browser.
- The detail `Chi tiết` action now jumps to `Information` when that tab exists.
- Home, detail, and search images now use a release-safe custom cache manager instead of the default `CachedNetworkImage` storage path.
- Android release manifest now includes `INTERNET`, so the installed APK can reach the API endpoints.
- Category entry now opens the unified search screen instead of filtering the home feed.
- Home hero filter and rail `Xem tất cả` actions now route into contextual search presets.
- Detail app bar now keeps only back and like actions.
- Search title is fixed to `Tìm kiếm phim`, with subtitle reflecting current query and filters.
- Search results now support a local liked-only filter without refetching the API payload.
- Search result count and page navigation are fixed above the grid for easier paging.
- Video player expand/collapse keeps playback position in sync and resume cache persists by movie/episode.
