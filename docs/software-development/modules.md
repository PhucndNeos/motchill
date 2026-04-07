# Module và Màn Hình

## 1. Home

### Screen Name

- `HomeView`

### Purpose

- Hiển thị home feed theo section.
- Đưa người dùng vào tìm kiếm, liked-only search, và detail screen.

### State Management

- `HomeController.sections`
- `HomeController.popupAd`
- `HomeController.isLoading`
- `HomeController.errorMessage`
- `_selectedIndex` trong `HomeView` để chọn hero movie

### User Actions

- Refresh home feed.
- Chọn movie trong hero carousel.
- Mở `SearchView`.
- Mở search chế độ liked-only.
- Mở `DetailView` từ movie card.

### Business Logic

- Tách section `slide` làm hero section.
- Các section còn lại render thành rail/list.
- Hero preview list loại bỏ movie đang chọn.
- Nút `Favorite` route sang search với `likedOnly=true`.
- `Xem tất cả` từ section được map thành search context dựa trên slug của section.

### API Integration

- `GET /api/moviehomepage`
- `GET /api/ads/popup`

## 2. Search and Category

### Screen Name

- `SearchView`
- `CategoryView` chỉ là wrapper dùng lại `SearchView`

### Purpose

- Tìm kiếm phim và lọc theo facet.
- Dùng chung cho search global và category entry.

### State Management

- `SearchController.results`
- `SearchController.filters`
- `SearchController.searchText`
- `SearchController.searchInputValue`
- `SearchController.selectedCategoryId` / `selectedCategoryLabel`
- `SearchController.selectedCountryId` / `selectedCountryLabel`
- `SearchController.selectedTypeRaw` / `selectedTypeLabel`
- `SearchController.selectedYear`
- `SearchController.selectedOrderBy`
- `SearchController.showLikedOnly`
- `SearchController.likedMovies`
- `SearchController.likedMovieIds`
- `SearchController.isLoading`
- `SearchController.isSearching`
- `SearchController.errorMessage`

### User Actions

- Gõ keyword và submit search.
- Mở bottom sheet để chọn category, country, type, year, order.
- Clear từng filter.
- Toggle liked-only.
- Chuyển page trước/sau.
- Pull-to-refresh.

### Business Logic

- Search screen khởi tạo từ route params:
  - `q`
  - `slug`
  - `likedOnly`
  - `favorite`
  - `mode=favorite`
- `likedOnly` ưu tiên nội dung đã lưu local, kể cả khi API search trả về rỗng.
- `screenSubtitle` tổng hợp trạng thái keyword + filter + liked-only để người dùng nhìn nhanh context hiện tại.
- `_applyPresetCategory` map slug của route sang facet category tương ứng.
- `_matchesQuery` filter local trên title, subtitle, description, status, và link.

### API Integration

- `GET /api/filter`
- `GET /api/search`

## 3. Detail

### Screen Name

- `DetailView`

### Purpose

- Hiển thị thông tin chi tiết một phim.
- Cho người dùng xem trailer, đọc synopsis, xem episode list, gallery, related items.
- Cho phép like/unlike nội dung.

### State Management

- `DetailController.detail`
- `DetailController.selectedTab`
- `DetailController.isLoading`
- `DetailController.errorMessage`
- `DetailController.isLiked`

### User Actions

- Back.
- Toggle like.
- Play episode đầu tiên từ hero section.
- Open trailer.
- Jump sang tab Information từ nút `Chi tiết`.
- Chọn tab bất kỳ trong strip.

### Business Logic

- Tab list được xây động từ dữ liệu thực tế:
  - Episodes
  - Synopsis
  - Information
  - Classification
  - Gallery
  - Related
- Default tab ưu tiên `Episodes` nếu có.
- Nút trailer mở browser ngoài app.
- Like toggle lưu snapshot movie vào local store để dùng lại ở search liked-only.

### API Integration

- `GET /api/movie/:slug`

## 4. Player

### Screen Name

- `PlayerView`

### Purpose

- Phát episode bằng source list từ API.
- Hỗ trợ stream trực tiếp và embedded webview.
- Lưu/resume playback position.

### State Management

- `PlayerController.sources`
- `PlayerController.selectedIndex`
- `PlayerController.isLoading`
- `PlayerController.errorMessage`
- `_PlayerFrame` giữ:
  - `_position`
  - `_duration`
  - `_isPlaying`
  - `_controlsVisible`
  - `_selectedAudioTrack`
  - `_selectedSubtitleTrack`
  - stream controller lifecycle

### User Actions

- Chọn source khác.
- Play/pause.
- Seek ±10 giây.
- Drag progress slider.
- Chọn audio track.
- Chọn subtitle track.
- Back ra detail hoặc màn trước.

### Business Logic

- Source `isFrame=true` sẽ mở bằng webview trên Android/iOS.
- Source stream trực tiếp sẽ phát bằng `media_kit`.
- Player tự restore vị trí từ `PlaybackPositionStore`.
- Vị trí được persist định kỳ và khi đổi source / pause / dispose.
- Player chuyển sang landscape và bật immersive mode khi vào màn hình.
- Controls auto-hide sau vài giây không tương tác.

### API Integration

- `GET /api/play/get?movieId=...&episodeId=...&server=...`

## 5. Core Shared Modules

### Network

- `MotchillApiClient` là lớp HTTP wrapper chính.
- Có timeout 20 giây và chung header `User-Agent`.

### Security

- `MotchillEncryptedPayloadCipher` giải mã payload encrypted kiểu OpenSSL `Salted__`.
- `MotchillPlayCipher` decode list source từ payload play.

### Storage

- `LikedMovieStore` lưu list movie đã thích và movie ids.
- `PlaybackPositionStore` lưu vị trí xem theo key `player_position:<movieId>:<episodeId>`.

### Widgets

- `MotchillNetworkImage` quản lý cache và placeholder cho ảnh.
- `TvFocusable` chuẩn hóa focus/hover/keyboard cho giao diện TV/remote.

