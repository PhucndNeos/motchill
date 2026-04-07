# Motchill Public API Reference

> Chỉ ghi các endpoint public mình đã kiểm tra được bằng `curl`.  
> Tài liệu này phản ánh cách `mobile-api-base` đang gọi API trực tiếp, không qua backend local.

## Base URL

- `https://motchilltv.taxi`

## Ghi chú chung

- Các endpoint dưới đây đều gọi được công khai, không cần token.
- Chỉ cần thêm `User-Agent: Mozilla/5.0` là đủ trong hầu hết trường hợp.
- Một số endpoint trả về dữ liệu rất giàu, nên client có thể dùng trực tiếp thay vì tự crawl trang.

Ví dụ:

```bash
curl 'https://motchilltv.taxi/api/moviehomepage' \
  -H 'User-Agent: Mozilla/5.0'
```

---

## 1. `GET /api/moviehomepage`

- **Mục đích**: Lấy dữ liệu home page.
- **Public**: Có
- **Auth**: Không

### Response shape

Trả về một mảng section. Mỗi section có:

- `Title`: string
- `Key`: string
- `Products`: array
- `IsCarousel`: boolean

Mỗi `Products[]` item có:

- `Id`: number
- `Name`: string
- `OtherName`: string
- `Avatar`: string
- `BannerThumb`: string
- `AvatarThumb`: string
- `Description`: string
- `Banner`: string
- `ImageIcon`: string
- `Link`: string
- `Quanlity`: string
- `Rating`: string
- `Year`: number
- `StatusTitle`: string
- `Countries`: array
- `Categories`: array

Mỗi item trong `Countries` và `Categories` có:

- `Id`: number
- `Name`: string
- `Link`: string
- `DisplayColumn`: number

### Ví dụ

```bash
curl 'https://motchilltv.taxi/api/moviehomepage' \
  -H 'User-Agent: Mozilla/5.0'
```

### Ghi chú

- Đây là endpoint quan trọng nhất cho home.
- Dữ liệu đủ để render slider, block nội dung, poster, category chips, và metadata cơ bản.

---

## 2. `GET /api/movie/:slug`

- **Mục đích**: Lấy dữ liệu chi tiết phim theo `slug`.
- **Public**: Có
- **Auth**: Không

### Path params

- `slug`: ví dụ `nguyet-lan-y-ky`

### Response shape

Trả về object gồm:

- `movie`
- `relatedMovies`

### `movie` fields

Nhóm định danh và SEO:

- `Id`
- `Name`
- `OtherName`
- `Link`
- `OriginalLink`
- `SearchText`
- `SeoTitle`
- `SeoDescription`
- `SeoKeywords`
- `Keyword`

Nhóm hình ảnh và media:

- `Avatar`
- `AvatarImage`
- `AvatarImageThumb`
- `AvatarThumb`
- `Banner`
- `BannerThumb`
- `Trailer`
- `PlayUrl`
- `EpisodeTrailer`
- `Photos`
- `PreviewPhotos`

Nhóm hiển thị và trạng thái:

- `ViewNumber`
- `RatePoint`
- `RateNumner`
- `EpisodesTotal`
- `Year`
- `Time`
- `ShowTimes`
- `Quanlity`
- `StatusTitle`
- `StatusRaw`
- `StatusTMText`
- `IsPublish`
- `SyncingEnable`
- `NotPrefer4k`

Nhóm phân loại:

- `Countries`
- `Categories`
- `Tags`
- `NewTags`

Nhóm thông tin phụ:

- `Director`
- `CastString`
- `MoreInfo`
- `TypeRaw`
- `LokLokMovie`
- `OphimUrl`
- `NguoncLink`
- `MDLDrama`
- `MDLCast`

Nhóm tập phim:

- `Episodes`

### Nested `Countries` và `Categories`

Mỗi item có:

- `Id`
- `Name`
- `Link`
- `DisplayColumn`

### Nested `Episodes`

Mỗi item có:

