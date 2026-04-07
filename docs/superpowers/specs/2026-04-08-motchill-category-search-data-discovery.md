# Motchill Category and Search Data Discovery

> Tài liệu này ghi lại nguồn dữ liệu thật của category/search trên webversion Motchill, vì đây là nền tảng cho việc xây dựng category controller, search screen và các luồng filter trong app mobile sau này.

## Tóm tắt ngắn

- `CategoryView` trong app hiện tại đang đi sai nguồn: nó lấy dữ liệu từ `HomeController.loadHome()` rồi lọc lại ở client.
- Webversion không render category từ `home` data của mobile app.
- Webversion dùng một luồng riêng:
  - `GET /api/filter` để lấy danh sách category/country cho bộ lọc
  - `GET /api/search` để lấy danh sách phim theo category/country/type/year/order/search/page
- Response của `/api/search` không phải JSON thuần. Nó trả về chuỗi mã hóa kiểu `U2FsdGVkX1...`, và frontend Nuxt decrypt trước khi render.
- Điều này có nghĩa là search feature sau này không nên build dựa trên `HomeController`, mà phải có một nguồn dữ liệu/filter riêng và một lớp giải mã/chuẩn hóa riêng.

## Phạm vi của tài liệu

Tài liệu này tập trung vào 4 câu hỏi:

1. Data category/search của webversion thực sự đi ra từ đâu?
2. Response shape và luồng xử lý của webversion là gì?
3. App mobile hiện tại đang thiếu gì so với webversion?
4. Search feature tương lai nên dựa trên kiến trúc nào để không phải refactor lại lần nữa?

## Bối cảnh hiện tại trong app

### `CategoryView` đang dùng sai nguồn

File: [mobile-api-base/lib/features/category/category_view.dart](/Users/phucnd/Documents/motchill/mobile-api-base/lib/features/category/category_view.dart)

Hiện tại `CategoryView` làm các việc sau:

- `Get.find<HomeController>()`
- đọc `controller.sections`
- lọc phim bằng `_moviesForLabel(label, sections)`
- suy ra category từ home sections, thay vì gọi API riêng

Điều này tạo ra 3 vấn đề:

- category page phụ thuộc hoàn toàn vào dữ liệu home
- nếu home payload thay đổi, category page sẽ sai hoặc thiếu dữ liệu
- không thể mở rộng search/filter đúng nghĩa vì nguồn dữ liệu không đủ giàu

### Repository hiện tại chưa có contract category/search riêng

Files:
- [mobile-api-base/lib/data/repositories/motchill_repository.dart](/Users/phucnd/Documents/motchill/mobile-api-base/lib/data/repositories/motchill_repository.dart)
- [mobile-api-base/lib/core/network/motchill_api_client.dart](/Users/phucnd/Documents/motchill/mobile-api-base/lib/core/network/motchill_api_client.dart)

Hiện repository chỉ expose:

- `loadHome()`
- `loadNavbar()`
- `loadDetail(slug)`
- `loadPreview(slug)`
- `loadEpisodeSources(movieId, episodeId, server)`
- `loadPopupAd()`

Không có:

- `loadFilter()`
- `loadCategoryPage(...)`
- `searchMovies(...)`

Nghĩa là app mobile hiện chưa có contract tương ứng với luồng webversion.

## Dữ liệu thực tế từ webversion

### Webversion là Nuxt SSR

Trang Motchill webversion là Nuxt SSR. Trong HTML source của trang category có:

- `window.__NUXT__`
- `buildId`
- config của `seo-utils`
- route cụ thể như `/the-loai/hanh-dong`

Điều này cho thấy category page không chỉ là một list tĩnh, mà được render theo route và query ngay từ server.

### Route category thực tế

Các route category/country mà mình xác nhận được trên webversion:

- `/the-loai/:slug`
- `/quoc-gia/:slug`
- `/phim-moi`
- `/phim-bo`
- `/phim-le`
- `/phim-4k`

Ví dụ:

- `https://motchilltv.taxi/the-loai/hanh-dong`
- `https://motchilltv.taxi/quoc-gia/han-quoc`

### Pagination là server-driven

Category page có pagination theo query `page`, ví dụ:

- `/the-loai/hanh-dong?page=1`
- `/the-loai/hanh-dong?page=2`

Điều này quan trọng vì nó cho biết category page không chỉ là “lọc mấy section home”, mà là một search result screen có paging thật.

## Endpoint gốc của category/search

### `GET /api/filter`

Đây là endpoint lấy metadata cho bộ lọc.

Quan sát từ bundle Nuxt:

- frontend gọi trực tiếp `"$fetch('/api/filter')"`
- response được dùng để dựng danh sách:
  - `categories`
  - `countries`

