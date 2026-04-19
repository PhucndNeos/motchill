# PhimMoiChill Research Report

Updated: 2026-04-19 (final)
Target site: `https://phimmoichill.men`

## 1) Mục tiêu chính

- Tìm API để render Home.
- Tìm API Search.
- Tìm API lấy episode + playable link.
- Với endpoint trả HTML: đề xuất mapping sang JSON để app iOS/Android dùng ổn định.

---

## 2) Tóm tắt kiến trúc dữ liệu hiện tại

- Site dùng kết hợp:
  - SSR HTML (nhiều trang list/search/home render sẵn HTML).
  - AJAX trả HTML fragment.
  - Một số endpoint trả JSON (episode links, member/auth/comment, ...).
- Base config xuất hiện trong HTML:
  - `base_url = https://phimmoichill.men/`
  - `window.PM_API_URL = https://api.phimmoi.mx`

Kết luận: không có public JSON endpoint kiểu `/api/films` cho home/list/search; cần parse HTML -> JSON ở tầng app/backend proxy.

---

## 3) Home API (thực tế)

### 3.1 Home tabs (AJAX HTML)

- Endpoint: `POST /ajax/get_content_box`
- Host: `https://phimmoichill.men`
- Body: `key=<tab-key>`
- Response: HTML fragment (`<li class="item ...">...</li>`)

Ví dụ key đã verify:

- `hanh-dong`
- `hoat-hinh`
- `kinh-di`
- `hai-huoc`
- `han-quoc`
- `trung-quoc`
- `phim-my`
- `phim-bo-full`
- `chieu-rap-2022|2023|2024|2025`
- `le-thinh-hanh`
- `bo-thinh-hanh`

Example:

```bash
curl 'https://phimmoichill.men/ajax/get_content_box' \
  -X POST \
  -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
  --data 'key=hanh-dong'
```

### 3.2 List/filter (AJAX HTML)

- Endpoint: `POST /ajax/get_filter_box/`
- Host: `https://phimmoichill.men`
- Body params:
  - `cat`
  - `country`
  - `year`
  - `type`
  - `byorder`
  - `hinhthuc`
  - `page`
- Response: HTML fragment chứa list + pagination

Example:

```bash
curl 'https://phimmoichill.men/ajax/get_filter_box/' \
  -X POST \
  -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
  --data 'cat=&country=&year=&type=&byorder=&hinhthuc=&page=1'
```

### 3.3 JSON schema mục tiêu cho Home

```json
{
  "sectionKey": "hanh-dong",
  "items": [
    {
      "title": "Huyền Thoại Aang: Ngự Khí Sư Cuối Cùng",
      "originalTitle": "The Legend of Aang: The Last Airbender",
      "detailUrl": "https://phimmoichill.men/info/...",
      "posterUrl": "https://img.phimmoichill.men/images/info/....jpg",
      "label": "HD-Vietsub",
      "status": "Tập 10/12 - Vietsub",
      "badges": ["4K", "TM 3", "🔊"]
    }
  ],
  "pagination": {
    "currentPage": 1,
    "hasNext": true
  }
}
```

---

## 4) Search API (thực tế)

### 4.1 Search page URL

- Web form submit tạo URL:
  - `/tim-kiem/<keyword-normalized>/`
- `keyword` được normalize ở `global.js`:
  - lower-case
  - remove special chars
  - spaces => `+`

Ví dụ:

- `one piece` -> `https://phimmoichill.men/tim-kiem/one+piece/`

Response: full HTML page có `#binlist` chứa `<ul class="list-film horizontal">`.

### 4.2 Search + filter

- Search page cũng có hàm `loc(page)` gọi `POST /ajax/get_filter_box/`.
- Nhưng endpoint này không mang keyword trực tiếp trong body.
- Verify thực tế: gọi thẳng `/ajax/get_filter_box/` trả list filter chung, không phải dedicated JSON search.

=> Để ổn định, nên lấy search data từ chính trang `/tim-kiem/<keyword>/` rồi parse `#binlist`.

### 4.3 JSON schema mục tiêu cho Search

