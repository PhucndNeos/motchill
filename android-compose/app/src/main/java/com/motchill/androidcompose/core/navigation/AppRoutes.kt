package com.motchill.androidcompose.core.navigation

import android.net.Uri

object AppRoutes {
    fun detail(slug: String): String = "detail/${Uri.encode(slug)}"
    fun auth(): String = "auth"
    fun account(): String = "account"

    fun play(
        movieId: Int,
        episodeId: Int,
        movieTitle: String = "",
        episodeLabel: String = "",
    ): String {
        return "play/$movieId/$episodeId?movieTitle=${Uri.encode(movieTitle)}&episodeLabel=${
            Uri.encode(episodeLabel)
        }"
    }

    fun search(
        q: String = "",
        slug: String = "",
        label: String = "",
        likedOnly: Boolean = false,
        favorite: Boolean = false,
        mode: String = "",
    ): String {
        return "search?q=${Uri.encode(q)}&slug=${Uri.encode(slug)}&label=${
            Uri.encode(label)
        }&likedOnly=$likedOnly&favorite=$favorite&mode=${Uri.encode(mode)}"
    }
}
