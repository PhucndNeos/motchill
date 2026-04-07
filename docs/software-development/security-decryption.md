# Giải Mã Payload Và Phục Hồi Key

Tài liệu này gom toàn bộ phần liên quan đến encrypted payload của Motchill: cách app đang giải mã, nguồn gốc key hiện tại, và quy trình thực hành để lấy lại key khi webversion thay đổi.

## 1. App đang giải mã gì?

Trong app hiện tại có 2 lớp payload được mã hóa:

- `/api/search`: trả về ciphertext, sau đó được decrypt rồi mới parse sang `SearchResults`
- `/api/play/get`: trả về payload nguồn phát, sau đó được decrypt rồi parse sang `PlaySource`

Hai lớp này dùng cùng một mẫu kỹ thuật:

- base64 payload
- header `Salted__`
- AES-CBC
- key/iv được dẫn xuất từ passphrase bằng hàm kiểu OpenSSL `EVP_BytesToKey`

## 2. Key hiện tại đến từ đâu?

`mobile-api-base/lib/core/security/motchill_encrypted_payload_cipher.dart` đang hard-code passphrase:

```dart
static const passphrase = 'sB7hP!c9X3@rVn\$5mGqT1eLzK!fU8dA2';
```

Đây không phải key “phát minh từ app mobile” mà là key đã được suy ra từ webversion/Nuxt bundle của Motchill. Các tài liệu discovery liên quan:

- `docs/superpowers/specs/2026-04-08-motchill-category-search-data-discovery.md`
- `docs/superpowers/specs/2026-04-08-motchill-api-reference.md`

Trong các tài liệu đó, pattern quan trọng là:

- response thô của endpoint không phải JSON thuần
- bundle webversion có helper decrypt
- helper này decrypt ciphertext rồi `JSON.parse(...)`

## 3. Dấu hiệu nhận biết đúng luồng

Khi kiểm tra payload gốc, nếu response bắt đầu bằng `U2FsdGVkX1...` thì đó là dấu hiệu rất mạnh rằng:

- payload đang theo định dạng OpenSSL salted
- client phải decrypt trước khi parse JSON

Trên webversion, logic tương ứng thường sẽ có các mảnh sau:

- `AES.decrypt(...)`
- `CryptoJS.enc.Utf8`
- `JSON.parse(...)`

## 4. Cách lấy lại key từ webversion

Đây là quy trình mình khuyên dùng nếu upstream đổi key hoặc đổi format:

### Bước 1: Xác định đúng trang webversion đang dùng dữ liệu đó

Mở category/search page hoặc page có play source trong webversion, rồi xác nhận request nào đang trả ciphertext.

Bạn cần nhìn 2 thứ:

- URL endpoint gốc
- response body thô có bắt đầu bằng `U2FsdGVkX1...` hay không

### Bước 2: Lấy bundle JS của webversion

Tìm file bundle/chunk mà Nuxt đang tải cho page đó. Cách thường làm:

- mở DevTools
- vào tab Network
- reload page
- lọc theo `js`
- tìm các chunk có liên quan đến search, player, hoặc util/helpers

Nếu bundle có source map, đó là đường ngắn nhất. Nếu không, vẫn có thể tìm trong bundle minified bằng search text.

### Bước 3: Tìm helper decrypt trong bundle

Tìm các chuỗi đặc trưng:

- `AES.decrypt`
- `CryptoJS`
- `Salted__`
- `JSON.parse`
- `Utf8`

Khi tìm thấy helper, kiểm tra xem nó:

- nhận ciphertext base64
- tách header/salt
- derive key/iv
- decrypt ra text JSON

Nếu helper có hard-coded secret, đây là nơi key thường nằm.

### Bước 4: Lấy passphrase hoặc derive nó từ code webversion

Có 2 trường hợp:

#### Trường hợp A: passphrase xuất hiện trực tiếp

Nếu bundle có chuỗi string secret rõ ràng, copy lại chuỗi đó và đối chiếu với `MotchillEncryptedPayloadCipher.passphrase`.

#### Trường hợp B: passphrase bị ghép hoặc obfuscate

Khi đó:

- tìm các hằng string quanh helper decrypt
- tìm module import của `crypto-js` hoặc helper nội bộ
- xem có biến nào được truyền vào `AES.decrypt(...)`
- tìm toàn bộ nơi biến đó được khai báo để lần ra giá trị cuối cùng

### Bước 5: Xác nhận key bằng test cục bộ

Sau khi có ứng viên passphrase, dùng test hiện có để xác nhận:

- `mobile-api-base/test/play_cipher_test.dart`

Test này mô phỏng đúng kiểu `Salted__` và AES-CBC, nên nếu key sai thì test sẽ fail ngay.

### Bước 6: Chốt key mới và cập nhật runtime

Khi xác nhận passphrase mới:

- cập nhật `motchill_encrypted_payload_cipher.dart`
- cập nhật `motchill_play_cipher.dart` nếu payload play có schema mới
- cập nhật test để lock lại key/format
- ghi chú lại nguồn trong docs discovery nếu cần trace về sau

## 5. Khi nào biết key đã đổi?

Các dấu hiệu hay gặp:

- `/api/search` hoặc `/api/play/get` không còn trả base64 salted theo pattern cũ
- app parse ra `FormatException`
- test decrypt/cipher bắt đầu fail
- webversion vẫn chạy nhưng app mobile không còn đọc được payload

Khi đó không nên đoán mò. Hãy quay lại webversion bundle và lặp lại quy trình trên.

## 6. Ảnh hưởng kiến trúc

Passphrase này là một technical dependency nhạy cảm:

- nó nằm trong client
- nó phụ thuộc webversion upstream
- khi đổi key, app cần một vòng research mới

Vì vậy, tốt nhất là coi tài liệu này như runbook nội bộ cho maintenance, không phải chỉ là ghi chú một lần.