```json
{
  "keyword": "one piece",
  "items": [
    {
      "title": "One Piece Vua Hải Tặc",
      "detailUrl": "https://phimmoichill.men/info/one-piece-phimmoi-e1-pm4063",
      "posterUrl": "https://img.phimmoichill.men/images/info/dao-hai-tac-hai-tac-mu-rom.jpg",
      "status": "Tập 1157 - Vietsub"
    }
  ],
  "pagination": {
    "currentPage": 1,
    "nextPageUrl": null
  }
}
```

---

## 5) Episode + Playable link API

### 5.1 Episode metadata + server links (JSON)

- Endpoint: `POST /ajax/get_episode_links`
- Body: `episode_id=<id>`
- Response: JSON

Example response:

```json
{
  "success": true,
  "episode": {
    "id": "127107",
    "name": "Full",
    "filmid": "17380",
    "subtitle": "0",
    "thumb": ""
  },
  "links": [
    { "id": 0, "type": "HD", "is_default": 1, "order": -1 }
  ]
}
```

### 5.2 Player payload (HTML) -> cần parse

- Endpoint: `POST /chillsplayer.php`
- Body:
  - `qcao=<episode_id>`
  - `sv=<server_id>` (0..3)
- Response: HTML + script call:
  - `iniPlayers("<hash>",2,)`
  - script source khác nhau theo `sv` (`sotrim2.js`, `dashstrim2.js`, ...)

### 5.3 Stream endpoints (từ player js)

- Với `sotrim2.js`:
  - `https://sotrim.listpm.net/manifest/<hash>` (JSON manifest)
  - `https://sotrim.listpm.net/mpeg/<hash>/index.m3u8`
- Với `dashstrim2.js`:
  - `https://sotrim.topphimmoi.org/hlspm/<hash>`
  - `https://sotrim.topphimmoi.org/raw/<hash>/index.m3u8`
- Với `sotrym.js`:
  - `https://dash.motchills.net/hlspm/<hash>`
  - `https://dash.motchills.net/raw/<hash>/index.m3u8`
- Với `pmcontent.js`:
  - `https://dash.megacdn.xyz/hlspm/<hash>`
  - `https://dash.megacdn.xyz/raw/<hash>/index.m3u8`

Lưu ý:

- Tùy episode, một số `sv` có thể trả hash rỗng (`[]`) => không có stream usable.

### 5.4 Vì sao "có link nhưng không play"

- Với sample hash `4495fca2c876bc2a4d22b293a08027d9`:
  - `manifest/hlspm` trả `segments[].link` có đuôi ngụy trang như `.woff2`, `.css`, `.js`, `.dat`, `.map`, `.ico`.
  - `index.m3u8` cũng chứa chính các URL đuôi này.
- Quan trọng:
  - `https://sotrim.listpm.net/manifest/<hash>` và `https://sotrim.topphimmoi.org/hlspm/<hash>` là JSON manifest, KHÔNG phải URL phát trực tiếp.
  - URL phát trực tiếp phải là:
    - `https://sotrim.listpm.net/mpeg/<hash>/index.m3u8`
    - `https://sotrim.topphimmoi.org/raw/<hash>/index.m3u8`
- Luồng phát thật của site:
  1. `chillsplayer.php` trả `iniPlayers(hash, ...)`
  2. player js gọi `manifest/hlspm`
  3. `generatem3u8(...)` build lại playlist
  4. tạo Blob URL `application/x-mpegURL`
  5. feed Blob URL vào JWPlayer
- Kết luận: app native mở thẳng một số `index.m3u8` sẽ fail/không ổn định; nên mô phỏng luồng `manifest -> generate m3u8` hoặc fallback WebView.

### 5.5 JSON schema mục tiêu cho playback

```json
{
  "episodeId": "127107",
  "episodeName": "Full",
  "filmId": "17380",
  "servers": [
    {
      "serverId": 0,
      "label": "HD",
      "default": true,
      "playerScript": "https://phimmoichill.men/player/sotrim2.js",
      "hash": "5f1c77b9db2239e063e3033dde72059e",
      "manifestUrl": "https://sotrim.listpm.net/manifest/5f1c77b9db2239e063e3033dde72059e",
      "hlsUrl": "https://sotrim.listpm.net/mpeg/5f1c77b9db2239e063e3033dde72059e/index.m3u8"
    }
  ]
}
```

