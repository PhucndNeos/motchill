# Android — Supabase Auth & Data Sync: Implementation Plan

> Dựa trên: `docs/software-development/supabase-auth-sync.md` + iOS SwiftUI source (`Core/Supabase/`)

---

## 1. Tổng quan & Mục tiêu

Plan này hướng dẫn triển khai đăng nhập Email OTP (Supabase) và đồng bộ dữ liệu cho app Android Motchill. Behavior phải khớp hoàn toàn với iOS — cùng Supabase backend, cùng bảng CSDL, và cùng conflict-resolution rule.

**Hai domain dữ liệu được đồng bộ:**
- Liked Movies
- Playback Progress (theo từng episode)

**Nguyên tắc thiết kế:**
- Remote là **read source chính** sau khi đăng nhập.
- Local store là **write buffer**, không phải canonical store.
- Player **không** được ghi thẳng lên Supabase mỗi 0.25 giây.
- Migration chạy lại mỗi khi session được khôi phục — không cần code path riêng.
- Sync failure **không được block playback**.

---

## 2. Dependencies cần thêm

### 2.1 `build.gradle.kts` (app module)

```kotlin
// Supabase BOM + modules
implementation(platform("io.github.jan-tennert.supabase:bom:3.1.4"))
implementation("io.github.jan-tennert.supabase:postgrest-kt")
implementation("io.github.jan-tennert.supabase:auth-kt")

// Ktor HTTP engine cho Android
implementation("io.ktor:ktor-client-android:3.1.3")

// kotlinx.serialization (Supabase SDK yêu cầu)
implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.0")
```

### 2.2 `build.gradle.kts` (project level) — thêm plugin

```kotlin
alias(libs.plugins.kotlin.serialization)
```

### 2.3 `libs.versions.toml`

```toml
[versions]
supabase-bom = "3.1.4"
ktor = "3.1.3"
kotlinx-serialization = "1.8.0"

[plugins]
kotlin-serialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
```

---

## 3. Kiến trúc tổng thể

Giữ nguyên pattern `ViewModel → Repository → Storage` hiện có, mở rộng thêm lớp Supabase:

```
PlayerViewModel ──────────────→ LocalPlaybackPositionStore (write buffer)
AuthViewModel ────────────────→ SupabaseAuthManager
SupabaseAuthManager ──────────→ SyncCoordinator (trigger on sign-in / session restore)
SyncCoordinator ──────────────→ SupabaseLikedMovieStore
                 └────────────→ SupabasePlaybackPositionStore
                 └────────────→ LocalLikedMovieStore (read pending, clear after sync)
                 └────────────→ LocalPlaybackPositionStore (read pending, clear after sync)
DetailViewModel ──────────────→ SupabasePlaybackPositionStore (remote read)
```

---

## 4. Bước 1 — Cấu hình Supabase

### 4.1 File: `core/supabase/SupabaseConfig.kt`

```kotlin
data class SupabaseConfig(
    val url: String,
    val publishableKey: String
)
```

### 4.2 Thêm vào `defaultConfig` trong `build.gradle.kts`

```kotlin
buildConfigField("String", "SUPABASE_URL", "\"https://xxx.supabase.co\"")
buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", "\"your-anon-key\"")
```

> ⚠️ Không commit key thật vào git. Dùng `local.properties` hoặc CI secrets injection.

### 4.3 File: `core/supabase/SupabaseClientProvider.kt`

```kotlin
fun createSupabaseClient(config: SupabaseConfig): SupabaseClient =
    createSupabaseClient(config.url, config.publishableKey) {
        install(Auth)
        install(Postgrest)
    }
```

---

## 5. Bước 2 — SupabaseAuthManager

**File:** `core/supabase/SupabaseAuthManager.kt`

Tương đương `PhucTvSupabaseAuthManager.swift` trên iOS. Dùng `StateFlow` thay vì `@Observable`.

