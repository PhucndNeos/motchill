package com.motchill.androidcompose.core.storage

object PlaybackPositionKeys {
    fun key(movieId: Int, episodeId: Int): String {
        return "$PLAYBACK_POSITION_PREFIX:$movieId:$episodeId"
    }
}