---

## 6) Mapping HTML -> JSON (Swift / Kotlin)

## 6.1 Swift (SwiftSoup)

```swift
import SwiftSoup

struct FilmItem: Codable {
    let title: String
    let detailUrl: String
    let posterUrl: String?
    let status: String?
}

func parseFilmListHTML(_ html: String) throws -> [FilmItem] {
    let doc = try SwiftSoup.parse(html)
    let items = try doc.select("li.item")
    return try items.map { li in
        let a = try li.select("a").first()
        let img = try li.select("img").first()
        let title = try li.select("h3").text()
        let status = try li.select(".label, .status").first()?.text()
        return FilmItem(
            title: title,
            detailUrl: try a?.attr("href") ?? "",
            posterUrl: try img?.attr("src"),
            status: status
        )
    }
}
```

## 6.2 Kotlin (Jsoup)

```kotlin
import org.jsoup.Jsoup

data class FilmItem(
    val title: String,
    val detailUrl: String,
    val posterUrl: String?,
    val status: String?
)

fun parseFilmListHtml(html: String): List<FilmItem> {
    val doc = Jsoup.parse(html)
    return doc.select("li.item").map { li ->
        val a = li.selectFirst("a")
        val img = li.selectFirst("img")
        val title = li.selectFirst("h3")?.text().orEmpty()
        val status = li.selectFirst(".label, .status")?.text()
        FilmItem(
            title = title,
            detailUrl = a?.attr("href").orEmpty(),
            posterUrl = img?.attr("src"),
            status = status
        )
    }
}
```

## 6.3 Parse `chillsplayer.php` để lấy hash

- Regex nên dùng:
  - `iniPlayers\\(\"([a-f0-9]{32})\"`

Sau khi có hash:

- map sang `manifestUrl` + `hlsUrl` theo script domain tương ứng.

Mapping nhanh cho 2 server thường usable (`sv=0/1`):

- `sv=0` (`player/sotrim2.js`) -> playable:
  - `https://sotrim.listpm.net/mpeg/<hash>/index.m3u8`
- `sv=1` (`player/dashstrim2.js`) -> playable:
  - `https://sotrim.topphimmoi.org/raw/<hash>/index.m3u8`

## 6.4 Mapping playback JSON (khuyến nghị cho Swift/Kotlin)

`PlaybackSource` nên tách 2 loại:

- `directM3u8`: dùng khi stream URL phát trực tiếp được.
- `manifestBased`: chứa `manifestUrl/hlspmUrl` để app tự build lại m3u8 text từ `segments`.

Schema gợi ý:

```json
{
  "type": "manifestBased",
  "serverId": 0,
  "hash": "4495fca2c876bc2a4d22b293a08027d9",
  "manifestUrl": "https://sotrim.listpm.net/manifest/4495fca2c876bc2a4d22b293a08027d9",
  "fallbackM3u8": "https://sotrim.listpm.net/mpeg/4495fca2c876bc2a4d22b293a08027d9/index.m3u8"
}
```

## 6.5 Swift sample: resolve 2 playable links từ `episode_id`

```swift
import Foundation

struct PlayableLinkResult: Codable {
    let episodeId: String
    let hash: String
    let playableUrls: [String]
}

enum ResolverError: Error {
    case invalidResponse
    case hashNotFound
}

final class PhimChillResolver {
    private let base = URL(string: "https://phimmoichill.men")!
    private let session = URLSession(configuration: .default)

    func resolvePlayableLinks(episodeId: String) async throws -> PlayableLinkResult {
        let html0 = try await fetchChillsPlayerHTML(episodeId: episodeId, sv: 0)
        let hash = try extractHash(from: html0)

        let url0 = "https://sotrim.listpm.net/mpeg/\(hash)/index.m3u8"
        let url1 = "https://sotrim.topphimmoi.org/raw/\(hash)/index.m3u8"

        return PlayableLinkResult(
            episodeId: episodeId,
            hash: hash,
            playableUrls: [url0, url1]
        )
    }

    private func fetchChillsPlayerHTML(episodeId: String, sv: Int) async throws -> String {
        var req = URLRequest(url: base.appendingPathComponent("chillsplayer.php"))
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = "qcao=\(episodeId)&sv=\(sv)".data(using: .utf8)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            throw ResolverError.invalidResponse
        }
        return html
    }

    private func extractHash(from html: String) throws -> String {
        let pattern = #"iniPlayers\("([a-f0-9]{32})""#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let hashRange = Range(match.range(at: 1), in: html) else {
            throw ResolverError.hashNotFound
        }
        return String(html[hashRange])
    }
}
```

