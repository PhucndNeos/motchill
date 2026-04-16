package com.motchill.androidcompose.core.supabase

import com.motchill.androidcompose.domain.model.MovieCard
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class LikedMovieRow(
    @SerialName("user_id") val userId: String,
    @SerialName("movie_id") val movieId: Int,
    @SerialName("movie_snapshot") val movieSnapshot: MovieCard,
    @SerialName("created_at") val createdAt: String? = null,
)

@Serializable
data class PlaybackPositionRow(
    @SerialName("user_id") val userId: String,
    @SerialName("movie_id") val movieId: Int,
    @SerialName("episode_id") val episodeId: Int,
    @SerialName("position_ms") val positionMillis: Long,
    @SerialName("duration_ms") val durationMillis: Long,
    @SerialName("updated_at") val updatedAt: String? = null,
)