- `Id`
- `EpisodeNumber`
- `UsingLocal`
- `SyncingComplete`
- `Status`
- `ProductId`
- `Name`
- `FullLink`
- `IsLogoEncode`
- `LogoEncodeComplete`
- `Type`
- `CreateOn`

### Nested `MDLCast`

Quan sát được cấu trúc:

- `Title`
- `Poster`
- `Casts`

`Casts` là object gồm các nhóm như:

- `Main Role`
- `Support Role`

Mỗi cast item có:

- `Name`
- `profile_image`
- `Slug`
- `role`

`role` có:

- `name`
- `type`

### `relatedMovies`

Mỗi item có:

- `Id`
- `Name`
- `OtherName`
- `Avatar`
- `Banner`
- `Link`
- `Quanlity`
- `Year`
- `StatusRaw`
- `StatusTitle`
- `AvatarImageThumb`
- `AvatarImage`
- `AvatarThumb`
- `BannerThumb`

### Ví dụ

```bash
curl 'https://motchilltv.taxi/api/movie/nguyet-lan-y-ky' \
  -H 'User-Agent: Mozilla/5.0'
```

### Ghi chú

- Endpoint này đủ giàu để thay thế crawl detail page.
- Đây là nguồn tốt nhất cho poster, mô tả, danh sách tập, thể loại, quốc gia, cast, và related list.

---

## 3. `GET /api/navbar`

- **Mục đích**: Lấy navigation tree của site.
- **Public**: Có
- **Auth**: Không

### Response shape

Trả về mảng nav item. Mỗi item top-level có:

- `Id`
- `Name`
- `Slug`
- `IsExistChild` (nếu có)
- `Items` (nếu có)

Mỗi item con trong `Items` có:

- `Id`
- `Name`
- `Slug`
- `Col`

### Ví dụ

```bash
curl 'https://motchilltv.taxi/api/navbar' \
  -H 'User-Agent: Mozilla/5.0'
```

### Ghi chú

- Dùng cho menu, dropdown thể loại, và các link điều hướng site-wide.

---

## 4. `GET /api/ads/popup`

- **Mục đích**: Lấy cấu hình popup ad.
- **Public**: Có
- **Auth**: Không

### Response shape

Trả về object có:

- `Id`
- `Name`
- `Type`
- `DesktopLink`
- `MobileLink`

### Ví dụ

```bash
curl 'https://motchilltv.taxi/api/ads/popup' \
  -H 'User-Agent: Mozilla/5.0'
```

### Ghi chú

- Endpoint này public và trả về một cấu hình quảng cáo duy nhất trong mẫu mình kiểm tra.

---

## 5. `GET /api/movie/preview/:slug`

- **Mục đích**: Lấy payload preview nhanh cho một phim.
- **Public**: Có
- **Auth**: Không

### Path params

- `slug`: ví dụ `nguyet-lan-y-ky`

### Response shape

Payload preview rất gần với detail object, và có thể gồm:

- `Id`
- `Name`
- `OtherName`
- `Avatar`
- `Description`
- `ViewNumber`
- `RatePoint`
- `RateNumner`
- `EpisodesTotal`
- `Year`
- `Director`
- `Time`
- `Trailer`
- `Link`
- `ShowTimes`
- `SearchText`
- `SeoTitle`
- `SeoDescription`
- `Keyword`
- `StatusTitle`
- `SeoKeywords`
- `OriginalLink`
- `CastString`
- `MoreInfo`
- `Quanlity`
- `SyncingEnable`
- `IsPublish`
- `TypeRaw`
- `StatusRaw`
- `Countries`
- `Categories`
- `Episodes`
- `EpisodeTrailer`
- `PlayUrl`
- `AvatarImage`
- `AvatarImageThumb`
- `Banner`
- `BannerThumb`
- `StatusTMText`
- `Tags`
- `NewTags`
- `Photos`
- `PreviewPhotos`
- `CreatedOn`
- `UpdateOn`
- `UpdateOnRaw`
- `LokLokMovie`
- `OphimUrl`
- `NguoncLink`
- `MDLDrama`
- `MDLCast`
- `NotPrefer4k`

