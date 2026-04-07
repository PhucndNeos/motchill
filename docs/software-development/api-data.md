# API, Dữ Liệu và Lưu Trữ

## 1. API Endpoints

- `GET /api/moviehomepage`
- `GET /api/movie/:slug`
- `GET /api/movie/preview/:slug`
- `GET /api/navbar`
- `GET /api/ads/popup`
- `GET /api/filter`
- `GET /api/search`
- `GET /api/play/get?movieId=...&episodeId=...&server=...`

## 2. Request Behavior

- Base URL lấy từ `MOTCHILL_PUBLIC_API_BASE_URL`, mặc định là `https://motchilltv.taxi`.
- Mỗi request dùng timeout 20 giây.
- Header mặc định mô phỏng browser client nhẹ.

## 3. Encrypted Payloads

- Search results trả về payload đã mã hóa.
- Play sources cũng trả về payload đã mã hóa.
- Cipher dùng AES-CBC với header `Salted__` và passphrase cố định trong code hiện tại.

Chi tiết về nguồn gốc passphrase và quy trình truy hồi khi upstream đổi key nằm trong [Giải mã payload và phục hồi key](security-decryption.md).

## 4. Data Models

### Home / Catalog

- `HomeSection`
- `MovieCard`
- `NavbarItem`
- `PopupAdConfig`
- `SimpleLabel`
- `MovieEpisode`
- `MovieDetail`

### Search

- `SearchFacetOption`
- `SearchFilterData`
- `SearchChoice`
- `SearchPagination`
- `SearchResults`

### Playback

- `PlaySource`
- `PlayTrack`

## 5. Local Storage

### Liked Movies

- Key: `liked_movie_cards`
- Key: `liked_movie_ids`
- Store có thể giữ full snapshot `MovieCard` để search liked-only vẫn hiển thị khi API search trả rỗng.

### Playback Resume

- Key format: `player_position:<movieId>:<episodeId>`
- Lưu `Duration.inMilliseconds`
- Dùng để resume vị trí phát cho từng episode riêng biệt

## 6. Business Rules

- Search liked-only ưu tiên local cache thay vì API.
- Category route `/category/:slug` được map sang preset filter.
- Detail screen ưu tiên tab Episodes nếu có.
- `displayBackdrop` của movie detail ưu tiên banner, rồi avatar, rồi fallback thumb.
- `displayTitle` và `displaySubtitle` fallback an toàn để UI không bị trống.
