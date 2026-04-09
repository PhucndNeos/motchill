package com.motchill.androidcompose.core.navigation

import android.net.Uri

object AppRoutes {
    fun detail(slug: String): String = "detail/${Uri.encode(slug)}"

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

    fun search(slug: String = "", likedOnly: Boolean = false): String {
        return "search?slug=${Uri.encode(slug)}&likedOnly=$likedOnly"
    }
}