Response sample đã kiểm tra bằng `curl`:

```json
{
  "categories": [
    { "Name": "Tất Cả" },
    { "Id": "1", "Name": "Hành Động", "Slug": "hanh-dong" }
  ],
  "countries": [
    { "Name": "Tất Cả" },
    { "Id": "1", "Name": "Trung Quốc", "Slug": "trung-quoc" }
  ]
}
```

#### Ý nghĩa

- Đây là nguồn canonical cho danh sách filter category/country.
- Không nên hardcode danh sách category từ home hoặc từ enum local.
- Đây là dữ liệu cần thiết để build search UI sau này.

### `GET /api/search`

Đây là endpoint lấy danh sách phim theo filter.

Quan sát từ bundle Nuxt:

- frontend gọi `"$fetch('/api/search', { query: {...} })"`
- query params thực tế gồm:
  - `categoryId`
  - `countryId`
  - `typeRaw`
  - `year`
  - `orderBy`
  - `isChieuRap`
  - `is4k`
  - `search`
  - `pageNumber`

#### Ví dụ query

```text
/api/search?categoryId=1&countryId=&typeRaw=&year=&orderBy=UpdateOn&isChieuRap=false&is4k=false&search=&pageNumber=1
```

#### Điểm bất thường nhưng rất quan trọng

Response của `/api/search` không phải JSON thuần. Khi gọi trực tiếp, server trả về một chuỗi bắt đầu bằng:

```text
U2FsdGVkX1...
```

Đây là dấu hiệu payload đã được mã hóa.

Trong bundle Nuxt mình thấy helper decrypt dùng AES:

- decrypt payload bằng `AES.decrypt(...)`
- sau đó `JSON.parse(...)`

Nói cách khác:

1. client gọi `/api/search`
2. server trả ciphertext
3. frontend Nuxt decrypt ciphertext
4. frontend mới đọc được `Records`, `Pagination`, và các field liên quan

## Giải mã payload

### Bằng chứng từ bundle

Trong bundle Nuxt có module helper decrypt. Bundle này chứa logic:

- parse ciphertext
- AES decrypt
- `toString(CryptoJS.enc.Utf8)`
- `JSON.parse`

Điều này xác nhận rằng category/search data không chỉ là HTML SSR thủ công, mà là API payload được mã hóa trước khi frontend sử dụng.

### Ý nghĩa kiến trúc

Tầng client nếu muốn gọi trực tiếp `/api/search` thì phải:

- biết cách decrypt payload
- biết key/IV hoặc schema decrypt thực tế
- normalize kết quả thành model dùng được trong app

Nếu không có lớp decrypt, gọi API sẽ chỉ nhận được ciphertext vô dụng.

## Response shape suy ra

### Từ bundle và HTML render

Mình chưa trích được JSON plain trực tiếp từ `/api/search` vì payload bị mã hóa, nhưng từ cách frontend render, có thể suy ra response sau khi decrypt có ít nhất:

- `Records`: danh sách phim
- `Pagination`:
  - `TotalRecords`
  - và các thông tin page liên quan

Trong UI Nuxt, `Records` được render thành grid card, còn `Pagination.TotalRecords` được đưa vào component paginate.

### Từ `api/filter`

`categories` và `countries` mỗi item có:

- `Id`
- `Name`
- `Slug`

### Từ `api/search`

Có thể suy ra các field filter đầu vào:

- `categoryId`
- `countryId`
- `typeRaw`
- `year`
- `orderBy`
- `search`
- `pageNumber`

Và các flag:

- `isChieuRap`
- `is4k`

## So sánh với app mobile hiện tại

### App đang có

App mobile hiện có:

- home feed từ `/api/moviehomepage`
- navbar từ `/api/navbar`
- detail từ `/api/movie/:slug`
- preview từ `/api/movie/preview/:slug`
- source phát từ `/api/play/get`

### App đang thiếu

Thiếu một lớp dữ liệu dành cho:

- category filter metadata
- category page search/pagination
- country page search/pagination
- text search
- sort/filter theo year/type/order

### Hệ quả

Nếu tiếp tục dùng `HomeController` cho category:

- category screen sẽ luôn là bản sao lọc từ home
- search screen sau này sẽ khó tái sử dụng logic
- pagination thật không có chỗ gắn
- route `category/:slug` chỉ là “lọc UI”, không phải “search page”

## Kết luận kỹ thuật

### Kết luận chắc chắn

1. Category data của webversion không đến từ `moviehomepage`.
2. Webversion có endpoint riêng cho filter: `/api/filter`.
3. Webversion có endpoint riêng cho kết quả search: `/api/search`.
4. `/api/search` trả ciphertext, và Nuxt frontend decrypt trước khi render.
5. App mobile hiện tại chưa có repository/client contract cho luồng này.

