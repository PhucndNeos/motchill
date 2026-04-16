package com.motchill.androidcompose.core.supabase

import com.motchill.androidcompose.core.storage.LocalPlaybackPosition
import com.motchill.androidcompose.core.storage.PlaybackProgressSnapshot
import com.motchill.androidcompose.domain.model.MovieCard
import kotlinx.coroutines.flow.StateFlow

data class SupabaseConfig(
    val baseUrl: String,
    val anonKey: String,
) {
    val isConfigured: Boolean
        get() = baseUrl.isNotBlank() && anonKey.isNotBlank()
}

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

interface LikedMovieLocalStore {
    suspend fun loadMovies(): List<MovieCard>
    suspend fun clearAll()
}

interface LikedMovieRemoteStore {
    suspend fun loadMovies(): List<MovieCard>
    suspend fun toggleMovie(movie: MovieCard): List<MovieCard>
    suspend fun importLegacyMovies(movies: List<MovieCard>)
}

interface PlaybackPositionLocalStore {
    suspend fun load(movieId: Int, episodeId: Int): PlaybackProgressSnapshot?
    suspend fun loadAllPending(): List<LocalPlaybackPosition>
    suspend fun clearSynced(positions: Collection<LocalPlaybackPosition>)
    suspend fun clear(movieId: Int, episodeId: Int)
}

interface PlaybackPositionRemoteStore {
    suspend fun load(movieId: Int, episodeId: Int): PlaybackProgressSnapshot?
    suspend fun save(movieId: Int, episodeId: Int, positionMillis: Long, durationMillis: Long)
    suspend fun importLegacyPositions(positions: List<LocalPlaybackPosition>)
}

interface SyncCoordinator {
    suspend fun runMigrationIfNeeded()
    suspend fun syncPlaybackProgress(movieId: Int, episodeId: Int, posMs: Long, durMs: Long)
}

interface SupabaseNetworkClient {
    suspend fun sendOtp(email: String)
    suspend fun verifyOtp(email: String, token: String): SupabaseSession
    suspend fun fetchCurrentUser(accessToken: String): UserSummary?
}

interface SupabaseSessionRepository {
    fun load(): SupabaseSession?
    fun save(session: SupabaseSession)
    fun clear()
}