### Ví dụ

```bash
curl 'https://motchilltv.taxi/api/movie/preview/nguyet-lan-y-ky' \
  -H 'User-Agent: Mozilla/5.0'
```

### Ghi chú

- Đây là endpoint phù hợp cho hover preview hoặc quick lookup.
- Nếu client chỉ cần metadata nhanh thì có thể dùng endpoint này thay vì detail đầy đủ.

---

## 6. `GET /api/filter`

- **Mục đích**: Lấy metadata cho bộ lọc category/country của webversion.
- **Public**: Có
- **Auth**: Không

### Response shape

Trả về object có ít nhất:

- `categories`: array
- `countries`: array

Mỗi item trong `categories` / `countries` có:

- `Name`: string
- `Id`: string hoặc rỗng cho mục "Tất Cả"
- `Slug`: string

### Ghi chú

- Đây là nguồn canonical cho danh sách category/country filter.
- `CategoryView` hiện tại trong app mobile chưa dùng endpoint này.
- Đây là endpoint nền tảng cho search/filter screen sau này.

### Ví dụ

```bash
curl 'https://motchilltv.taxi/api/filter' \
  -H 'User-Agent: Mozilla/5.0'
```

---

## 7. `GET /api/search`

- **Mục đích**: Lấy danh sách phim theo filter, order và page.
- **Public**: Có
- **Auth**: Không

### Query params

- `categoryId`
- `countryId`
- `typeRaw`
- `year`
- `orderBy`
- `isChieuRap`
- `is4k`
- `search`
- `pageNumber`

### Response shape

Response thực tế không phải JSON thuần khi gọi trực tiếp bằng `curl`.

- Server trả về một chuỗi ciphertext bắt đầu bằng `U2FsdGVkX1...`
- Frontend Nuxt decrypt payload trước khi đọc `Records` và `Pagination`

### Ghi chú

- Đây là endpoint thực thi cho category page và search page của webversion.
- App mobile muốn dùng endpoint này phải có thêm bước decrypt/normalize.
- Không nên đọc endpoint này như JSON plain.

### Ví dụ

```bash
curl 'https://motchilltv.taxi/api/search?categoryId=1&countryId=&typeRaw=&year=&orderBy=UpdateOn&isChieuRap=false&is4k=false&search=&pageNumber=1' \
  -H 'User-Agent: Mozilla/5.0'
```

### Lưu ý kỹ thuật

- Nếu response bắt đầu bằng `U2FsdGVkX1...`, đó là dấu hiệu payload đã được mã hóa.
- Frontend webversion có helper AES decrypt trước khi parse JSON.
- Khi làm client riêng cho app mobile, cần tái tạo bước này ở repository hoặc security layer.

---

## 8. `GET /api/play/get`

- **Mục đích**: Lấy payload nguồn phát cho một episode.
- **Public**: Có
- **Auth**: Không

### Query params

- `movieId`: id phim
- `episodeId`: id tập
- `server`: server index, thường là `0`

### Response shape

- Trả về một payload đã mã hóa / đóng gói.
- `mobile-api-base` giải mã payload này để lấy danh sách nguồn phát thực tế.

### Ghi chú

- Đây là endpoint mà player hiện tại dùng trước khi quyết định mở `video_player` hay `webview_flutter`.
- Với embed source, payload thường chứa một URL embed thay vì stream trực tiếp.

---

## Khuyến nghị dùng trong client

Nếu chỉ dùng các API public qua `curl`, thứ tự ưu tiên nên là:

1. `GET /api/moviehomepage` cho home
2. `GET /api/movie/:slug` cho detail
3. `GET /api/navbar` cho menu
4. `GET /api/movie/preview/:slug` cho preview nhanh
5. `GET /api/ads/popup` cho popup ad
6. `GET /api/play/get` cho danh sách nguồn phát của từng tập