### Kết luận suy luận

Mình suy luận rằng:

- webversion dùng `api/search` làm nguồn canonical cho category pages và search pages
- `api/filter` là nguồn canonical cho danh sách category/country filter
- mobile app nên đi theo cùng mô hình đó thay vì cố bẻ `home` data thành category

## Ảnh hưởng tới tính năng search sau này

Đây là phần quan trọng nhất của tài liệu.

### Search không nên xây trên home data

Home data chỉ phù hợp cho:

- featured blocks
- trending rail
- carousel
- short rails

Home data không đủ tốt để làm:

- advanced search
- paging thật
- filter theo country/category/year/type
- sort theo update/view/year

### Search nên có contract riêng

Khi xây search sau này, app nên có:

1. `CategorySearchFilterSource`
   - lấy category/country metadata từ `/api/filter`

2. `CategorySearchRepository`
   - gọi `/api/search`
   - decrypt payload
   - normalize response

3. `CategorySearchController`
   - giữ state filter, page, loading, error
   - expose kết quả cho UI

4. `CategorySearchView`
   - render filter chips
   - render result grid
   - render pagination

### Lý do phải tách riêng

- Search/filter có vòng đời khác home
- Search/filter cần page state riêng
- Search/filter có thể đổi query liên tục
- Search/filter phải handle empty/error/loading khác home

## Hướng triển khai đề xuất

### Phase 1: Tách nguồn dữ liệu category khỏi home

- thêm API client method cho:
  - `/api/filter`
  - `/api/search`
- thêm repository riêng hoặc method riêng
- tạo controller riêng thay vì mượn `HomeController`

### Phase 2: Thêm lớp decrypt/normalize

- decode ciphertext của `/api/search`
- normalize response thành model app-side
- tái sử dụng cùng pattern với play source decrypt nếu hợp lý

### Phase 3: Dựng UI category/search đúng nghĩa

- filter bar từ `/api/filter`
- grid kết quả từ `/api/search`
- pagination theo response thật
- search text + sort + country + category + year

### Phase 4: Đồng bộ route

- `/category/:slug` không còn là “lọc home”
- route này trở thành một search result screen theo slug
- có thể mở rộng sang `/search` sau này mà không phải đập đi làm lại

## Các file liên quan cần nhớ

- [CategoryView](/Users/phucnd/Documents/motchill/mobile-api-base/lib/features/category/category_view.dart)
- [HomeController](/Users/phucnd/Documents/motchill/mobile-api-base/lib/features/home/home_controller.dart)
- [MotchillRepository](/Users/phucnd/Documents/motchill/mobile-api-base/lib/data/repositories/motchill_repository.dart)
- [MotchillApiClient](/Users/phucnd/Documents/motchill/mobile-api-base/lib/core/network/motchill_api_client.dart)
- [Motchill models](/Users/phucnd/Documents/motchill/mobile-api-base/lib/data/models/motchill_models.dart)
- [Motchill public API reference](/Users/phucnd/Documents/motchill/docs/superpowers/specs/2026-04-08-motchill-api-reference.md)

## Nguồn kiểm chứng

- [https://motchilltv.taxi/](https://motchilltv.taxi/)
- [https://motchilltv.taxi/the-loai/hanh-dong](https://motchilltv.taxi/the-loai/hanh-dong)
- [https://motchilltv.taxi/api/filter](https://motchilltv.taxi/api/filter)
- [https://motchilltv.taxi/api/search?categoryId=1&countryId=&typeRaw=&year=&orderBy=UpdateOn&isChieuRap=false&is4k=false&search=&pageNumber=1](https://motchilltv.taxi/api/search?categoryId=1&countryId=&typeRaw=&year=&orderBy=UpdateOn&isChieuRap=false&is4k=false&search=&pageNumber=1)
- [https://motchilltv.taxi/_nuxt/oiz7fik-.js](https://motchilltv.taxi/_nuxt/oiz7fik-.js)
- [https://motchilltv.taxi/_nuxt/BGKIqjMk.js](https://motchilltv.taxi/_nuxt/BGKIqjMk.js)

## Tiêu chí đúng

Tài liệu này được coi là đúng nếu người đọc có thể trả lời được các câu hỏi sau:

- Category page của webversion đang lấy data từ đâu?
- `/api/filter` và `/api/search` khác gì nhau?
- Vì sao `CategoryView` hiện tại là chưa đúng kiến trúc?
- Search feature sau này nên đặt contract nào để không phụ thuộc `HomeController`?
- Vì sao response `/api/search` cần decrypt trước khi parse?

