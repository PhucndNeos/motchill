package com.motchill.androidcompose.core.storage

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.core.content.edit

class PlaybackPositionStore(context: Context) {
    private val prefs = context.getSharedPreferences(PLAYBACK_POSITION_PREFS, Context.MODE_PRIVATE)

    suspend fun save(movieId: Int, episodeId: Int, positionMillis: Long) = withContext(Dispatchers.IO) {
        prefs.edit { putLong(PlaybackPositionKeys.key(movieId, episodeId), positionMillis) }
    }

    suspend fun load(movieId: Int, episodeId: Int): Long? = withContext(Dispatchers.IO) {
        val value = prefs.getLong(PlaybackPositionKeys.key(movieId, episodeId), Long.MIN_VALUE)
        if (value == Long.MIN_VALUE || value < 0) null else value
    }
}

