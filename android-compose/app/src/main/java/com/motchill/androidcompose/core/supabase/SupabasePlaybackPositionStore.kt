package com.motchill.androidcompose.core.supabase

import com.motchill.androidcompose.core.storage.LocalPlaybackPosition
import com.motchill.androidcompose.core.storage.PlaybackProgressSnapshot

class SupabasePlaybackPositionStore(
    private val client: SupabaseRestClient,
    private val authSessionProvider: AuthSessionProvider,
) : PlaybackPositionRemoteStore {
    override suspend fun load(movieId: Int, episodeId: Int): PlaybackProgressSnapshot? {
        val user = authSessionProvider.userId ?: return null
        val accessToken = authSessionProvider.accessToken ?: return null
        return client.loadPlaybackPosition(user, accessToken, movieId, episodeId)
    }

    override suspend fun save(
        movieId: Int,
        episodeId: Int,
        positionMillis: Long,
        durationMillis: Long,
    ) {
        val user = authSessionProvider.userId ?: return
        val accessToken = authSessionProvider.accessToken ?: return
        val local = PlaybackProgressSnapshot(positionMillis = positionMillis, durationMillis = durationMillis)
        val remote = client.loadPlaybackPosition(user, accessToken, movieId, episodeId)
        if (!shouldWriteRemote(local, remote)) return
        client.upsertPlaybackPosition(
            userId = user,
            accessToken = accessToken,
            row = PlaybackPositionRow(
                userId = user,
                movieId = movieId,
                episodeId = episodeId,
                positionMillis = positionMillis.coerceAtLeast(0L),
                durationMillis = durationMillis.coerceAtLeast(0L),
            ),
        )
    }

    override suspend fun importLegacyPositions(positions: List<LocalPlaybackPosition>) {
        if (positions.isEmpty()) return
        val user = authSessionProvider.userId ?: return
        val accessToken = authSessionProvider.accessToken ?: return
        client.upsertPlaybackPositions(
            userId = user,
            accessToken = accessToken,
            rows = positions.map {
                PlaybackPositionRow(
                    userId = user,
                    movieId = it.movieId,
                    episodeId = it.episodeId,
                    positionMillis = it.positionMillis.coerceAtLeast(0L),
                    durationMillis = it.durationMillis.coerceAtLeast(0L),
                )
            },
        )
    }

    companion object {
        fun shouldWriteRemote(
            local: PlaybackProgressSnapshot,
            remote: PlaybackProgressSnapshot?,
        ): Boolean {
            if (remote == null) return true
            return when {
                local.positionMillis > remote.positionMillis -> true
                local.positionMillis < remote.positionMillis -> false
                local.durationMillis > remote.durationMillis -> true
                else -> false
            }
        }
    }
}
