package com.motchill.androidcompose.feature.home

import com.motchill.androidcompose.domain.model.HomeSection
import com.motchill.androidcompose.domain.model.MovieCard
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HomePresentationTest {
    @Test
    fun `slide section prefers explicit slide key`() {
        val sections = listOf(
            section(key = "action", title = "Action"),
            section(key = "slide", title = "Hero"),
        )

        assertEquals("slide", slideSection(sections)?.key)
    }

    @Test
    fun `content sections exclude slide key only`() {
        val sections = listOf(
            section(key = "slide", title = "Hero"),
            section(key = "drama", title = "Drama"),
        )

        assertEquals(listOf("drama"), contentSections(sections).map { it.key })
    }

    @Test
    fun `section slug normalizes title when key is empty`() {
        val slug = sectionSearchSlug(
            section(key = "", title = "Coming Soon 2024"),
        )

        assertEquals("coming-soon-2024", slug)
    }

    @Test
    fun `home ui state derives hero movies from slide section`() {
        val slideMovie = movie(id = 1)
        val otherMovie = movie(id = 2)
        val state = HomeUiState(
            sections = listOf(
                section(key = "slide", title = "Hero", movies = listOf(slideMovie)),
                section(key = "drama", title = "Drama", movies = listOf(otherMovie)),
            ),
        )

        assertEquals(listOf(slideMovie), state.heroMovies)
        assertEquals(slideMovie, state.selectedMovie)
        assertTrue(state.previewMovies.isEmpty())
    }

    private fun section(
        key: String,
        title: String,
        movies: List<MovieCard> = emptyList(),
    ) = HomeSection(
        title = title,
        key = key,
        products = movies,
        isCarousel = false,
    )

    private fun movie(id: Int) = MovieCard(
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
}