### 5.1 AuthState

```kotlin
sealed interface AuthState {
    data object Loading : AuthState
    data object SignedOut : AuthState
    data class SignedIn(val user: UserSummary) : AuthState
    data class Error(val message: String) : AuthState
}

data class UserSummary(
    val id: String,
    val email: String?
) {
    val displayTitle: String get() = email?.takeIf { it.isNotBlank() } ?: "Signed in"
}
```

### 5.2 SupabaseAuthManager

```kotlin
class SupabaseAuthManager(
    private val client: SupabaseClient,
    private val syncCoordinator: SyncCoordinator
) {
    private val _state = MutableStateFlow<AuthState>(AuthState.Loading)
    val state: StateFlow<AuthState> = _state.asStateFlow()

    val isAuthenticated: Boolean
        get() = _state.value is AuthState.SignedIn

    init { observeAuthState() }

    /** Bước 1 của OTP flow: gửi mã đến email */
    suspend fun sendOTP(email: String) {
        client.auth.signInWith(OTP) { this.email = email }
    }

    /** Bước 2 của OTP flow: xác minh mã 6 số */
    suspend fun verifyOTP(email: String, token: String) {
        client.auth.verifyEmailOtp(type = OtpType.Email.EMAIL, email = email, token = token)
    }

    /** Đăng xuất: clear session, không trigger migration */
    suspend fun signOut() {
        client.auth.signOut()
        _state.value = AuthState.SignedOut
    }

    /** Gọi khi app foreground để khôi phục session */
    suspend fun refreshSession() {
        val session = client.auth.currentSessionOrNull()
        if (session != null) {
            _state.value = AuthState.SignedIn(session.user.toUserSummary())
            syncCoordinator.runMigrationIfNeeded()
        } else {
            _state.value = AuthState.SignedOut
        }
    }

    private fun observeAuthState() {
        // Chạy trong coroutine scope của ViewModel hoặc Application
        client.auth.sessionStatus.collectLatest { status ->
            when (status) {
                is SessionStatus.Authenticated -> {
                    _state.value = AuthState.SignedIn(status.session.user.toUserSummary())
                    syncCoordinator.runMigrationIfNeeded()
                }
                is SessionStatus.NotAuthenticated -> _state.value = AuthState.SignedOut
                is SessionStatus.LoadingFromStorage -> _state.value = AuthState.Loading
                is SessionStatus.NetworkError     -> _state.value = AuthState.Error("Network error")
            }
        }
    }
}
```

---

## 6. Bước 3 — Data Models (Kotlin / Serializable)

**File:** `core/supabase/models/LikedMovieRow.kt`

```kotlin
@Serializable
data class LikedMovieRow(
    @SerialName("user_id")       val userId: String,
    @SerialName("movie_id")      val movieId: Int,
    @SerialName("movie_snapshot") val movieSnapshot: MovieCard,
    @SerialName("created_at")    val createdAt: String? = null
)
```

**File:** `core/supabase/models/PlaybackPositionRow.kt`

```kotlin
@Serializable
data class PlaybackPositionRow(
    @SerialName("user_id")     val userId: String,
    @SerialName("movie_id")    val movieId: Int,
    @SerialName("episode_id")  val episodeId: Int,
    @SerialName("position_ms") val positionMillis: Long,
    @SerialName("duration_ms") val durationMillis: Long,
    @SerialName("updated_at")  val updatedAt: String? = null
)
```

> `MovieCard` cần thêm `@Serializable` annotation để upsert được vào cột `movie_snapshot` (JSON).

---

## 7. Bước 4 — Remote Stores

### 7.1 SupabaseLikedMovieStore

**File:** `core/supabase/SupabaseLikedMovieStore.kt`

