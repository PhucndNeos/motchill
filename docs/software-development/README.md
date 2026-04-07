# Motchill Mobile API Base - Software Development Docs

Tài liệu này mô tả app Flutter `mobile-api-base` theo góc nhìn phát triển phần mềm: kiến trúc, module, API, dữ liệu, và luồng điều hướng.

## Tài liệu con

- [Kiến trúc hệ thống](architecture.md)
- [Module và màn hình](modules.md)
- [API, dữ liệu và lưu trữ](api-data.md)
- [Giải mã payload và phục hồi key](security-decryption.md)
- [Điều hướng và flow](navigation.md)

## Mục tiêu của app

- Truy cập nội dung phim từ public Motchill API.
- Hiển thị home feed, tìm kiếm, lọc theo thể loại/quốc gia/năm/kiểu phim.
- Xem chi tiết phim, theo dõi tập, trailer, related movies.
- Phát video bằng `media_kit` cho stream trực tiếp và `webview_flutter` cho nguồn nhúng.
- Lưu liked movies và vị trí xem dở dang bằng `SharedPreferences`.
