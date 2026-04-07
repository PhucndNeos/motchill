# Điều Hướng và Flow

## 1. Routes

- `/` -> `HomeView`
- `/search` -> `SearchView`
- `/category/:slug` -> `CategoryView` -> reuse `SearchView`
- `/detail/:slug` -> `DetailView`
- `/play/:movieId/:episodeId` -> `PlayerView`

## 2. Route Parameters

- Search:
  - `q`
  - `slug`
  - `likedOnly`
  - `favorite`
  - `mode=favorite`
- Detail:
  - `slug`
- Player:
  - `movieId`
  - `episodeId`
  - arguments map: `movieTitle`, `episodeLabel`

## 3. Flow Summary

```mermaid
flowchart LR
  A["Home"] --> B["Search"]
  A["Home"] --> C["Detail"]
  B["Search"] --> C["Detail"]
  C["Detail"] --> D["Player"]
  E["Category route"] --> B["Search preset category"]
  A["Favorite button"] --> B["Search likedOnly"]
  D["Player"] --> C["Back to detail"]
  C["Back"] --> A["Home or previous route"]
```

## 4. Navigation Notes

- Home hero actions:
  - `Favorite` opens search với `likedOnly=true`
  - `Tìm kiếm` opens global search
  - `Xem ngay` opens detail của movie đang chọn
- Category entry không có màn riêng, mà mở search với preset category.
- Detail screen có nút `Chi tiết` để nhảy sang tab Information nếu tab đó tồn tại.
- Player giữ source selection trong màn và cho phép đổi source ngay trong playback chrome.

