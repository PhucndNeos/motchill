# Motchill Detail Page Design

> Mục tiêu của trang detail là hiển thị đầy đủ thông tin thật từ API `GET /api/movie/:slug`, không cắt nhóm dữ liệu nào đang có trong `MovieDetail`.

## Mục tiêu

- Dùng dữ liệu thật từ `MovieDetail` làm nguồn hiển thị chính.
- Giữ trải nghiệm đọc rõ ràng trên mobile, nhưng vẫn đủ “cinematic” để khớp với phong cách home hiện tại.
- Render đầy đủ các nhóm dữ liệu sẵn có:
  - banner / ảnh
  - title / other name
  - metadata cơ bản
  - mô tả
  - countries
  - categories
  - episodes
  - related movies
  - photos / preview photos nếu API trả về
  - các trường phụ như `ShowTimes`, `MoreInfo`, `StatusRaw`, `StatusTMText`, `Director`, `CastString`, `Trailer` nếu có dữ liệu

## Nguồn dữ liệu

- `DetailController.load()` đang gọi `MotchillRepository.loadDetail(slug)`.
- `MovieDetail` hiện có các nhóm dữ liệu chính:
  - `movie`
  - `relatedMovies`
  - `countries`
  - `categories`
  - `episodes`
  - `photoUrls`
  - `previewPhotos`
  - nhiều getter phụ từ `movie` như `ratePoint`, `viewNumber`, `quality`, `time`, `director`, `castString`, `showTimes`, `moreInfo`, `statusRaw`, `statusText`, `trailer`
- Thiết kế mới sẽ chỉ dựa trên những gì model đã có, không thêm contract giả.

## Kiến trúc

Trang detail sẽ được tách thành 3 lớp rõ ràng:

1. `DetailController`
   - Giữ nhiệm vụ fetch dữ liệu và expose trạng thái loading/error/detail.
   - Không chứa logic trình bày.

2. `DetailView`
   - Điều phối layout tổng thể.
   - Chia các khối thông tin thành sliver/section độc lập.
   - Quyết định section nào xuất hiện dựa trên việc dữ liệu có rỗng hay không.

3. Các section con
   - Mỗi section chỉ chịu trách nhiệm một nhóm dữ liệu:
     - hero banner
     - action row
     - summary metadata
     - description
     - info grid
     - countries/categories chips
     - episodes list
     - photo gallery
     - related rail
   - Mục tiêu là mỗi section có thể đọc riêng, test riêng, và ẩn mềm nếu data trống.

## Bố cục

### 1. Hero

- Dùng `bannerThumb` trước, fallback sang `banner`.
- Hero có:
  - ảnh nền lớn
  - title
  - `otherName`
  - năm phát hành
  - rating / view count / runtime / quality nếu có
  - CTA xem phim hoặc mở trailer nếu API có `Trailer`
- Phần hero phải ưu tiên data thật, không dùng placeholder text cố định ngoài các fallback như `N/A` hoặc `Chưa có`.

### 2. Summary metadata

- Hiển thị các chip / pill cho:
  - `quality`
  - `statusTitle`
  - `statusRaw`
  - `statusText`
  - `year`
  - `episodesTotal`
  - `ratePoint`
  - `viewNumber`
  - `time`
- Các chip chỉ hiện khi field tương ứng có giá trị.

### 3. Mô tả và thông tin phụ

- Một section mô tả chính từ `description`.
- Một section thông tin phụ lấy từ:
  - `director`
  - `castString`
  - `showTimes`
  - `moreInfo`
  - `trailer`
- Nếu API có dữ liệu dài, section phải dùng layout đọc được trên mobile, tránh nhồi một khối text quá dày.

### 4. Countries và categories

- Render chip list cho `countries` và `categories`.
- Nếu có nhiều item, cho phép wrap nhiều dòng.
- Các chip này chỉ là display, không cần filter navigation ở phase này.

### 5. Episodes

- Render danh sách tập từ `episodes`.
- Mỗi item hiển thị:
  - `episode.label`
  - `type`
  - trạng thái nếu có thể suy ra từ `status`
- Nếu tương lai cần phát video, đây là nơi nối action mở player.
- Hiện tại ưu tiên hiển thị đầy đủ và ổn định trước.

### 6. Photos / preview photos

- Nếu `photoUrls` hoặc `previewPhotos` có dữ liệu:
  - render thành horizontal gallery
  - mỗi ảnh có thể chạm để phóng to trong phase sau
- Nếu không có ảnh, section này ẩn hoàn toàn.

### 7. Related movies

- Render `relatedMovies` thành rail ngang như home.
- Card dùng poster + title + year / subtitle tối thiểu.
- Khi tap card, điều hướng sang detail của phim liên quan.

## Hành vi tải dữ liệu

- Khi mở detail screen:
  - show loading nếu chưa có `detail`
  - show error state nếu load fail và chưa có data
  - show content ngay khi `detail` có dữ liệu, kể cả nếu một vài group trống
- Không chặn UI chỉ vì một section thiếu dữ liệu.
- Nếu API trả về một phần nội dung, phần đó vẫn render bình thường.

## Error handling

- Nếu `loadDetail(slug)` thất bại:
  - giữ error state hiện tại
  - cho phép retry bằng nút reload
- Nếu một group con không có data:
  - section đó tự ẩn
  - không làm hỏng các section khác
- Nếu `slug` trống:
  - detail controller vẫn được khởi tạo
  - màn hình nên hiển thị error/fallback rõ ràng thay vì crash

## Data flow

1. User tap một movie từ home hoặc category.
2. `Get.toNamed('/detail/:slug')` truyền slug vào route.
3. `DetailBinding` lấy `Get.parameters['slug']` và tạo `DetailController`.
4. `DetailController.load()` gọi repository.
5. `DetailView` quan sát `detail`, `isLoading`, `errorMessage`.
6. View dựng hero và các section con từ object `MovieDetail`.

## Testing

### Widget tests

- Test loading state khi chưa có dữ liệu.
- Test error state khi repository throw.
- Test render content khi `MovieDetail` có dữ liệu đầy đủ.
- Test rằng các section trống bị ẩn mềm.
- Test navigation từ related movie hoặc CTA nếu có action.

### Data tests

- Có thể bổ sung test model nếu cần xác nhận parse đúng các field phụ:
  - `ratePoint`
  - `viewNumber`
  - `photoUrls`
  - `previewPhotos`
  - `episodes`

## Phạm vi không làm ở phase này

- Không thêm API mới.
- Không thêm trạng thái watch history / favorites thật nếu backend chưa hỗ trợ.
- Không triển khai player flow hoàn chỉnh ở detail, trừ các nút điều hướng cần thiết.
- Không cố mô phỏng 1:1 mockup nếu nó làm mất dữ liệu thật từ API.

## Tiêu chí hoàn thành

- Detail screen hiển thị được đầy đủ các nhóm dữ liệu thật từ `MovieDetail`.
- Không crash khi một hoặc nhiều field rỗng.
- Điều hướng từ home/category sang detail hoạt động.
- Test widget và data chính đều pass.
