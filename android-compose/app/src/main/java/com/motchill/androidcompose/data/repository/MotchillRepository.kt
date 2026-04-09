package com.motchill.androidcompose.data.repository

import com.motchill.androidcompose.domain.model.HomeSection
import com.motchill.androidcompose.domain.model.MovieDetail
import com.motchill.androidcompose.domain.model.NavbarItem
import com.motchill.androidcompose.domain.model.PlaySource
import com.motchill.androidcompose.domain.model.PopupAdConfig
import com.motchill.androidcompose.domain.model.SearchFilterData
import com.motchill.androidcompose.domain.model.SearchResults

interface MotchillRepository {
    suspend fun loadHome(): List<HomeSection>
    suspend fun loadNavbar(): List<NavbarItem>
    suspend fun loadDetail(slug: String): MovieDetail
    suspend fun loadPreview(slug: String): MovieDetail
    suspend fun loadSearchFilters(): SearchFilterData
    suspend fun loadSearchResults(
        categoryId: Int? = null,
        countryId: Int? = null,
        typeRaw: String = "",
        year: String = "",
        orderBy: String = "UpdateOn",
        isChieuRap: Boolean = false,
        is4k: Boolean = false,
        search: String = "",
        pageNumber: Int = 1,
    ): SearchResults

    suspend fun loadEpisodeSources(
        movieId: Int,
        episodeId: Int,
        server: Int = 0,
    ): List<PlaySource>

    suspend fun loadPopupAd(): PopupAdConfig?
}

