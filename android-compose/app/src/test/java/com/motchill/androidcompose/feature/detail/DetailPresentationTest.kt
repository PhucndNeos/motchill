package com.motchill.androidcompose.feature.detail

import com.motchill.androidcompose.domain.model.MovieCard
import com.motchill.androidcompose.domain.model.MovieDetail
import com.motchill.androidcompose.domain.model.MovieEpisode
import com.motchill.androidcompose.domain.model.SimpleLabel
import org.junit.Assert.assertEquals
import org.junit.Test

class DetailPresentationTest {
    @Test
    fun `available tabs include sections in flutter order`() {
        val detail = detail(
            episodes = listOf(episode()),
            description = "Synopsis",
            director = "Director",
            countries = listOf(label("VN")),
            categories = listOf(label("Action")),
            photos = listOf("photo-1"),
            related = listOf(movie(2)),
        )

        assertEquals(
            listOf(
                DetailSectionTab.episodes,
                DetailSectionTab.synopsis,
                DetailSectionTab.information,
                DetailSectionTab.classification,
                DetailSectionTab.gallery,
                DetailSectionTab.related,
            ),
            detail.availableTabs,
        )
    }

    @Test
    fun `default detail tab prefers episodes when available`() {
        val detail = detail(episodes = listOf(episode()))

        assertEquals(DetailSectionTab.episodes, defaultDetailTab(detail))
    }

    @Test
    fun `default detail tab falls back to synopsis when no episodes exist`() {
        val detail = detail(description = "Synopsis")

        assertEquals(DetailSectionTab.synopsis, defaultDetailTab(detail))
    }

    private fun detail(
        episodes: List<MovieEpisode> = emptyList(),
        description: String = "",
        director: String = "",
        countries: List<SimpleLabel> = emptyList(),
        categories: List<SimpleLabel> = emptyList(),
        photos: List<String> = emptyList(),
        related: List<MovieCard> = emptyList(),
    ) = MovieDetail(
        movie = movie(
            1,
            description = description,
            director = director,
            countries = countries,
            categories = categories,
            photos = photos,
        ),
        relatedMovies = related,
        countries = countries,
        categories = categories,
        episodes = episodes,
    )

    private fun movie(
        id: Int,
        description: String = "",
        director: String = "",
        countries: List<SimpleLabel> = emptyList(),
        categories: List<SimpleLabel> = emptyList(),
        photos: List<String> = emptyList(),
    ) = MovieCard(
        id = id,
        name = "Movie $id",
        otherName = "",
        avatar = "",
        bannerThumb = "",
        avatarThumb = "",
        description = description,
        banner = "",
        imageIcon = "",
        link = "movie-$id",
        quantity = "",
        rating = "",
        year = 2024,
        statusTitle = "",
        director = director,
        photoUrls = photos,
        previewPhotoUrls = photos,
    )

    private fun episode() = MovieEpisode(
        id = 1,
        episodeNumber = 1,
        name = "Episode 1",
        fullLink = "https://example.com",
        status = null,
        type = "mp4",
    )

    private fun label(name: String) = SimpleLabel(
        id = name.hashCode(),
        name = name,
        link = name.lowercase(),
        displayColumn = 1,
    )
}