Swift AVPlayer headers mẫu (để giảm khả năng anti-leech chặn):

```swift
import AVFoundation

let headers = [
    "Referer": "https://phimmoichill.men/",
    "Origin": "https://phimmoichill.men",
    "User-Agent": "Mozilla/5.0"
]
let options: [String: Any] = ["AVURLAssetHTTPHeaderFieldsKey": headers]
let asset = AVURLAsset(url: URL(string: playableUrl)!, options: options)
let item = AVPlayerItem(asset: asset)
let player = AVPlayer(playerItem: item)
player.play()
```

## 6.6 Kotlin sample: resolve 2 playable links từ `episode_id`

```kotlin
import okhttp3.FormBody
import okhttp3.OkHttpClient
import okhttp3.Request

data class PlayableLinkResult(
    val episodeId: String,
    val hash: String,
    val playableUrls: List<String>
)

class PhimChillResolver(
    private val client: OkHttpClient = OkHttpClient()
) {
    fun resolvePlayableLinks(episodeId: String): PlayableLinkResult {
        val html = fetchChillsPlayerHtml(episodeId, 0)
        val hash = Regex("iniPlayers\\(\"([a-f0-9]{32})\"")
            .find(html)?.groupValues?.get(1)
            ?: error("Hash not found")

        val playable = listOf(
            "https://sotrim.listpm.net/mpeg/$hash/index.m3u8",
            "https://sotrim.topphimmoi.org/raw/$hash/index.m3u8"
        )
        return PlayableLinkResult(episodeId, hash, playable)
    }

    private fun fetchChillsPlayerHtml(episodeId: String, sv: Int): String {
        val body = FormBody.Builder()
            .add("qcao", episodeId)
            .add("sv", sv.toString())
            .build()
        val request = Request.Builder()
            .url("https://phimmoichill.men/chillsplayer.php")
            .post(body)
            .build()
        client.newCall(request).execute().use { resp ->
            require(resp.isSuccessful) { "HTTP ${resp.code}" }
            return resp.body?.string().orEmpty()
        }
    }
}
```

ExoPlayer header mẫu:

```kotlin
val factory = DefaultHttpDataSource.Factory()
    .setDefaultRequestProperties(
        mapOf(
            "Referer" to "https://phimmoichill.men/",
            "Origin" to "https://phimmoichill.men",
            "User-Agent" to "Mozilla/5.0"
        )
    )
```

---

## 7) Khuyến nghị triển khai app

- Bắt buộc có 1 lớp `ParserAdapter` tách riêng network.
- Ưu tiên parse dựa theo selector ổn định:
  - `li.item`, `a[href*="/info/"]`, `img`, `h3`, `.label`, `.status`
- Chuẩn hóa URL tương đối -> tuyệt đối (`https://phimmoichill.men`).
- Cache response HTML ngắn hạn để tránh gọi liên tục.
- Có fallback parser khi thiếu field.

Gợi ý pipeline:

1. Fetch raw HTML/JSON endpoint.
2. Parse -> `Domain DTO`.
3. Convert -> model dùng cho UI.
4. Track parser errors + selector miss.

---

## 8) Endpoint checklist (verified)

