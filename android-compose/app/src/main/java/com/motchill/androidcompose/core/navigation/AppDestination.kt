package com.motchill.androidcompose.core.navigation

sealed class AppDestination(val route: String) {
    data object Home : AppDestination("home")
    data object Search : AppDestination("search")
    data object Category : AppDestination("category/{slug}")
    data object Detail : AppDestination("detail/{slug}")
    data object Player : AppDestination("play/{movieId}/{episodeId}?movieTitle={movieTitle}&episodeLabel={episodeLabel}")
}
