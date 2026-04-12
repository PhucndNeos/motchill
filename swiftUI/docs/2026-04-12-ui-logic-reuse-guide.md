# UI and Logic Reuse Guide

Updated: 2026-04-12

## Why this exists

Mục tiêu là giảm code trùng giữa Home, Detail, Player và tránh phát sinh component mới khi có thể reuse.

Quy tắc mặc định:

1. Ưu tiên tìm trong `swiftUI/Features/SharedUI` (UI).
2. Ưu tiên tìm trong `swiftUI/Features/Common` (logic/helper).
3. Chỉ tạo mới nếu không có thành phần phù hợp hoặc thay đổi semantics thật sự khác.

## Source of truth

- UI shared: `swiftUI/Features/SharedUI`
- Logic shared: `swiftUI/Features/Common`

## Shared UI catalog

### State overlays

- `FeatureStateOverlay`: wrapper chuẩn cho loading/empty/error của feature screen.
- `ErrorOverlay`: canvas hiển thị chính, có icon theo trạng thái (`generic`, `network`, `server`, `playback`, `loading`) và loading indicator cho nút retry.
- `FeatureOverlayDescriptor` (ở Common): model hóa nội dung overlay để screen không cần lặp setup UI.

Áp dụng:

- Home: loading/empty/error
- Detail: idle/loading/empty/error
- Player: idle/loading/empty/error

### Actions / Buttons

- `FeaturePrimaryAction`: chuẩn cho CTA chính (Watch Now).
- `FeatureSecondaryAction`: chuẩn cho action phụ (Trailer và các action phụ tương tự).

Quy tắc:

- Không tự style lại nút watch/trailer trong từng màn nếu cùng vai trò UX.
- Nếu cần variant mới, mở rộng component shared thay vì copy style inline.

### Metadata pills

- `FeatureMetaPill`: pill có phân loại màu theo ngữ nghĩa (`year`, `rating`, `quality`, `status`, `views`, `episodes`, `duration`, `generic`).

Quy tắc:

- Mọi chip metadata ngắn nên đi qua `FeatureMetaPill` để giữ đồng bộ màu và typography.

### Cards and list items

- `MovieCardView`: card poster + rating + title/subtitle cho movie collection.

Quy tắc:

- Home section list và related movies ở Detail dùng cùng `MovieCardView`.
- Tránh tạo card mới nếu chỉ khác spacing/padding bên ngoài.

### Wrapping layout

- `FlowWrapLayout`: wrapper dùng `HFlow` để wrap chips/tags.

Quy tắc:

- Không dùng lại `WrapGrid` cũ.
- Không dùng trực tiếp `HFlow` ở feature screen trừ khi có lý do rõ ràng; ưu tiên `FlowWrapLayout` để thống nhất API.

### Segmented / thumbnail selection

- `TabSegmentedView`: control chọn item dạng horizontal segmented/thumbnail.

Áp dụng:

- Home chọn section
- Home iPad chọn hero movie
- Player chọn source list

## Shared logic catalog

### View actions

- `FeatureViewActions.makeAsyncAction`: chuẩn hóa async action cho button callback.
- `FeatureViewActions.openExternalURL`: mở trailer/link ngoài, xử lý normalize URL an toàn.

### Episode presentation

- `EpisodePresentation.episodeSecondaryText`: subtitle episode có metadata + trạng thái xem (`Chưa xem`, `Đã xem xong`, `Đã xem xx/yy`).
- `EpisodePresentation.shouldShowEpisodeProgressBar`: điều kiện hiển thị progress bar.

## Reuse checklist before adding new code

1. Search nhanh bằng `rg` trong `swiftUI/Features/SharedUI` và `swiftUI/Features/Common`.
2. Nếu component hiện có cover >= 80% nhu cầu, mở rộng component shared.
3. Nếu chỉ khác text/data, giữ nguyên component và truyền param.
4. Nếu cần component mới, ghi rõ lý do không thể reuse trong PR description.
5. Khi merge component mới, cập nhật tài liệu này.

## Current alignment status

- Home và Detail đã đồng bộ action buttons (`FeaturePrimaryAction` + `FeatureSecondaryAction`).
- Overlay states đã dùng cùng hệ `FeatureStateOverlay` + `FeatureOverlayDescriptor`.
- Flow layout đã chuẩn hóa qua `FlowWrapLayout`.
- Movie list card đã gom về `MovieCardView`.
- Episode subtitle/progress đã chuyển về logic chung trong `EpisodePresentation`.

## Naming and placement conventions

- Reusable UI component: đặt trong `SharedUI`, tên bắt đầu bằng `Feature...` khi có semantics cross-feature.
- Reusable domain/presentation helper: đặt trong `Common`.
- Feature-specific view model/state không đặt ở thư mục shared.

