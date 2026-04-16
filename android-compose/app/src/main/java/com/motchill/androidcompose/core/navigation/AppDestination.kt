package com.motchill.androidcompose.core.navigation

sealed class AppDestination(val route: String) {
    data object Home : AppDestination("home")
    data object Search : AppDestination(
        "search?q={q}&slug={slug}&label={label}&likedOnly={likedOnly}&favorite={favorite}&mode={mode}",
    )
    data object Auth : AppDestination("auth")
    data object Account : AppDestination("account")
    data object Detail : AppDestination("detail/{slug}")
    data object Player : AppDestination("play/{movieId}/{episodeId}?movieTitle={movieTitle}&episodeLabel={episodeLabel}")
}