```kotlin
class SupabaseLikedMovieStore(private val client: SupabaseClient) {

    suspend fun loadMovies(): List<MovieCard> {
        val session = client.auth.currentSessionOrNull() ?: return emptyList()
        return client.postgrest["liked_movies"]
            .select { filter { eq("user_id", session.user.id) } }
            .decodeList<LikedMovieRow>()
            .map { it.movieSnapshot }
    }

    suspend fun loadIds(): Set<Int> = loadMovies().map { it.id }.toSet()

    suspend fun isLiked(movieId: Int): Boolean = loadIds().contains(movieId)

    /** Toggle: upsert nếu chưa liked, DELETE nếu đã liked */
    suspend fun toggle(movie: MovieCard): List<MovieCard> {
        val session = client.auth.currentSessionOrNull() ?: return emptyList()
        val userId = session.user.id
        val exists = client.postgrest["liked_movies"]
            .select { filter { eq("user_id", userId); eq("movie_id", movie.id) } }
            .decodeList<LikedMovieRow>().isNotEmpty()

        if (exists) {
            client.postgrest["liked_movies"].delete {
                filter { eq("user_id", userId); eq("movie_id", movie.id) }
            }
        } else {
            client.postgrest["liked_movies"].upsert(
                LikedMovieRow(userId, movie.id, movie),
                onConflict = "user_id,movie_id"
            )
        }
        return loadMovies()
    }

    /** Migration: upsert batch từ local sang remote */
    suspend fun importLegacyMovies(movies: List<MovieCard>) {
        val session = client.auth.currentSessionOrNull() ?: return
        if (movies.isEmpty()) return
        val rows = movies.map { LikedMovieRow(session.user.id, it.id, it) }
        client.postgrest["liked_movies"].upsert(rows, onConflict = "user_id,movie_id")
    }
}
```

### 7.2 SupabasePlaybackPositionStore

**File:** `core/supabase/SupabasePlaybackPositionStore.kt`

```kotlin
class SupabasePlaybackPositionStore(private val client: SupabaseClient) {

    /** Upsert với conflict rule: furthest position wins */
    suspend fun save(movieId: Int, episodeId: Int, posMs: Long, durMs: Long) {
        val session = client.auth.currentSessionOrNull() ?: return
        val userId = session.user.id

        // Đọc remote trước để so sánh
        val remote = load(movieId, episodeId)
        if (remote != null
            && remote.positionMillis >= posMs
            && remote.durationMillis >= durMs) return  // skip: remote đã tốt hơn hoặc bằng

        val row = PlaybackPositionRow(
            userId = userId,
            movieId = movieId,
            episodeId = episodeId,
            positionMillis = posMs.coerceAtLeast(0L),
            durationMillis = durMs.coerceAtLeast(0L)
        )
        client.postgrest["playback_positions"].upsert(row, onConflict = "user_id,movie_id,episode_id")
    }

    suspend fun load(movieId: Int, episodeId: Int): PlaybackProgressSnapshot? {
        val session = client.auth.currentSessionOrNull() ?: return null
        val rows = client.postgrest["playback_positions"]
            .select {
                filter {
                    eq("user_id", session.user.id)
                    eq("movie_id", movieId)
                    eq("episode_id", episodeId)
                }
            }
            .decodeList<PlaybackPositionRow>()
        val row = rows.firstOrNull() ?: return null
        return PlaybackProgressSnapshot(row.positionMillis, row.durationMillis)
    }

    /** Migration: upsert batch positions từ local */
    suspend fun importLegacyPositions(positions: List<LocalPlaybackPosition>) {
        val session = client.auth.currentSessionOrNull() ?: return
        if (positions.isEmpty()) return
        val rows = positions.map {
            PlaybackPositionRow(session.user.id, it.movieId, it.episodeId,
                it.positionMillis.coerceAtLeast(0L), it.durationMillis.coerceAtLeast(0L))
        }
        client.postgrest["playback_positions"].upsert(rows, onConflict = "user_id,movie_id,episode_id")
    }
}
```

