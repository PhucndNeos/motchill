# Motchill Player Debug Handoff

Date: 2026-04-08

## Scope

Tài liệu này ghi lại trạng thái player hiện tại của `mobile-api-base` để người khác tiếp tục debug hoặc polish mà không cần lần lại toàn bộ lịch sử thử nghiệm.

## Current Architecture

### App

- Repo hiện tại chỉ còn app Flutter `mobile-api-base`.
- App nói chuyện trực tiếp với public Motchill API, mặc định là `https://motchilltv.taxi`.
- Base URL có thể override qua `MOTCHILL_PUBLIC_API_BASE_URL`.

### Player

- Direct stream source:
  - dùng `media_kit`
  - play inline trong app
- Embed source:
  - dùng `webview_flutter` trên Android/iOS
  - load thẳng URL embed
  - set user-agent và headers kiểu browser để giảm lỗi Cloudflare / hotlink

### Source flow

1. Detail screen lấy `MovieDetail`.
2. Player gọi `GET /api/play/get?movieId=...&episodeId=...&server=...`.
3. Payload trả về được giải mã thành danh sách `PlaySource`.
4. `source.isFrame == false`:
    - vào `media_kit`
5. `source.isFrame == true`:
   - vào `WebViewWidget`

## What We Learned

- Một số embed URL mở được trong Safari/Chrome nhưng trong WebView có thể quay mãi hoặc trả `404`.
- Trường hợp này thường là do host embed / anti-bot / fingerprint, không phải do GetX hay layout.
- Log hiện tại đã được thêm ở:
  - API client
  - decrypt layer
  - player controller
  - player view

## Useful Logs

Khi debug, hãy chú ý các log sau:

- `[Motchill.player] load episode ...`
- `[Motchill.player] source payload ...`
- `[Motchill.player] selected play source ...`
- `[Motchill.player] render source mode=...`
- `[Motchill.player] init video player ...`
- `[Motchill.player] init webview player ...`
- `[Motchill.player] web resource error ...`

## Important Files

- [`mobile-api-base/lib/core/config/api_config.dart`](./mobile-api-base/lib/core/config/api_config.dart)
- [`mobile-api-base/lib/core/network/motchill_api_client.dart`](./mobile-api-base/lib/core/network/motchill_api_client.dart)
- [`mobile-api-base/lib/data/models/motchill_play_models.dart`](./mobile-api-base/lib/data/models/motchill_play_models.dart)
- [`mobile-api-base/lib/features/player/player_controller.dart`](./mobile-api-base/lib/features/player/player_controller.dart)
- [`mobile-api-base/lib/features/player/player_view.dart`](./mobile-api-base/lib/features/player/player_view.dart)
- [`mobile-api-base/lib/features/player/frame_player.dart`](./mobile-api-base/lib/features/player/frame_player.dart)
- [`mobile-api-base/lib/features/player/frame_player_stub.dart`](./mobile-api-base/lib/features/player/frame_player_stub.dart)

## Verified Commands

- `cd mobile-api-base && flutter analyze`
- `cd mobile-api-base && flutter test`

## Notes For Future Work

- Keep direct streams on `media_kit`.
- Keep embed sources on `webview_flutter` unless product direction changes.
- If a specific embed host still spins in WebView, inspect request headers and server response before changing the UI.
