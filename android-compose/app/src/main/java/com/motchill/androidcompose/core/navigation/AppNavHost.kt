package com.motchill.androidcompose.core.navigation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.motchill.androidcompose.feature.detail.DetailScreen
import com.motchill.androidcompose.feature.home.HomeRoute
import com.motchill.androidcompose.feature.player.PlayerScreen
import com.motchill.androidcompose.feature.search.SearchScreen

@Composable
fun AppNavHost() {
    val navController = rememberNavController()
    NavHost(
        navController = navController,
        startDestination = AppDestination.Home.route,
        modifier = androidx.compose.ui.Modifier.fillMaxSize(),
    ) {
        composable(AppDestination.Home.route) {
            HomeRoute(
                onOpenSearch = { navController.navigate(AppRoutes.search()) },
                onOpenFavorite = {
                    navController.navigate(AppRoutes.search(likedOnly = true))
                },
                onOpenDetail = { slug ->
                    if (slug.isNotBlank()) {
                        navController.navigate(AppRoutes.detail(slug))
                    }
                },
                onOpenSection = { slug ->
                    if (slug.isBlank()) {
                        navController.navigate(AppRoutes.search())
                    } else {
                        navController.navigate(AppRoutes.search(slug = slug))
                    }
                },
            )
        }
        composable(
            route = "search?slug={slug}&likedOnly={likedOnly}",
            arguments = listOf(
                navArgument("slug") {
                    type = NavType.StringType
                    defaultValue = ""
                },
                navArgument("likedOnly") {
                    type = NavType.BoolType
                    defaultValue = false
                },
            ),
        ) { SearchScreen() }
        composable(AppDestination.Category.route) { SearchScreen() }
        composable(
            route = AppDestination.Detail.route,
            arguments = listOf(
                navArgument("slug") { type = NavType.StringType },
            ),
        ) { entry ->
            DetailScreen(
                slug = entry.requireStringArg("slug"),
                onBack = { navController.popBackStack() },
                onOpenSearch = { navController.navigate(AppRoutes.search()) },
                onOpenDetail = { slug ->
                    if (slug.isNotBlank()) navController.navigate(AppRoutes.detail(slug))
                },
                onOpenEpisode = { movieId, episodeId, movieTitle, episodeLabel ->
                    navController.navigate(
                        AppRoutes.play(
                            movieId = movieId,
                            episodeId = episodeId,
                            movieTitle = movieTitle,
                            episodeLabel = episodeLabel,
                        ),
                    )
                },
            )
        }
        composable(
            route = "play/{movieId}/{episodeId}?movieTitle={movieTitle}&episodeLabel={episodeLabel}",
            arguments = listOf(
                navArgument("movieId") { type = NavType.IntType },
                navArgument("episodeId") { type = NavType.IntType },
                navArgument("movieTitle") {
                    type = NavType.StringType
                    defaultValue = ""
                },
                navArgument("episodeLabel") {
                    type = NavType.StringType
                    defaultValue = ""
                },
            ),
        ) { entry ->
            PlayerScreen(
                movieId = entry.requireIntArg("movieId"),
                episodeId = entry.requireIntArg("episodeId"),
                movieTitle = entry.requireStringArg("movieTitle"),
                episodeLabel = entry.requireStringArg("episodeLabel"),
                onBack = { navController.popBackStack() },
            )
        }
    }
}

private fun NavBackStackEntry.requireStringArg(name: String): String {
    return arguments?.getString(name).orEmpty()
}

private fun NavBackStackEntry.requireIntArg(name: String): Int {
    return arguments?.getInt(name) ?: 0
}