### 7.3 Conflict Resolution Rule

| Điều kiện | Kết quả |
|---|---|
| `remote.position >= local.position` AND `remote.duration >= local.duration` | Skip write |
| `local.position > remote.position` | Upsert local lên remote |
| Position bằng nhau, `local.duration > remote.duration` | Upsert local lên remote |

---

## 8. Bước 5 — SyncCoordinator

**File:** `core/supabase/SyncCoordinator.kt`

```kotlin
interface SyncCoordinator {
    /** Chạy sau sign-in và session restore */
    suspend fun runMigrationIfNeeded()
    /** Gọi tại các explicit sync point trong PlayerViewModel */
    suspend fun syncPlaybackProgress(movieId: Int, episodeId: Int, posMs: Long, durMs: Long)
}
```

**File:** `core/supabase/DefaultSyncCoordinator.kt`

```kotlin
class DefaultSyncCoordinator(
    private val localLikedMovieStore: LikedMovieStore,
    private val remoteLikedMovieStore: SupabaseLikedMovieStore,
    private val localPlaybackStore: PlaybackPositionStore,
    private val remotePlaybackStore: SupabasePlaybackPositionStore
) : SyncCoordinator {

    override suspend fun runMigrationIfNeeded() {
        // 1. Migrate liked movies (độc lập với playback)
        try {
            val pending = localLikedMovieStore.loadMovies()
            if (pending.isNotEmpty()) {
                remoteLikedMovieStore.importLegacyMovies(pending)
                localLikedMovieStore.clearAll()  // xóa sau khi sync thành công
            }
        } catch (_: Exception) {
            // giữ local, retry lần sau
        }

        // 2. Migrate playback positions (độc lập)
        try {
            val pending = localPlaybackStore.loadAllPending()
            if (pending.isNotEmpty()) {
                remotePlaybackStore.importLegacyPositions(pending)
                localPlaybackStore.clearSynced(pending)
            }
        } catch (_: Exception) {
            // giữ local pending, retry lần sau
        }
    }

    override suspend fun syncPlaybackProgress(
        movieId: Int, episodeId: Int, posMs: Long, durMs: Long
    ) {
        try {
            remotePlaybackStore.save(movieId, episodeId, posMs, durMs)
            localPlaybackStore.markSynced(movieId, episodeId)
        } catch (_: Exception) {
            // Giữ local pending — retry khi có explicit sync tiếp theo
        }
    }
}
```

> **Partial failure:** Liked movies và playback migrate độc lập. Nếu một bên thành công thì xóa phần đó, bên còn lại giữ nguyên để retry.

---

## 9. Bước 6 — Cập nhật AppContainer

Thêm vào `PhucTVAppContainer.kt`:

```kotlin
val supabaseClient: SupabaseClient by lazy {
    createSupabaseClient(SupabaseConfig(
        url = BuildConfig.SUPABASE_URL,
        publishableKey = BuildConfig.SUPABASE_PUBLISHABLE_KEY
    ))
}

val remoteLikedMovieStore: SupabaseLikedMovieStore by lazy {
    SupabaseLikedMovieStore(supabaseClient)
}

val remotePlaybackStore: SupabasePlaybackPositionStore by lazy {
    SupabasePlaybackPositionStore(supabaseClient)
}

val syncCoordinator: SyncCoordinator by lazy {
    DefaultSyncCoordinator(
        localLikedMovieStore  = likedMovieStore,
        remoteLikedMovieStore = remoteLikedMovieStore,
        localPlaybackStore    = playbackPositionStore,
        remotePlaybackStore   = remotePlaybackStore
    )
}

val authManager: SupabaseAuthManager by lazy {
    SupabaseAuthManager(supabaseClient, syncCoordinator)
}
```

---

## 10. Bước 7 — Auth UI (Jetpack Compose)

### 10.1 AuthUiState

