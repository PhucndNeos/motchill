package com.motchill.androidcompose.core.supabase

import com.motchill.androidcompose.core.storage.LocalPlaybackPosition
import com.motchill.androidcompose.domain.model.MovieCard
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DefaultSyncCoordinatorTest {
    @Test
    fun `failed liked migration does not block playback migration`() = runTest {
        val likedStore = FakeLocalLikedMovieStore(
            movies = listOf(testMovie(1)),
        )
        val playbackStore = FakeLocalPlaybackPositionStore(
            pending = listOf(
                LocalPlaybackPosition(
                    movieId = 2,
                    episodeId = 5,
                    positionMillis = 12_000,
                    durationMillis = 40_000,
                ),
            ),
        )
        val remoteLikedStore = FakeRemoteLikedMovieStore(shouldFailImport = true)
        val remotePlaybackStore = FakeRemotePlaybackPositionStore()

        val coordinator = DefaultSyncCoordinator(
            localLikedMovieStore = likedStore,
            remoteLikedMovieStore = remoteLikedStore,
            localPlaybackStore = playbackStore,
            remotePlaybackStore = remotePlaybackStore,
        )

        coordinator.runMigrationIfNeeded()

        assertEquals(listOf(testMovie(1)), likedStore.movies)
        assertTrue(playbackStore.pending.isEmpty())
        assertEquals(1, remotePlaybackStore.importCalls)
        assertEquals(0, remoteLikedStore.importCalls)
    }

    private fun testMovie(id: Int) = MovieCard(
        id = id,
        name = "Movie $id",
        otherName = "",
        avatar = "",
        bannerThumb = "",
        avatarThumb = "",
        description = "",
        banner = "",
        imageIcon = "",
        link = "movie-$id",
        quantity = "",
        rating = "",
        year = 2024,
        statusTitle = "",
    )

    private class FakeLocalLikedMovieStore(
        var movies: List<MovieCard>,
    ) : LikedMovieLocalStore {
        var clearCalls = 0

        override suspend fun loadMovies(): List<MovieCard> = movies

        override suspend fun clearAll() {
            clearCalls++
            movies = emptyList()
        }
    }

    private class FakeRemoteLikedMovieStore(
        private val shouldFailImport: Boolean = false,
    ) : LikedMovieRemoteStore {
        var importCalls = 0

        override suspend fun loadMovies(): List<MovieCard> = emptyList()

        override suspend fun toggleMovie(movie: MovieCard): List<MovieCard> = listOf(movie)

        override suspend fun importLegacyMovies(movies: List<MovieCard>) {
            if (shouldFailImport) error("boom")
            importCalls++
        }
    }

    private class FakeLocalPlaybackPositionStore(
        var pending: List<LocalPlaybackPosition>,
    ) : PlaybackPositionLocalStore {
        override suspend fun load(movieId: Int, episodeId: Int) = pending.firstOrNull {
            it.movieId == movieId && it.episodeId == episodeId
        }?.let {
            com.motchill.androidcompose.core.storage.PlaybackProgressSnapshot(
                positionMillis = it.positionMillis,
                durationMillis = it.durationMillis,
            )
        }

        override suspend fun loadAllPending(): List<LocalPlaybackPosition> = pending

        override suspend fun clearSynced(positions: Collection<LocalPlaybackPosition>) {
            pending = pending.filterNot { position ->
                positions.any { it.movieId == position.movieId && it.episodeId == position.episodeId }
            }
        }

        override suspend fun clear(movieId: Int, episodeId: Int) {
            pending = pending.filterNot { it.movieId == movieId && it.episodeId == episodeId }
        }
    }

    private class FakeRemotePlaybackPositionStore : PlaybackPositionRemoteStore {
        var importCalls = 0

        override suspend fun load(movieId: Int, episodeId: Int) = null

        override suspend fun save(movieId: Int, episodeId: Int, positionMillis: Long, durationMillis: Long) = Unit

        override suspend fun importLegacyPositions(positions: List<LocalPlaybackPosition>) {
            importCalls++
        }
    }
}
