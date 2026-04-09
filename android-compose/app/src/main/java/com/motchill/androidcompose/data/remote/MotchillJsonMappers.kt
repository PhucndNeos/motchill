package com.motchill.androidcompose.data.remote

import com.motchill.androidcompose.domain.model.HomeSection
import com.motchill.androidcompose.domain.model.MovieCard
import com.motchill.androidcompose.domain.model.MovieDetail
import com.motchill.androidcompose.domain.model.MovieEpisode
import com.motchill.androidcompose.domain.model.NavbarItem
import com.motchill.androidcompose.domain.model.PlaySource
import com.motchill.androidcompose.domain.model.PlayTrack
import com.motchill.androidcompose.domain.model.PopupAdConfig
import com.motchill.androidcompose.domain.model.SearchFacetOption
import com.motchill.androidcompose.domain.model.SearchFilterData
import com.motchill.androidcompose.domain.model.SearchPagination
import com.motchill.androidcompose.domain.model.SearchResults
import com.motchill.androidcompose.domain.model.SimpleLabel
import org.json.JSONArray
import org.json.JSONObject

internal fun JSONObject.toHomeSection(): HomeSection {
    return HomeSection(
        title = stringValue("Title"),
        key = stringValue("Key"),
        products = jsonArray("Products").toMovieCardList(),
        isCarousel = booleanValue("IsCarousel"),
    )
}

internal fun JSONObject.toMovieCard(): MovieCard {
    return MovieCard(
        id = intValue("Id"),
        name = stringValue("Name"),
        otherName = stringValue("OtherName"),
        avatar = stringValue("Avatar"),
        bannerThumb = stringValue("BannerThumb"),
        avatarThumb = stringValue("AvatarThumb"),
        description = stringValue("Description"),
        banner = stringValue("Banner"),
        imageIcon = stringValue("ImageIcon"),
        link = stringValue("Link"),
        quantity = stringValue("Quanlity"),
        rating = stringValue("Rating"),
        year = intValue("Year"),
        statusTitle = stringValue("StatusTitle"),
        statusRaw = stringValue("StatusRaw"),
        statusText = stringValue("StatusTMText"),
        director = stringValue("Director"),
        time = stringValue("Time"),
        trailer = stringValue("Trailer"),
        showTimes = stringValue("ShowTimes"),
        moreInfo = stringValue("MoreInfo"),
        castString = stringValue("CastString"),
        episodesTotal = intValue("EpisodesTotal"),
        viewNumber = intValue("ViewNumber"),
        ratePoint = doubleValue("RatePoint"),
        photoUrls = stringList("Photos"),
        previewPhotoUrls = stringList("PreviewPhotos"),
    )
}

internal fun JSONObject.toNavbarItem(): NavbarItem {
    return NavbarItem(
        id = intValue("Id"),
        name = stringValue("Name"),
        slug = stringValue("Slug"),
        items = jsonArray("Items").toNavbarList(),
        isExistChild = booleanValue("IsExistChild"),
    )
}

internal fun JSONObject.toPopupAdConfig(): PopupAdConfig {
    return PopupAdConfig(
        id = intValue("Id"),
        name = stringValue("Name"),
        type = stringValue("Type"),
        desktopLink = stringValue("DesktopLink"),
        mobileLink = stringValue("MobileLink"),
    )
}

internal fun JSONObject.toSimpleLabel(): SimpleLabel {
    return SimpleLabel(
        id = intValue("Id"),
        name = stringValue("Name"),
        link = stringValue("Link"),
        displayColumn = intValue("DisplayColumn"),
    )
}

internal fun JSONObject.toMovieEpisode(): MovieEpisode {
    return MovieEpisode(
        id = intValue("Id"),
        episodeNumber = opt("EpisodeNumber"),
        name = stringValue("Name"),
        fullLink = stringValue("FullLink"),
        status = opt("Status"),
        type = stringValue("Type"),
    )
}

internal fun JSONObject.toMovieDetail(): MovieDetail {
    val movieObject = optJSONObject("movie") ?: JSONObject()
    return MovieDetail(
        movie = movieObject.toMovieCard(),
        relatedMovies = jsonArray("relatedMovies").toMovieCardList(),
        countries = movieObject.jsonArray("Countries").toSimpleLabelList(),
        categories = movieObject.jsonArray("Categories").toSimpleLabelList(),
        episodes = movieObject.jsonArray("Episodes").toMovieEpisodeList(),
    )
}