**File:** `feature/auth/AuthViewModel.kt`

```kotlin
sealed interface AuthUiState {
    data object Idle : AuthUiState
    data object Loading : AuthUiState
    data class EnterOtp(val email: String) : AuthUiState
    data class Success(val user: UserSummary) : AuthUiState
    data class Error(val message: String) : AuthUiState
}
```

### 10.2 Flow màn hình

1. User nhập email → tap **"Gửi mã OTP"** → `AuthViewModel.sendOTP(email)`
2. Chuyển sang màn hình nhập OTP (`EnterOtp` state)
3. User nhập 6 chữ số → tap **"Xác nhận"** → `AuthViewModel.verifyOTP(email, token)`
4. Nếu thành công → `AuthState.SignedIn` → navigation tự động về màn hình trước
5. Nếu lỗi → hiển thị error message, không sign out session cũ

### 10.3 Routes mới trong AppNavHost

```kotlin
composable(AppRoutes.AUTH)    { AuthScreen(authManager = PhucTVAppContainer.authManager) }
composable(AppRoutes.ACCOUNT) { AccountScreen(authManager = PhucTVAppContainer.authManager) }
```

**AccountScreen:** Nếu đã đăng nhập → hiển thị email + nút "Đăng xuất". Nếu chưa → hiển thị "Đăng nhập để đồng bộ liked movies và playback position."

---

## 11. Bước 8 — Tích hợp PlayerViewModel

### 11.1 Load progress: remote-first

```kotlin
val progress = if (authManager.isAuthenticated) {
    remotePlaybackStore.load(movieId, episodeId)
        ?: localPlaybackStore.load(movieId, episodeId)
} else {
    localPlaybackStore.load(movieId, episodeId)
}
```

### 11.2 Save path — local write buffer (mỗi 15s delta)

```kotlin
// TimeObserver callback mỗi 0.25s
elapsedSinceLastCheckpoint += deltaMs
if (elapsedSinceLastCheckpoint >= 15_000L) {
    localPlaybackStore.save(movieId, episodeId, posMs, durMs)
    elapsedSinceLastCheckpoint = 0L
}
// KHÔNG gọi remote tại đây
```

### 11.3 Sync path — explicit remote sync

Gọi `syncCoordinator.syncPlaybackProgress(...)` tại:
- User **pause** playback
- **Seek** hoàn thành
- User **đổi source**
- `onCleared()` của PlayerViewModel (màn hình disappear)

---

## 12. Sync Timing Matrix

| Sự kiện | Local save | Remote sync | Auth trigger | Retry on fail |
|---|---|---|---|---|
| Time observer tick (0.25s) | Mỗi 15s delta | Không | — | — |
| User pause | Có | Có | — | Có |
| Seek hoàn thành | Có | Có | — | Có |
| Đổi source | Có | Có | — | Có |
| Player disappear (`onCleared`) | Có | Có | — | Có |
| Sign-in / Session restore | Không | Có (migrator) | Trigger | Có |
| Sign-out | Không | Không | — | — |

---

## 13. Xử lý lỗi

### Auth failures
- Hiển thị error message rõ ràng trên AuthScreen.
- Giữ nguyên session signed out.
- Không xóa local progress khi auth thất bại.

### Sync failures
- Giữ lại local pending playback progress.
- Retry vào lần sync tiếp theo (không poll liên tục — chỉ retry khi có explicit event).
- Không block playback dưới bất kỳ hoàn cảnh nào.

### Partial migration
- Liked movies và playback positions migrate hoàn toàn độc lập.
- Thành công từng phần → chỉ xóa data đã sync thành công, phần còn lại giữ để retry.

---

## 14. Cấu trúc file mới

