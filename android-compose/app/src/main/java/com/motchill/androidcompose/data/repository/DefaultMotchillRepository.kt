package com.motchill.androidcompose.data.repository

import com.motchill.androidcompose.core.network.MotchillApiClient
import com.motchill.androidcompose.core.security.MotchillPlayCipher
import com.motchill.androidcompose.domain.model.HomeSection
import com.motchill.androidcompose.domain.model.MovieDetail
import com.motchill.androidcompose.domain.model.NavbarItem
import com.motchill.androidcompose.domain.model.PlaySource
import com.motchill.androidcompose.domain.model.PopupAdConfig
import com.motchill.androidcompose.domain.model.SearchFilterData
import com.motchill.androidcompose.domain.model.SearchResults

class DefaultMotchillRepository(
    private val apiClient: MotchillApiClient,
) : MotchillRepository {
    override suspend fun loadHome(): List<HomeSection> = apiClient.fetchHomeSections()

    override suspend fun loadNavbar(): List<NavbarItem> = apiClient.fetchNavbar()

    override suspend fun loadDetail(slug: String): MovieDetail = apiClient.fetchMovieDetail(slug)

    override suspend fun loadPreview(slug: String): MovieDetail = apiClient.fetchMoviePreview(slug)

    override suspend fun loadSearchFilters(): SearchFilterData = apiClient.fetchSearchFilters()

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
    ): SearchResults {
        return apiClient.fetchSearchResults(
            categoryId = categoryId,
            countryId = countryId,
            typeRaw = typeRaw,
            year = year,
            orderBy = orderBy,
            isChieuRap = isChieuRap,
            is4k = is4k,
            search = search,
            pageNumber = pageNumber,
        )
    }

    override suspend fun loadEpisodeSources(
        movieId: Int,
        episodeId: Int,
        server: Int,
    ): List<PlaySource> {
        val payload = apiClient.fetchEpisodeSourcesPayload(
            movieId = movieId,
            episodeId = episodeId,
            server = server,
        )
        return MotchillPlayCipher.decodeSources(payload)
    }

    override suspend fun loadPopupAd(): PopupAdConfig? = apiClient.fetchPopupAd()
}