- `POST https://phimmoichill.men/ajax/get_content_box` (HTML)
- `POST https://phimmoichill.men/ajax/get_filter_box/` (HTML)
- `GET  https://phimmoichill.men/tim-kiem/<keyword>/` (HTML page search)
- `POST https://phimmoichill.men/ajax/get_episode_links` (JSON)
- `POST https://phimmoichill.men/chillsplayer.php` (HTML player payload)
- `GET  https://sotrim.listpm.net/manifest/<hash>` (JSON)
- `GET  https://sotrim.listpm.net/mpeg/<hash>/index.m3u8` (HLS)
- `GET  https://sotrim.topphimmoi.org/hlspm/<hash>` (JSON)
- `GET  https://sotrim.topphimmoi.org/raw/<hash>/index.m3u8` (HLS)
- `GET  https://dash.motchills.net/hlspm/<hash>` (JSON hoặc empty tùy hash)
- `GET  https://dash.megacdn.xyz/hlspm/<hash>` (JSON hoặc empty tùy hash)

---

## 9) Case study: `pm17367` (Phu Nhan Dai Quan The Ky 21)

URL film:

- `https://phimmoichill.men/info/phu-nhan-dai-quan-the-ky-21-pm17367`

Episode list parse được từ HTML:

- Tập 1: `episode_id=127058`
- Tập 2: `episode_id=127064`
- Tập 3: `episode_id=127117`
- Tập 4: `episode_id=127120`

Test cụ thể tập 1 (`episode_id=127058`):

- `POST /ajax/get_episode_links` -> JSON:
  - `episode.id=127058`, `filmid=17367`, `links=[{id:0,type:"HD"}]`
- `POST /chillsplayer.php`:
  - `sv=0` -> `player/sotrim2.js`, `iniPlayers("4495fca2c876bc2a4d22b293a08027d9",...)`
  - `sv=1` -> `player/dashstrim2.js`, cùng hash
  - `sv=2` -> `player/sotrym.js`, `iniPlayers("[]",...)` (không usable)
  - `sv=3` -> `player/pmcontent.js`, `initPlayer("https://so-trym.phimchill.net/dash/[]/index.m3u8")` (không usable)

Stream endpoint usable nhất cho sample này:

- JSON manifest (trung gian, không play trực tiếp):
  - `https://sotrim.listpm.net/manifest/4495fca2c876bc2a4d22b293a08027d9`
  - `https://sotrim.topphimmoi.org/hlspm/4495fca2c876bc2a4d22b293a08027d9`
- Playable HLS trực tiếp:
  - `https://sotrim.listpm.net/mpeg/4495fca2c876bc2a4d22b293a08027d9/index.m3u8`
  - `https://sotrim.topphimmoi.org/raw/4495fca2c876bc2a4d22b293a08027d9/index.m3u8`

---

## 10) Final verification trên app test (đã chạy thành công)

Đã triển khai flow thực chiến trong app mẫu:

- File: `docs/phimoichill-research/TestPlayableLink/TestPlayableLink/ContentView.swift`
- Input: URL phim info
  - `https://phimmoichill.men/info/phu-nhan-dai-quan-the-ky-21-pm17367`
- Flow runtime:
  1. Fetch trang info.
  2. Parse danh sách tập từ `latest-episode`.
  3. Chọn tập đầu tiên (tập 1, `episode_id=127058`).
  4. Gọi `chillsplayer.php` (`sv=0`, `sv=1`) để lấy `hash`.
  5. Resolve 2 playable links trực tiếp:
     - `listpm/mpeg`
     - `topphimmoi/raw`
  6. Cho phép switch source trong UI và play trực tiếp bằng `AVPlayer`.
  7. Gắn header `Referer`, `Origin`, `User-Agent`.

Kết quả:

- Đã xác nhận play được trên app test.
- Có UI log để quan sát trạng thái `Loading/Ready/Playing/Failed`.
- Nếu một source lỗi, có thể đổi sang source còn lại ngay trên màn hình.

### Commit-ready checklist

- [x] Home/list/search research endpoint + mapping.
- [x] Episode + hash resolution.
- [x] Distinguish manifest JSON vs playable HLS URL.
- [x] Swift/Kotlin resolver mẫu.
- [x] Test app implement end-to-end và verify playback thành công.