```
app/src/main/java/com/motchill/androidcompose/
├── core/
│   └── supabase/
│       ├── SupabaseConfig.kt
│       ├── SupabaseClientProvider.kt
│       ├── SupabaseAuthManager.kt
│       ├── SupabaseLikedMovieStore.kt
│       ├── SupabasePlaybackPositionStore.kt
│       ├── SyncCoordinator.kt
│       ├── DefaultSyncCoordinator.kt
│       └── models/
│           ├── LikedMovieRow.kt
│           └── PlaybackPositionRow.kt
└── feature/
    ├── auth/
    │   ├── AuthScreen.kt
    │   └── AuthViewModel.kt
    └── account/
        ├── AccountScreen.kt
        └── AccountViewModel.kt
```

---

## 15. Implementation Checklist

- [ ] Thêm Supabase BOM + `auth-kt` + `postgrest-kt` + `ktor-client-android` vào `build.gradle.kts`
- [ ] Thêm `kotlin.serialization` plugin
- [ ] Thêm `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY` vào `BuildConfig`
- [ ] Tạo `SupabaseConfig.kt` và `SupabaseClientProvider.kt`
- [ ] Tạo `SupabaseAuthManager.kt` với `StateFlow<AuthState>`
- [ ] Implement `sendOTP` / `verifyOTP` / `signOut` / `refreshSession`
- [ ] Lắng nghe `sessionStatus` flow → trigger `SyncCoordinator`
- [ ] Tạo `LikedMovieRow.kt` (`@Serializable`)
- [ ] Tạo `PlaybackPositionRow.kt` (`@Serializable`)
- [ ] Thêm `@Serializable` vào `MovieCard`
- [ ] Tạo `SupabaseLikedMovieStore` (load, toggle, importLegacy)
- [ ] Tạo `SupabasePlaybackPositionStore` (load, save với conflict rule, importLegacy)
- [ ] Implement conflict rule: **furthest position wins**
- [ ] Tạo `SyncCoordinator` interface + `DefaultSyncCoordinator`
- [ ] Implement `runMigrationIfNeeded`: migrate liked movies → xóa local
- [ ] Implement `runMigrationIfNeeded`: migrate playback positions → xóa local pending
- [ ] Implement partial failure: chỉ xóa phần đã sync thành công
- [ ] Cập nhật `PhucTVAppContainer`: thêm `supabaseClient`, remote stores, `authManager`
- [ ] Tạo `AuthScreen.kt` (email input → OTP input)
- [ ] Tạo `AuthViewModel.kt` với `AuthUiState`
- [ ] Tạo `AccountScreen.kt` (profile info + sign-out)
- [ ] Thêm route `AUTH` và `ACCOUNT` vào `AppNavHost`
- [ ] `PlayerViewModel`: load progress remote-first khi đã đăng nhập
- [ ] `PlayerViewModel`: giữ nguyên local save mỗi ~15s checkpoint
- [ ] `PlayerViewModel`: thêm explicit sync khi pause / seek / source change / `onCleared`
- [ ] Retry logic: giữ pending khi sync fail, retry lần explicit sync tiếp theo
- [ ] Test: sign-in → migrate local data → verify remote
- [ ] Test: playback progress conflict rule (furthest wins)
- [ ] Test: partial migration failure không xóa phần chưa sync
- [ ] Test: sign-out không xóa local progress

---

## 16. Lưu ý quan trọng

- **Không commit key thật** vào git. Dùng `local.properties` hoặc CI/CD secrets injection.
- **Supabase anon key** là public-safe nhưng phải bật **Row Level Security (RLS)** trên dashboard: mỗi user chỉ được đọc/ghi rows có `user_id = auth.uid()`.
- Kotlin SDK dùng coroutines — tất cả Supabase calls phải trong `suspend` function hoặc coroutine scope.
- Với **TV/large screen**, OTP keyboard nên là `KeyboardType.NumberPassword` để dễ nhập bằng D-pad/remote.
- `MovieCard` cần `@Serializable` để được lưu vào cột `movie_snapshot` dạng JSON trên Supabase.
