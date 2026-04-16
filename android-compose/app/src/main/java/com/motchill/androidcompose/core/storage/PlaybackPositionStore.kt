package com.motchill.androidcompose.core.storage

import android.content.Context
import androidx.core.content.edit
import com.motchill.androidcompose.core.supabase.AuthSessionProvider
import com.motchill.androidcompose.core.supabase.PlaybackPositionLocalStore
import com.motchill.androidcompose.core.supabase.PlaybackPositionRemoteStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class PlaybackProgressSnapshot(
    val positionMillis: Long,
    val durationMillis: Long,
) {
    val progressFraction: Float
        get() = if (durationMillis <= 0L) 0f else (positionMillis.toFloat() / durationMillis.toFloat()).coerceIn(0f, 1f)
}

class PlaybackPositionStore(
    context: Context,
    private val authSessionProvider: AuthSessionProvider? = null,
    private val remoteStore: PlaybackPositionRemoteStore? = null,
) : PlaybackPositionLocalStore {
    private val prefs = context.getSharedPreferences(PLAYBACK_POSITION_PREFS, Context.MODE_PRIVATE)

    suspend fun save(
        movieId: Int,
        episodeId: Int,
        positionMillis: Long,
        durationMillis: Long,
        ) = withContext(Dispatchers.IO) {
        prefs.edit {
            putLong(PlaybackPositionKeys.key(movieId, episodeId), positionMillis)
            putLong(PlaybackDurationKeys.key(movieId, episodeId), durationMillis.coerceAtLeast(0L))
        }
    }

    override suspend fun load(movieId: Int, episodeId: Int): PlaybackProgressSnapshot? = withContext(Dispatchers.IO) {
        if (authSessionProvider?.isAuthenticated == true && remoteStore != null) {
            remoteStore?.let { runCatching { it.load(movieId, episodeId) } }?.getOrNull()?.let { remoteSnapshot ->
                if (remoteSnapshot != null) {
                    return@withContext remoteSnapshot
                }
            }
        }

        val positionValue = prefs.getLong(PlaybackPositionKeys.key(movieId, episodeId), Long.MIN_VALUE)
        if (positionValue == Long.MIN_VALUE || positionValue < 0) return@withContext null

        val durationValue = prefs.getLong(PlaybackDurationKeys.key(movieId, episodeId), Long.MIN_VALUE)
        val durationMillis = if (durationValue == Long.MIN_VALUE || durationValue < 0) 0L else durationValue
        PlaybackProgressSnapshot(
            positionMillis = positionValue,
            durationMillis = durationMillis,
        )
    }

    override suspend fun loadAllPending(): List<LocalPlaybackPosition> = withContext(Dispatchers.IO) {
        prefs.all.entries.mapNotNull { (key, _) ->
            parsePositionKey(key)
        }.mapNotNull { position ->
            val snapshot = loadLocal(position.movieId, position.episodeId) ?: return@mapNotNull null
            LocalPlaybackPosition(
                movieId = position.movieId,
                episodeId = position.episodeId,
                positionMillis = snapshot.positionMillis,
                durationMillis = snapshot.durationMillis,
            )
        }
    }

    override suspend fun clearSynced(positions: Collection<LocalPlaybackPosition>) = withContext(Dispatchers.IO) {
        if (positions.isEmpty()) return@withContext
        prefs.edit {
            positions.forEach { position ->
                remove(PlaybackPositionKeys.key(position.movieId, position.episodeId))
                remove(PlaybackDurationKeys.key(position.movieId, position.episodeId))
            }
        }
    }

    override suspend fun clear(movieId: Int, episodeId: Int) = withContext(Dispatchers.IO) {
        prefs.edit {
            remove(PlaybackPositionKeys.key(movieId, episodeId))
            remove(PlaybackDurationKeys.key(movieId, episodeId))
        }
    }

    private fun loadLocal(movieId: Int, episodeId: Int): PlaybackProgressSnapshot? {
        val positionValue = prefs.getLong(PlaybackPositionKeys.key(movieId, episodeId), Long.MIN_VALUE)
        if (positionValue == Long.MIN_VALUE || positionValue < 0) return null
        val durationValue = prefs.getLong(PlaybackDurationKeys.key(movieId, episodeId), Long.MIN_VALUE)
        val durationMillis = if (durationValue == Long.MIN_VALUE || durationValue < 0) 0L else durationValue
        return PlaybackProgressSnapshot(
            positionMillis = positionValue,
            durationMillis = durationMillis,
        )
    }

    private fun parsePositionKey(key: String): LocalPlaybackPosition? {
        if (!key.startsWith("$PLAYBACK_POSITION_PREFIX:")) return null
        val parts = key.split(":")
        if (parts.size != 3) return null
        val movieId = parts[1].toIntOrNull() ?: return null
        val episodeId = parts[2].toIntOrNull() ?: return null
        val snapshot = loadLocal(movieId, episodeId) ?: return null
        return LocalPlaybackPosition(
            movieId = movieId,
            episodeId = episodeId,
            positionMillis = snapshot.positionMillis,
            durationMillis = snapshot.durationMillis,
        )
    }
}
