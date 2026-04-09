package com.motchill.androidcompose.feature.detail

import com.motchill.androidcompose.domain.model.MovieDetail

enum class DetailSectionTab {
    episodes,
    synopsis,
    information,
    classification,
    gallery,
    related,
}

val DetailSectionTab.label: String
    get() = when (this) {
        DetailSectionTab.episodes -> "Episodes"
        DetailSectionTab.synopsis -> "Synopsis"
        DetailSectionTab.information -> "Information"
        DetailSectionTab.classification -> "Classification"
        DetailSectionTab.gallery -> "Gallery"
        DetailSectionTab.related -> "Related"
    }

data class DetailUiState(
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
    val detail: MovieDetail? = null,
    val selectedTab: DetailSectionTab? = null,
    val isLiked: Boolean = false,
) {
    val availableTabs: List<DetailSectionTab>
        get() = detail?.availableTabs.orEmpty()

    val effectiveSelectedTab: DetailSectionTab
        get() = selectedTab?.takeIf { it in availableTabs }
            ?: detail?.let(::defaultDetailTab)
            ?: DetailSectionTab.synopsis
}

val MovieDetail.availableTabs: List<DetailSectionTab>
    get() {
        val tabs = mutableListOf<DetailSectionTab>()
        if (episodes.isNotEmpty()) tabs += DetailSectionTab.episodes
        if (description.trim().isNotEmpty()) tabs += DetailSectionTab.synopsis
        if (hasInformation()) tabs += DetailSectionTab.information
        if (countries.isNotEmpty() || categories.isNotEmpty()) {
            tabs += DetailSectionTab.classification
        }
        if (photoUrls.isNotEmpty() || previewPhotoUrls.isNotEmpty()) {
            tabs += DetailSectionTab.gallery
        }
        if (relatedMovies.isNotEmpty()) tabs += DetailSectionTab.related
        return tabs
    }

fun defaultDetailTab(detail: MovieDetail): DetailSectionTab {
    val tabs = detail.availableTabs
    if (tabs.isEmpty()) return DetailSectionTab.synopsis
    if (DetailSectionTab.episodes in tabs) return DetailSectionTab.episodes
    return tabs.first()
}

private fun MovieDetail.hasInformation(): Boolean {
    return director.trim().isNotEmpty() ||
        castString.trim().isNotEmpty() ||
        showTimes.trim().isNotEmpty() ||
        moreInfo.trim().isNotEmpty() ||
        trailer.trim().isNotEmpty() ||
        statusRaw.trim().isNotEmpty() ||
        statusText.trim().isNotEmpty()
}

