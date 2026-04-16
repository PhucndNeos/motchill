package com.motchill.androidcompose.core.supabase

import com.motchill.androidcompose.core.storage.PlaybackProgressSnapshot
import com.motchill.androidcompose.domain.model.MovieCard
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlinx.serialization.json.Json
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class SupabaseRestClient(private val config: SupabaseConfig) : SupabaseNetworkClient {
    private val client = OkHttpClient.Builder()
        .callTimeout(20, TimeUnit.SECONDS)
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .writeTimeout(20, TimeUnit.SECONDS)
        .build()
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true; explicitNulls = false }
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    fun isConfigured(): Boolean = config.isConfigured

    override suspend fun sendOtp(email: String) {
        postJson(
            path = "/auth/v1/otp",
            body = JSONObject()
                .put("email", email)
                .put("create_user", true)
                .toString(),
            includeBearer = false,
        )
    }

    override suspend fun verifyOtp(email: String, token: String): SupabaseSession {
        val response = postJson(
            path = "/auth/v1/verify",
            body = JSONObject()
                .put("email", email)
                .put("token", token)
                .put("type", "email")
                .toString(),
            includeBearer = false,
        )
        val payload = JSONObject(response)
        val accessToken = payload.getString("access_token")
        val refreshToken = payload.optString("refresh_token")
        val tokenType = payload.optString("token_type", "bearer")
        val expiresAt = payload.optLong("expires_at", 0L)
        val user = payload.getJSONObject("user").toUserSummary()
        return SupabaseSession(
            accessToken = accessToken,
            refreshToken = refreshToken,
            tokenType = tokenType,
            expiresAtEpochSeconds = expiresAt,
            user = user,
        )
    }

    override suspend fun fetchCurrentUser(accessToken: String): UserSummary? {
        val response = getJson(
            path = "/auth/v1/user",
            accessToken = accessToken,
        ) ?: return null
        return JSONObject(response).toUserSummary()
    }

    fun loadLikedMovies(userId: String, accessToken: String): List<MovieCard> {
        val response = getJson(
            path = "/rest/v1/liked_movies?select=user_id,movie_id,movie_snapshot&user_id=eq.${encodeQuery(userId)}",
            accessToken = accessToken,
        ) ?: return emptyList()
        val rows = json.decodeFromString<List<LikedMovieRow>>(response)
        return rows.map { it.movieSnapshot }
    }

    fun toggleLikedMovie(userId: String, accessToken: String, movie: MovieCard): List<MovieCard> {
        val existing = loadLikedMovies(userId, accessToken).firstOrNull { it.id == movie.id }
        return if (existing != null) {
            deleteLikedMovie(userId, accessToken, movie.id)
            loadLikedMovies(userId, accessToken)
        } else {
            upsertLikedMovies(userId, accessToken, listOf(movie))
            loadLikedMovies(userId, accessToken)
        }
    }

    fun upsertLikedMovies(userId: String, accessToken: String, movies: List<MovieCard>) {
        if (movies.isEmpty()) return
        val rows = movies.map { LikedMovieRow(userId = userId, movieId = it.id, movieSnapshot = it) }
        postJson(
            path = "/rest/v1/liked_movies?on_conflict=user_id,movie_id",
            body = json.encodeToString(rows),
            accessToken = accessToken,
            method = HttpMethod.POST,
            preferHeader = "resolution=merge-duplicates,return=minimal",
        )
    }

    fun deleteLikedMovie(userId: String, accessToken: String, movieId: Int) {
        delete(
            path = "/rest/v1/liked_movies?user_id=eq.${encodeQuery(userId)}&movie_id=eq.$movieId",
            accessToken = accessToken,
        )
    }

    fun loadPlaybackPosition(
        userId: String,
        accessToken: String,
        movieId: Int,
        episodeId: Int,
    ): PlaybackProgressSnapshot? {
        val response = getJson(
            path = "/rest/v1/playback_positions?select=*&user_id=eq.${encodeQuery(userId)}&movie_id=eq.$movieId&episode_id=eq.$episodeId",
            accessToken = accessToken,
        ) ?: return null
        val rows = json.decodeFromString<List<PlaybackPositionRow>>(response)
        val row = rows.firstOrNull() ?: return null
        return PlaybackProgressSnapshot(row.positionMillis, row.durationMillis)
    }

    fun upsertPlaybackPosition(
        userId: String,
        accessToken: String,
        row: PlaybackPositionRow,
    ) {
        postJson(
            path = "/rest/v1/playback_positions?on_conflict=user_id,movie_id,episode_id",
            body = json.encodeToString(listOf(row.copy(userId = userId))),
            accessToken = accessToken,
            method = HttpMethod.POST,
            preferHeader = "resolution=merge-duplicates,return=minimal",
        )
    }

    fun upsertPlaybackPositions(
        userId: String,
        accessToken: String,
        rows: List<PlaybackPositionRow>,
    ) {
        if (rows.isEmpty()) return
        postJson(
            path = "/rest/v1/playback_positions?on_conflict=user_id,movie_id,episode_id",
            body = json.encodeToString(rows.map { it.copy(userId = userId) }),
            accessToken = accessToken,
            method = HttpMethod.POST,
            preferHeader = "resolution=merge-duplicates,return=minimal",
        )
    }

    private fun getJson(path: String, accessToken: String): String? {
        val response = request(
            method = HttpMethod.GET,
            path = path,
            accessToken = accessToken,
            body = null,
        )
        return if (response.isBlank()) null else response
    }

    private fun delete(path: String, accessToken: String) {
        request(
            method = HttpMethod.DELETE,
            path = path,
            accessToken = accessToken,
            body = null,
        )
    }

    private fun postJson(
        path: String,
        body: String,
        accessToken: String? = null,
        includeBearer: Boolean = true,
        method: HttpMethod = HttpMethod.POST,
        preferHeader: String? = null,
    ): String {
        return request(
            method = method,
            path = path,
            accessToken = accessToken,
            body = body,
            includeBearer = includeBearer,
            preferHeader = preferHeader,
        )
    }

    private fun request(
        method: HttpMethod,
        path: String,
        accessToken: String? = null,
        body: String?,
        includeBearer: Boolean = true,
        preferHeader: String? = null,
    ): String {
        if (!config.isConfigured) {
            throw IOException("Supabase is not configured")
        }

        val requestBuilder = Request.Builder()
            .url(config.baseUrl.trimEnd('/') + path)
            .header("apikey", config.anonKey)
            .header("Content-Type", "application/json")
            .header("Accept", "application/json")
        if (includeBearer && !accessToken.isNullOrBlank()) {
            requestBuilder.header("Authorization", "Bearer $accessToken")
        }
        if (preferHeader != null) {
            requestBuilder.header("Prefer", preferHeader)
        }

        val requestBody = body?.toRequestBody(jsonMediaType)
        val preparedBuilder = when (method) {
            HttpMethod.GET -> requestBuilder.get()
            HttpMethod.POST -> requestBuilder.post(requestBody ?: "".toRequestBody(jsonMediaType))
            HttpMethod.DELETE -> requestBuilder.delete(requestBody ?: ByteArray(0).toRequestBody(jsonMediaType))
        }

        client.newCall(preparedBuilder.build()).execute().use { response ->
            val raw = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw IOException("HTTP ${response.code}: $raw")
            }
            return raw
        }
    }

    private fun JSONObject.toUserSummary(): UserSummary {
        return UserSummary(
            id = optString("id"),
            email = optString("email").takeIf { it.isNotBlank() },
        )
    }

    private fun encodeQuery(value: String): String {
        return java.net.URLEncoder.encode(value, Charsets.UTF_8.name())
    }

    private enum class HttpMethod { GET, POST, DELETE }
}
