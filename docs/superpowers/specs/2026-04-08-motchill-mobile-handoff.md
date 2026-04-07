# Motchill Mobile Technical Handoff

> Tài liệu này tóm tắt kiến trúc hiện tại của `mobile-api-base` để người khác có thể tiếp quản nhanh mà không cần đọc toàn bộ lịch sử chat.

## What Changed

- Search/category đã được gộp thành một màn hình chung.
- Home hero filter và rail `Xem tất cả` dẫn vào search với preset theo ngữ cảnh.
- Detail screen dùng tab ngang cho synopsis, information, classification, episodes, gallery, related, và tab Episodes được ưu tiên đầu tiên.
- Like movie được lưu local qua `SharedPreferences` dưới dạng snapshot movie để dùng chung giữa detail và search.
- Search có thêm local filter `Đã thích` trên cache liked movie, nên favorite vẫn hiện ngay cả khi API search trả rỗng.
- Launcher icon và app display name đã được đổi sang `A MotchillTV`.
- Ảnh network ở các màn chính đã được chuyển sang cache để giảm tải lại và mượt hơn khi scroll.

## Search and Category Architecture

### Flow

1. Home chip hoặc route category mở vào màn search chung.
2. `SearchController` load metadata từ `GET /api/filter`.
3. Controller map slug sang `categoryId`, và giữ các filter khác ở trạng thái trống nếu không được preset.
4. Khi người dùng đổi filter hoặc search text, controller gọi `GET /api/search`.
5. Kết quả được decrypt từ payload mã hóa trước khi parse thành model.
6. Local liked filter chỉ lọc trên kết quả đã trả về, không gọi lại API.

## Detail and Likes Architecture

### Flow

1. `DetailController` load `MovieDetail` từ `GET /api/movie/:slug`.
2. Controller đọc trạng thái liked local từ `LikedMovieStore` để set icon tim.
3. Người dùng đổi tab ngang để xem synopsis, information, classification, episodes, gallery, hoặc related.
4. Khi bấm like, controller lưu id phim vào `SharedPreferences`.
5. Search screen đọc lại danh sách liked ids đó để lọc local khi bật chip `Đã thích`.

### Important Files

- [mobile-api-base/lib/features/search/search_view.dart](/Users/phucnd/Documents/motchill/mobile-api-base/lib/features/search/search_view.dart)
- [mobile-api-base/lib/features/search/search_controller.dart](/Users/phucnd/Documents/motchill/mobile-api-base/lib/features/search/search_controller.dart)
- [mobile-api-base/lib/features/detail/detail_view.dart](/Users/phucnd/Documents/motchill/mobile-api-base/lib/features/detail/detail_view.dart)
- [mobile-api-base/lib/features/detail/detail_controller.dart](/Users/phucnd/Documents/motchill/mobile-api-base/lib/features/detail/detail_controller.dart)
- [mobile-api-base/lib/core/storage/liked_movie_store.dart](/Users/phucnd/Documents/motchill/mobile-api-base/lib/core/storage/liked_movie_store.dart)
- [mobile-api-base/lib/core/network/motchill_api_client.dart](/Users/phucnd/Documents/motchill/mobile-api-base/lib/core/network/motchill_api_client.dart)
- [mobile-api-base/lib/data/repositories/motchill_repository.dart](/Users/phucnd/Documents/motchill/mobile-api-base/lib/data/repositories/motchill_repository.dart)

### API Contract

- `GET /api/filter`
  - Provides category and country filter options.
  - The first category/country entry may be `Tất cả` without a real `Id`.
- `GET /api/search`
  - Accepts `categoryId`, `countryId`, `typeRaw`, `year`, `orderBy`, `isChieuRap`, `is4k`, `search`, and `pageNumber`.
  - Returns an encrypted payload that must be decrypted client-side.
- `SharedPreferences`
  - Stores liked movie snapshots under a local key so the detail and search screens can share state without a new backend endpoint.

### Design Rules

- Screen title stays fixed as `Tìm kiếm phim`.
- Subtitle should reflect current query/filter context.
- `Loại phim`, `Năm`, `Thể loại`, `Quốc gia`, and `Sắp xếp` are picker-driven, not free text.
- `Tất cả` should clear a filter instead of sending a bogus id.
- `Đã thích` is a local-only search filter and should not trigger a new API request.
- The search header keeps result count and page navigation fixed above the grid, outside the scrolling results area.

## Image and Branding

### Launcher Icon

- Source asset: [mobile-api-base/assets/app_icon.png](/Users/phucnd/Documents/motchill/mobile-api-base/assets/app_icon.png)
- Generated via `flutter_launcher_icons`
- Android and iOS icons are generated from the same source image and allowed to crop automatically per platform defaults.

### App Name

- Android app label: `A MotchillTV`
- iOS display name: `A MotchillTV`

### Important Files

- [mobile-api-base/pubspec.yaml](/Users/phucnd/Documents/motchill/mobile-api-base/pubspec.yaml)
- [mobile-api-base/android/app/src/main/AndroidManifest.xml](/Users/phucnd/Documents/motchill/mobile-api-base/android/app/src/main/AndroidManifest.xml)
- [mobile-api-base/android/app/src/main/res/values/strings.xml](/Users/phucnd/Documents/motchill/mobile-api-base/android/app/src/main/res/values/strings.xml)
- [mobile-api-base/ios/Runner/Info.plist](/Users/phucnd/Documents/motchill/mobile-api-base/ios/Runner/Info.plist)

## Performance Notes

- Home/detail/search images use `cached_network_image`.
- Placeholders are static to avoid leaving widget tests or UI states in perpetual animation.
- Fade animations were disabled on cached images to keep the UI predictable.

## Build and Maintenance

- Regenerate launcher icons after changing `assets/app_icon.png`:

```bash
cd mobile-api-base
dart run flutter_launcher_icons
```

- Run tests before shipping changes:

```bash
cd mobile-api-base
flutter test
```

## Ownership Hints

- Search/category work lives in the `features/search` feature folder.
- Playback/resume logic lives in the `features/player` feature folder.
- Networking and payload decryption live under `core/network` and `core/security`.
- Model shape changes should be updated in `data/models` first, then wired through repositories and views.
