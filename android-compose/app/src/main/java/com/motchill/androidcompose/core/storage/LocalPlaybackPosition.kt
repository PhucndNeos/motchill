package com.motchill.androidcompose.core.storage

data class LocalPlaybackPosition(
    val movieId: Int,
    val episodeId: Int,
    val positionMillis: Long,
    val durationMillis: Long,
)
