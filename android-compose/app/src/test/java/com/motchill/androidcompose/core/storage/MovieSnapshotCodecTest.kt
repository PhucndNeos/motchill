package com.motchill.androidcompose.core.storage

import com.motchill.androidcompose.domain.model.MovieCard
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MovieSnapshotCodecTest {
    @Test
    fun roundTripsMovieSnapshots() {
        val movies = listOf(
            MovieCard(
                id = 42,
                name = "Oppenheimer",
                otherName = "Oppenheimer (2023)",
                avatar = "avatar",
                bannerThumb = "banner-thumb",
                avatarThumb = "avatar-thumb",
                description = "Biography drama",
                banner = "banner",
                imageIcon = "icon",
                link = "/movie/oppenheimer",
                quantity = "HD",
                rating = "8.8",
                year = 2023,
                statusTitle = "Completed",
                statusRaw = "completed",
                statusText = "Ended",
                director = "Christopher Nolan",
                time = "180m",
                trailer = "https://example.com/trailer",
                showTimes = "Now showing",
                moreInfo = "More info",
                castString = "Cillian Murphy",
                episodesTotal = 1,
                viewNumber = 1000,
                ratePoint = 8.8,
                photoUrls = listOf("photo-1", "photo-2"),
                previewPhotoUrls = listOf("preview-1"),
            ),
        )

        val decoded = MovieSnapshotCodec.decodeMovies(MovieSnapshotCodec.encodeMovies(movies))

        assertEquals(1, decoded.size)
        assertEquals(movies.first(), decoded.first())
    }

    @Test
    fun generatesStablePlaybackPositionKey() {
        assertEquals("player_position:7:9", PlaybackPositionKeys.key(7, 9))
        assertTrue(PlaybackPositionKeys.key(7, 9).contains(":"))
    }
}

