package com.motchill.androidcompose.core.network

import com.motchill.androidcompose.core.config.ApiConfig
import com.motchill.androidcompose.data.remote.toHomeSection
import com.motchill.androidcompose.data.remote.toMovieDetail
import com.motchill.androidcompose.data.remote.toNavbarItem
import com.motchill.androidcompose.data.remote.toPopupAdConfig
import com.motchill.androidcompose.data.remote.toSearchFilterData
import com.motchill.androidcompose.data.remote.toSearchResults
import com.motchill.androidcompose.domain.model.HomeSection
import com.motchill.androidcompose.domain.model.MovieDetail
import com.motchill.androidcompose.domain.model.NavbarItem
import com.motchill.androidcompose.domain.model.PopupAdConfig
import com.motchill.androidcompose.domain.model.SearchFilterData
import com.motchill.androidcompose.domain.model.SearchResults
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

class MotchillApiClient(
    private val client: OkHttpClient = defaultClient(),
    private val baseUrlProvider: () -> String = { ApiConfig.baseUrl },
) {
    suspend fun fetchHomeSections(): List<HomeSection> {
        return getJsonArray("/api/moviehomepage").map { it.toHomeSection() }
    }

    suspend fun fetchNavbar(): List<NavbarItem> {
        return getJsonArray("/api/navbar").map { it.toNavbarItem() }
    }

    suspend fun fetchMovieDetail(slug: String): MovieDetail {
        return getJsonObject("/api/movie/${slug.encodePathSegment()}").toMovieDetail()
    }

    suspend fun fetchMoviePreview(slug: String): MovieDetail {
        return getJsonObject("/api/movie/preview/${slug.encodePathSegment()}").toMovieDetail()
    }

    suspend fun fetchSearchFilters(): SearchFilterData {
        return getJsonObject("/api/filter").toSearchFilterData()
    }

    suspend fun fetchSearchResults(
        categoryId: Int? = null,
        countryId: Int? = null,
        typeRaw: String = "",
        year: String = "",
        orderBy: String = "UpdateOn",
        isChieuRap: Boolean = false,
        is4k: Boolean = false,
        search: String = "",
        pageNumber: Int = 1,
    ): SearchResults {
        val payload = getText(
            "/api/search",
            mapOf(
                "categoryId" to categoryId?.toString().orEmpty(),
                "countryId" to countryId?.toString().orEmpty(),
                "typeRaw" to typeRaw,
                "year" to year,
                "orderBy" to orderBy,
                "isChieuRap" to isChieuRap.toString(),
                "is4k" to is4k.toString(),
                "search" to search,
                "pageNumber" to pageNumber.toString(),
            ),
        )
        return com.motchill.androidcompose.core.security.MotchillPayloadCipher.decodeJsonObject(payload).toSearchResults()
    }

    suspend fun fetchEpisodeSourcesPayload(
        movieId: Int,
        episodeId: Int,
        server: Int = 0,
    ): String {
        return getText(
            "/api/play/get",
            mapOf(
                "movieId" to movieId.toString(),
                "episodeId" to episodeId.toString(),
                "server" to server.toString(),
            ),
        )
    }

    suspend fun fetchPopupAd(): PopupAdConfig? {
        val text = getText("/api/ads/popup")
        val trimmed = text.trim()
        if (trimmed.isEmpty() || trimmed[0] != '{') return null
        return JSONObject(trimmed).toPopupAdConfig()
    }

    private suspend fun getJsonArray(path: String): List<JSONObject> {
        val text = getText(path)
        val array = JSONArray(text)
        return buildList(array.length()) {
            for (index in 0 until array.length()) {
                val item = array.opt(index)
                if (item is JSONObject) {
                    add(item)
                } else if (item is Map<*, *>) {
                    @Suppress("UNCHECKED_CAST")
                    add(JSONObject(item as Map<String, Any?>))
                }
            }
        }
    }

    private suspend fun getJsonObject(path: String): JSONObject {
        val text = getText(path)
        return JSONObject(text)
    }

    private suspend fun getText(
        path: String,
        query: Map<String, String>? = null,
    ): String = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(buildUrl(path, query))
            .headers(
                okhttp3.Headers.headersOf(
                    *ApiConfig.headers()
                        .flatMap { listOf(it.key, it.value) }
                        .toTypedArray(),
                ),
            )
            .get()
            .build()

        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                throw IOException("HTTP ${response.code} for ${response.request.url}")
            }
            response.body?.string().orEmpty()
        }
    }

    private fun buildUrl(path: String, query: Map<String, String>?): String {
        val normalizedBaseUrl = baseUrlProvider().trimEnd('/')
        val url = "$normalizedBaseUrl$path".toHttpUrl().newBuilder()
        query?.forEach { (key, value) ->
            if (value.isNotEmpty()) {
                url.addQueryParameter(key, value)
            } else {
                url.addQueryParameter(key, "")
            }
        }
        return url.build().toString()
    }

    private fun String.encodePathSegment(): String {
        return java.net.URLEncoder.encode(this, Charsets.UTF_8.name())
    }

    companion object {
        fun defaultClient(): OkHttpClient {
            return OkHttpClient.Builder()
                .callTimeout(ApiConfig.requestTimeoutMillis, TimeUnit.MILLISECONDS)
                .connectTimeout(ApiConfig.requestTimeoutMillis, TimeUnit.MILLISECONDS)
                .readTimeout(ApiConfig.requestTimeoutMillis, TimeUnit.MILLISECONDS)
                .writeTimeout(ApiConfig.requestTimeoutMillis, TimeUnit.MILLISECONDS)
                .build()
        }
    }
}
