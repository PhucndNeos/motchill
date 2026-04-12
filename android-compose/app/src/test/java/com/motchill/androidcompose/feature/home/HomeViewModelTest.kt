package com.motchill.androidcompose.feature.home

import com.motchill.androidcompose.data.repository.MotchillRepository
import com.motchill.androidcompose.domain.model.HomeSection
import com.motchill.androidcompose.domain.model.MovieCard
import com.motchill.androidcompose.domain.model.NavbarItem
import com.motchill.androidcompose.domain.model.PlaySource
import com.motchill.androidcompose.domain.model.PopupAdConfig
import com.motchill.androidcompose.domain.model.SearchFilterData
import com.motchill.androidcompose.domain.model.SearchResults
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestCoroutineScheduler
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertNull
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModelTest {
    @After
    fun tearDown() {
        runCatching {
            Dispatchers.resetMain()
        }
    }

    @Test
    fun remoteConfigFailureShowsErrorAndSkipsRepositoryCalls() = runTest {
        withMainDispatcher(testScheduler) {
            val repo = RecordingRepository()
            val viewModel = HomeViewModel(
                repository = repo,
                remoteConfigLoader = { throw IOException("config down") },
            )

            advanceUntilIdle()

            val state = viewModel.uiState.value
            assertFalse(state.isLoading)
            assertEquals("Failed to load remote config: config down", state.errorMessage)
            assertTrue(repo.homeCalls == 0)
            assertTrue(repo.popupCalls == 0)
        }
    }

    @Test
    fun retryRunsConfigAndHomeLoadingAgain() = runTest {
        withMainDispatcher(testScheduler) {
            var remoteConfigCalls = 0
            val repo = RecordingRepository()
            val viewModel = HomeViewModel(
                repository = repo,
                remoteConfigLoader = {
                    remoteConfigCalls++
                    if (remoteConfigCalls == 1) {
                        throw IOException("config down")
                    }
                },
            )

            advanceUntilIdle()
            assertEquals("Failed to load remote config: config down", viewModel.uiState.value.errorMessage)
            assertEquals(0, repo.homeCalls)

            viewModel.refresh()
            advanceUntilIdle()

            val state = viewModel.uiState.value
            assertFalse(state.isLoading)
            assertNull(state.errorMessage)
            assertEquals(1, repo.homeCalls)
            assertEquals(1, repo.popupCalls)
            assertEquals("Featured", state.sections.first().title)
            assertEquals("Weekend Picks", state.popupAdTitle)
        }
    }

    @Test
    fun successPathLoadsHomeAndPopup() = runTest {
        withMainDispatcher(testScheduler) {
            val repo = RecordingRepository()
            val viewModel = HomeViewModel(
                repository = repo,
                remoteConfigLoader = {},
            )

            advanceUntilIdle()

            val state = viewModel.uiState.value
            assertFalse(state.isLoading)
            assertNull(state.errorMessage)
            assertEquals(1, repo.homeCalls)
            assertEquals(1, repo.popupCalls)
            assertEquals(1, state.sections.size)
            assertEquals("Featured", state.sections.first().title)
            assertEquals("Weekend Picks", state.popupAdTitle)
        }
    }

    private suspend fun withMainDispatcher(
        testScheduler: TestCoroutineScheduler,
        block: suspend () -> Unit,
    ) {
        val mainDispatcher = StandardTestDispatcher(testScheduler)
        Dispatchers.setMain(mainDispatcher)
        try {
            block()
        } finally {
            Dispatchers.resetMain()
        }
    }

    private class RecordingRepository : MotchillRepository {
        var homeCalls = 0
        var popupCalls = 0

        override suspend fun loadHome(): List<HomeSection> {
            homeCalls++
            return listOf(
                HomeSection(
                    title = "Featured",
                    key = "featured",
                    products = listOf(testMovie(1)),
                    isCarousel = true,
                ),
            )
        }

        override suspend fun loadNavbar(): List<NavbarItem> {
            error("Not used")
        }

        override suspend fun loadDetail(slug: String) = error("Not used")

        override suspend fun loadPreview(slug: String) = error("Not used")

        override suspend fun loadSearchFilters(): SearchFilterData = error("Not used")

        override suspend fun loadSearchResults(
            categoryId: Int?,
            countryId: Int?,
            typeRaw: String,
            year: String,
            orderBy: String,
            isChieuRap: Boolean,
            is4k: Boolean,
            search: String,
            pageNumber: Int,
        ): SearchResults = error("Not used")

        override suspend fun loadEpisodeSources(
            movieId: Int,
            episodeId: Int,
            server: Int,
        ): List<PlaySource> = error("Not used")

        override suspend fun loadPopupAd(): PopupAdConfig? {
            popupCalls++
            return PopupAdConfig(
                id = 1,
                name = "Weekend Picks",
                type = "popup",
                desktopLink = "",
                mobileLink = "",
            )
        }
    }

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
