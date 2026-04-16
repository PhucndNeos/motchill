package com.motchill.androidcompose.core.navigation

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import com.motchill.androidcompose.feature.detail.DetailScreen
import com.motchill.androidcompose.feature.home.HomeRoute
import com.motchill.androidcompose.feature.player.PlayerScreen
import com.motchill.androidcompose.feature.search.SearchRoute
import com.motchill.androidcompose.feature.account.AccountScreen
import com.motchill.androidcompose.feature.auth.AuthScreen

@Composable
fun AppNavHost() {
    val navController = rememberNavController()
    NavHost(
        navController = navController,
        startDestination = AppDestination.Home.route,
        modifier = androidx.compose.ui.Modifier.fillMaxSize(),
    ) {
        composable(AppDestination.Home.route) {
            AppSafeDrawingScreen {
                HomeRoute(
                    onOpenSearch = { navController.navigate(AppRoutes.search()) },
                    onOpenFavorite = {
                        navController.navigate(AppRoutes.search(likedOnly = true))
                    },
                    onOpenAccount = {
                        navController.navigate(AppRoutes.account())
                    },
                    onOpenDetail = { slug ->
                        if (slug.isNotBlank()) {
                            navController.navigate(AppRoutes.detail(slug))
                        }
                    },
                    onOpenSection = { slug, label ->
                        if (slug.isBlank()) {
                            navController.navigate(AppRoutes.search())
                        } else {
                            navController.navigate(AppRoutes.search(slug = slug, label = label))
                        }
                    },
                )
            }
        }
        composable(
            route = AppDestination.Search.route,
            arguments = listOf(
                navArgument("q") {
                    type = NavType.StringType
                    defaultValue = ""
                },
                navArgument("slug") {
                    type = NavType.StringType
                    defaultValue = ""
                },
                navArgument("label") {
                    type = NavType.StringType
                    defaultValue = ""
                },
                navArgument("likedOnly") {
                    type = NavType.BoolType
                    defaultValue = false
                },
                navArgument("favorite") {
                    type = NavType.BoolType
                    defaultValue = false
                },
                navArgument("mode") {
                    type = NavType.StringType
                    defaultValue = ""
                },
            ),
        ) { entry ->
            AppSafeDrawingScreen {
                SearchRoute(
                    initialQuery = entry.requireStringArg("q"),
                    presetSlug = entry.requireStringArg("slug"),
                    initialLabel = entry.requireStringArg("label"),
                    startLikedOnly = entry.requireBoolArg("likedOnly") ||
                        entry.requireBoolArg("favorite") ||
                        entry.requireStringArg("mode").equals("favorite", ignoreCase = true),
                    onBack = { navController.popBackStack() },
                    onOpenDetail = { slug ->
                        if (slug.isNotBlank()) navController.navigate(AppRoutes.detail(slug))
                    },
                )
            }
        }
        composable(AppDestination.Auth.route) {
            AppSafeDrawingScreen {
                AuthScreen(
                    onDone = { navController.popBackStack() },
                    onBack = { navController.popBackStack() },
                )
            }
        }
        composable(AppDestination.Account.route) {
            AppSafeDrawingScreen {
                AccountScreen(
                    onOpenAuth = { navController.navigate(AppRoutes.auth()) },
                    onBack = { navController.popBackStack() },
                )
            }
        }
        composable(
            route = AppDestination.Detail.route,
            arguments = listOf(
                navArgument("slug") { type = NavType.StringType },
            ),
        ) { entry ->
            AppSafeDrawingScreen {
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

@Composable
private fun AppSafeDrawingScreen(content: @Composable () -> Unit) {
    Box(
        modifier = androidx.compose.ui.Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing),
    ) {
        content()
    }
}

private fun NavBackStackEntry.requireStringArg(name: String): String {
    return arguments?.getString(name).orEmpty()
}

private fun NavBackStackEntry.requireIntArg(name: String): Int {
    return arguments?.getInt(name) ?: 0
}

private fun NavBackStackEntry.requireBoolArg(name: String): Boolean {
    return arguments?.getBoolean(name) ?: false
}
