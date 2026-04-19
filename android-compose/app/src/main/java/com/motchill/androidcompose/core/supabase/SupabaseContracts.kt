package com.motchill.androidcompose.core.supabase

import com.motchill.androidcompose.core.storage.PlaybackProgressSnapshot
import com.motchill.androidcompose.domain.model.MovieCard

data class UserSummary(
    val id: String,
    val email: String?,
) {
    val displayTitle: String
        get() = email?.takeIf { it.isNotBlank() } ?: "Signed in"
}

sealed interface AuthState {
    data object Loading : AuthState
    data object SignedOut : AuthState
    data class SignedIn(val user: UserSummary) : AuthState
    data class Error(val message: String) : AuthState
}

interface AuthSessionProvider {
    val isAuthenticated: Boolean
    val userId: String?
    val accessToken: String?
    val currentUser: UserSummary?
}

interface LikedMovieStore {
    suspend fun loadMovies(): List<MovieCard>
    suspend fun isLiked(movieId: Int): Boolean
    suspend fun toggleMovie(movie: MovieCard): List<MovieCard>
}

interface PlaybackPositionStore {
    suspend fun load(movieId: Int, episodeId: Int): PlaybackProgressSnapshot?
    suspend fun save(movieId: Int, episodeId: Int, positionMillis: Long, durationMillis: Long)
}

interface SyncCoordinator {
    suspend fun runMigrationIfNeeded()
    suspend fun syncPlaybackProgress(movieId: Int, episodeId: Int, posMs: Long, durMs: Long)
}

interface SupabaseNetworkClient {
    val supabaseClient: io.github.jan.supabase.SupabaseClient
    suspend fun sendOtp(email: String)
    suspend fun verifyOtp(email: String, token: String): SupabaseSession
    suspend fun fetchCurrentUser(accessToken: String): UserSummary?
}

interface SupabaseSessionRepository {
    fun load(): SupabaseSession?
    fun save(session: SupabaseSession)
    fun clear()
    fun saveEmail(email: String)
    fun loadEmail(): String?
}
