package com.motchill.androidcompose.feature.home

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.motchill.androidcompose.app.di.PhucTVAppContainer

@Composable
fun HomeRoute(
    onOpenSearch: () -> Unit,
    onOpenFavorite: () -> Unit,
    onOpenAccount: () -> Unit,
    onOpenDetail: (String) -> Unit,
    onOpenSection: (String, String) -> Unit,
) {
    val homeViewModel: HomeViewModel = viewModel(
        factory = remember {
            HomeViewModel.factory(PhucTVAppContainer.repository)
        },
    )
    val uiState by homeViewModel.uiState.collectAsState()

    HomeScreen(
        uiState = uiState,
        onRetry = homeViewModel::refresh,
        onSelectHeroMovie = homeViewModel::selectHeroMovie,
        onTapFavorite = onOpenFavorite,
        onTapSearch = onOpenSearch,
        onTapAccount = onOpenAccount,
        onOpenMovie = onOpenDetail,
        onOpenSection = onOpenSection,
    )
}

@Composable
fun HomeScreen(
    uiState: HomeUiState,
    onRetry: () -> Unit,
    onSelectHeroMovie: (Int) -> Unit,
    onTapFavorite: () -> Unit,
    onTapSearch: () -> Unit,
    onTapAccount: () -> Unit,
    onOpenMovie: (String) -> Unit,
    onOpenSection: (String, String) -> Unit,
) {
    androidx.compose.foundation.layout.Box(
        modifier = Modifier.fillMaxSize(),
    ) {
        HomeScreenContent(
            uiState = uiState,
            onRetry = onRetry,
            onSelectHeroMovie = onSelectHeroMovie,
            onTapFavorite = onTapFavorite,
            onTapSearch = onTapSearch,
            onTapAccount = onTapAccount,
            onOpenMovie = onOpenMovie,
            onOpenSection = onOpenSection,
        )
    }
}