internal fun JSONObject.toSearchFilterData(): SearchFilterData {
    return SearchFilterData(
        categories = jsonArray("categories").toSearchFacetList(),
        countries = jsonArray("countries").toSearchFacetList(),
    )
}

internal fun JSONObject.toSearchResults(): SearchResults {
    return SearchResults(
        records = jsonArray("Records").toMovieCardList(),
        pagination = optJSONObject("Pagination")
            ?.toSearchPagination()
            ?: SearchPagination(
                pageIndex = 0,
                pageSize = 0,
                pageCount = 0,
                totalRecords = 0,
            ),
    )
}

internal fun JSONObject.toSearchPagination(): SearchPagination {
    return SearchPagination(
        pageIndex = intValue("PageIndex"),
        pageSize = intValue("PageSize"),
        pageCount = intValue("PageCount"),
        totalRecords = intValue("TotalRecords"),
    )
}

internal fun JSONObject.toPlaySource(): PlaySource {
    return PlaySource(
        sourceId = intValue("SourceId"),
        serverName = stringValue("ServerName"),
        link = stringValue("Link"),
        subtitle = stringValue("Subtitle"),
        type = intValue("Type"),
        isFrame = booleanValue("IsFrame"),
        quality = stringValue("Quality"),
        tracks = jsonArray("Tracks").toPlayTrackList(),
    )
}

internal fun JSONArray.toMovieCardList(): List<MovieCard> = mapObjects { it.toMovieCard() }

internal fun JSONArray.toNavbarList(): List<NavbarItem> = mapObjects { it.toNavbarItem() }

internal fun JSONArray.toSimpleLabelList(): List<SimpleLabel> = mapObjects { it.toSimpleLabel() }

internal fun JSONArray.toMovieEpisodeList(): List<MovieEpisode> = mapObjects { it.toMovieEpisode() }

internal fun JSONArray.toSearchFacetList(): List<SearchFacetOption> = mapObjects {
    SearchFacetOption(
        id = it.intValue("Id"),
        name = it.stringValue("Name"),
        slug = it.stringValue("Slug"),
    )
}

internal fun JSONArray.toPlayTrackList(): List<PlayTrack> = mapObjects {
    PlayTrack(
        kind = it.stringValue("kind"),
        file = it.stringValue("file"),
        label = it.stringValue("label"),
        isDefault = it.booleanValue("default"),
    )
}

internal inline fun <T> JSONArray.mapObjects(transform: (JSONObject) -> T): List<T> {
    return buildList(length()) {
        for (index in 0 until length()) {
            val element = opt(index)
            if (element is JSONObject) {
                add(transform(element))
            } else if (element is Map<*, *>) {
                @Suppress("UNCHECKED_CAST")
                add(transform(JSONObject(element as Map<String, Any?>)))
            }
        }
    }
}

internal fun JSONObject.jsonArray(name: String): JSONArray {
    return optJSONArray(name) ?: JSONArray()
}

internal fun JSONObject.stringValue(name: String): String {
    val value = opt(name)
    return when (value) {
        null -> ""
        JSONObject.NULL -> ""
        else -> value.toString()
    }
}

internal fun JSONObject.intValue(name: String): Int {
    val value = opt(name)
    return when (value) {
        is Int -> value
        is Number -> value.toInt()
        null, JSONObject.NULL -> 0
        else -> value.toString().toIntOrNull() ?: 0
    }
}

internal fun JSONObject.doubleValue(name: String): Double {
    val value = opt(name)
    return when (value) {
        is Double -> value
        is Number -> value.toDouble()
        null, JSONObject.NULL -> 0.0
        else -> value.toString().toDoubleOrNull() ?: 0.0
    }
}

internal fun JSONObject.booleanValue(name: String): Boolean {
    val value = opt(name)
    return when (value) {
        is Boolean -> value
        is Number -> value.toInt() != 0
        null, JSONObject.NULL -> false
        else -> value.toString().toBooleanStrictOrNull() ?: value.toString() == "1"
    }
}

internal fun JSONObject.stringList(name: String): List<String> {
    val raw = optJSONArray(name) ?: return emptyList()
    return buildList(raw.length()) {
        for (index in 0 until raw.length()) {
            val value = raw.opt(index)?.toString().orEmpty()
            if (value.isNotBlank()) {
                add(value)
            }
        }
    }
}
