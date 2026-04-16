package com.motchill.androidcompose.core.supabase

import com.motchill.androidcompose.core.storage.LocalPlaybackPosition
import com.motchill.androidcompose.domain.model.MovieCard

class DefaultSyncCoordinator(
    private val localLikedMovieStore: LikedMovieLocalStore,
    private val remoteLikedMovieStore: LikedMovieRemoteStore,
    private val localPlaybackStore: PlaybackPositionLocalStore,
    private val remotePlaybackStore: PlaybackPositionRemoteStore,
) : SyncCoordinator {
    override suspend fun runMigrationIfNeeded() {
        runCatching {
            val pending = localLikedMovieStore.loadMovies()
            if (pending.isNotEmpty()) {
                remoteLikedMovieStore.importLegacyMovies(pending)
                localLikedMovieStore.clearAll()
            }
        }

        runCatching {
            val pending = localPlaybackStore.loadAllPending()
            if (pending.isNotEmpty()) {
                remotePlaybackStore.importLegacyPositions(pending)
                localPlaybackStore.clearSynced(pending)
            }
        }
    }

    override suspend fun syncPlaybackProgress(movieId: Int, episodeId: Int, posMs: Long, durMs: Long) {
        runCatching {
            remotePlaybackStore.save(movieId, episodeId, posMs.coerceAtLeast(0L), durMs.coerceAtLeast(0L))
            localPlaybackStore.clear(movieId, episodeId)
        }
    }
}
