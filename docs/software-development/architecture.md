# Kiến trúc hệ thống

## 1. Technical Overview

### Tech Stack

- Flutter / Dart 3.11+
- GetX cho routing, binding, controller và reactive state
- `http` cho API client
- `media_kit` và `media_kit_video` cho direct stream playback
- `webview_flutter` cho embedded player sources
- `cached_network_image` + custom cache manager cho ảnh
- `shared_preferences` cho liked movies và playback resume
- `url_launcher` cho trailer và browser handoff

### Architecture

App được tổ chức theo hướng feature-first, kết hợp state-driven UI của GetX:

- `app/` chứa bootstrap, route table, và binding global.
- `core/` chứa network, security, storage, widget dùng chung, và config.
- `data/` chứa models và repository.
- `features/` chứa màn hình và controller theo từng domain.

Luồng phụ thuộc chính:

`UI View -> GetX Controller -> Repository -> ApiClient / Security / Storage`

### State Management Pattern

- Mỗi màn hình có `GetxController` riêng.
- View đọc state qua `Obx`.
- Binding inject dependency bằng `Get.lazyPut` hoặc `Get.put`.
- `InitialBinding` đăng ký singleton dùng chung:
  - `http.Client`
  - `MotchillApiClient`
  - `MotchillRepository`
  - `LikedMovieStore`
  - `PlaybackPositionStore`

### Security Notes

- `MotchillEncryptedPayloadCipher` và `MotchillPlayCipher` xử lý payload mã hóa theo kiểu OpenSSL `Salted__`.
- Passphrase giải mã hiện đang hard-code trong client và được suy ra từ webversion/Nuxt bundle.
- Nếu upstream đổi key hoặc đổi cách mã hóa, xem runbook trong [Giải mã payload và phục hồi key](security-decryption.md).

### UI/UX Conventions

- Theme dark mode, Material 3.
- Focus traversal tối ưu cho TV/remote bằng `TvFocusable`.
- Ảnh dùng placeholder và cache riêng để giảm jank khi scroll.
- Player screen mặc định landscape và giữ màn hình sáng trong lúc xem.

### CI/CD & Quality

- Không thấy cấu hình CI/CD riêng như `.github/workflows`, Jenkins, hay SonarQube trong lần scan hiện tại.
- Dự án có test suite khá đầy đủ cho:
  - search controller
  - detail controller
  - player playback store
  - liked movie store
  - model parsing
  - view behavior

## 2. Dependency Graph

- `app/app.dart` dựng `GetMaterialApp`, theme, routes, và `InitialBinding`.
- `core/network/motchill_api_client.dart` gọi HTTP endpoints và parse JSON/encrypted payload.
- `core/security/*` giải mã payload cho search và play.
- `core/storage/*` lưu liked movies và playback position.
- `data/repositories/motchill_repository.dart` là lớp facade cho toàn bộ data source.
- `features/*_controller.dart` giữ state và business logic.
- `features/*_view.dart` render UI và điều hướng.
