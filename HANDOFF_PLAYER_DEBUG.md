# Motchill Player Debug Handoff

Date: 2026-04-07

## Scope
Tài liệu này tổng hợp trạng thái điều tra player hiện tại để người khác có thể tiếp tục cải tiến luồng lấy URL stream cho mobile, nhất là các source khác nhau trên Android/iOS.

## Current Architecture

### Backend
- App mobile không gọi website gốc trực tiếp.
- App gọi backend local trung gian.
- Backend làm 3 việc chính:
  - crawl/serve catalog
  - resolve playback fresh-on-demand
  - proxy/rewrite HLS để `video_player` dùng được URL native-playable

### Flutter app
- App dùng `video_player`, không dùng WebView cho playback.
- Player screen có:
  - play/pause
  - seek
  - source picker
  - scale mode
  - landscape-only khi play
  - tap để ẩn/hiện UI

## Stream Resolution Flow

### Entry point from mobile
1. App gọi `/api/playback/:slug?server=N&fallback=1`
2. Backend lấy detail episode từ `slug`
3. Backend gọi `getPlayback(movieId, episodeId, server, { allowFallback })`
4. Backend trả:
   - `playbackKind`
   - `mediaUrl`
   - `mediaReferer`
   - `sources[]`
   - `selectedSource`
   - `streamUrl`

### Web-like source resolver
Backend có endpoint debug:
- `GET /api/source/:id`

Luồng resolve:
1. Fetch payload từ website embed/source endpoint
2. Decrypt AES-CBC payload bằng key/iv của web
3. Parse JSON payload ra:
   - `Link`
   - `Subtitle` / `SubLink`
   - `Tracks`
   - `IsFrame` / `IsIframe`
4. Normalize thành source có thể play bằng native player

### HLS handling
- Nếu source là HLS:
  - backend rewrite playlist sang `/api/hls/fetch?...`
  - segment/playlist vẫn đi qua backend proxy
- Backend đã kiểm tra segment đầu bằng curl và xác nhận trả `200` cho source tốt.

## Root Cause Findings

### 1. Không phải lỗi UI đơn thuần
Ban đầu màn player quay mãi rồi lỗi, nhưng root cause thật sự là đường stream/source, không phải chỉ là Flutter UI.

### 2. Source 0 bị fail
Trong episode đang debug:
- `Vietsub 1` fail
- `Vietsub 2` resolve được và là source đúng để play

Source 0 có thể báo tồn tại ở detail nhưng khi playback thực tế sẽ fail ở HLS/segment.

### 3. HLS proxy backend hoạt động
Đã kiểm tra bằng curl:
- playlist trả ra hợp lệ
- playlist được rewrite đúng
- segment đầu qua backend trả `200` và `video/mp2t`

### 4. State bug trong player UI
Bug đã sửa:
- source chọn fail không được làm cả màn player nhảy sang error overlay
- `_error` chỉ nên ảnh hưởng khi `LoadState.failure` thật

## Bugs Fixed During Investigation

### Playback init timeout
- `video_player.initialize()` ban đầu timeout quá ngắn
- đã tăng lên `30s`

### Error overlay logic
- `_controller.error != null` từng làm màn player báo lỗi quá sớm
- đã sửa để chỉ dựa vào `LoadState.failure`

### ATS / local networking on iOS
Đã mở trong `Info.plist`:
- `NSAllowsArbitraryLoadsInMedia = true`
- `NSAllowsLocalNetworking = true`
- `NSAllowsArbitraryLoadsInWebContent = true`

## Important Files

### Backend
- [`backend/src/motchill.js`](./backend/src/motchill.js)
- [`backend/src/server.js`](./backend/src/server.js)
- [`backend/test/web-source-resolver.test.mjs`](./backend/test/web-source-resolver.test.mjs)

### Flutter
- [`mobile/lib/src/models.dart`](./mobile/lib/src/models.dart)
- [`mobile/lib/src/api.dart`](./mobile/lib/src/api.dart)
- [`mobile/lib/src/data/motchill_repository.dart`](./mobile/lib/src/data/motchill_repository.dart)
- [`mobile/lib/src/features/player/player_controller.dart`](./mobile/lib/src/features/player/player_controller.dart)
- [`mobile/lib/src/screens/player_screen.dart`](./mobile/lib/src/screens/player_screen.dart)

### iOS config
- [`mobile/ios/Runner/Info.plist`](./mobile/ios/Runner/Info.plist)

## Verified Commands

### Backend
- `cd backend && npm test`

### Mobile
- `cd mobile && flutter analyze`
- `cd mobile && flutter test`

### Runtime / manual verification
- iPad simulator playback was verified after backend selected source 1.
- Screenshot showed video actually playing and the player overlay visible.

## Runtime State At Last Check

### Backend
- Backend was running on:
  - `http://127.0.0.1:3000`
  - `http://192.168.100.74:3000`

### iPad simulator
- Booted device:
  - `iPad Air 11-inch (M3)`
  - device id: `28A002B3-91FC-41DF-9827-D02C79D2DDD8`

### Flutter run
- A debug `flutter run` session was active during investigation and hot reload succeeded.

## What To Investigate Next

### 1. Improve source resolver for embed-only sources
Many sources still return:
- `Unable to resolve playable stream`
- `fetch failed`

These are the main remaining targets if the goal is to support more sources without WebView.

### 2. Make source scoring smarter
Right now some sources look available in detail, but fail later in playback. The backend should ideally:
- score sources earlier
- mark bad HLS sources unavailable before user taps play
- keep only truly playable source options in the picker

### 3. Reduce runtime load
Current flow is acceptable for MVP, but can be improved by:
- caching playback resolution briefly
- caching HLS manifest rewrites
- avoiding repeated upstream fetches for the same episode/source within a short window

### 4. Cross-platform parity
iOS and Android should both be tested on the same source set:
- direct HLS
- embed-derived HLS
- source-dead / unsupported

## Known Good Source Behavior
For the episode currently inspected:
- `Vietsub 2` is the source that resolves into a playable HLS URL
- the backend rewrites it through local HLS proxy correctly
- `video_player` can play it

## Known Bad Source Behavior
For the same episode:
- `Vietsub 1` fails in playback path
- some embed-only or 4K sources are still unsupported or fail to resolve
- choosing a dead source should show toast and should not replace the working controller

## Notes For Future Work
- Keep playback fresh-on-demand when Play is tapped.
- Keep catalog refresh scheduled and persistent.
- Do not reintroduce WebView fallback for playback in the mobile app unless the product direction changes.
- The most important thing now is not UI polish; it is source resolution quality and stability of the native-playable URL path.
