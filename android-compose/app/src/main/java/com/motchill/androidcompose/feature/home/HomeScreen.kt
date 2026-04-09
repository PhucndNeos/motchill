package com.motchill.androidcompose.feature.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.motchill.androidcompose.app.di.MotchillAppContainer
import com.motchill.androidcompose.core.designsystem.MotchillFocusCard
import com.motchill.androidcompose.core.designsystem.MotchillRemoteImage
import com.motchill.androidcompose.domain.model.HomeSection
import com.motchill.androidcompose.domain.model.MovieCard

@Composable
fun HomeRoute(
    onOpenSearch: () -> Unit,
    onOpenFavorite: () -> Unit,
    onOpenDetail: (String) -> Unit,
    onOpenSection: (String) -> Unit,
) {
    val homeViewModel: HomeViewModel = viewModel(
        factory = remember {
            HomeViewModel.factory(MotchillAppContainer.repository)
        },
    )
    val uiState by homeViewModel.uiState.collectAsState()

    HomeScreen(
        uiState = uiState,
        onRetry = homeViewModel::refresh,
        onSelectHeroMovie = homeViewModel::selectHeroMovie,
        onTapFavorite = onOpenFavorite,
        onTapSearch = onOpenSearch,
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
    onOpenMovie: (String) -> Unit,
    onOpenSection: (String) -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(
                        Color(0xFF131313),
                        Color(0xFF101010),
                        Color(0xFF050505),
                    ),
                ),
            ),
    ) {
        when {
            uiState.isLoading && uiState.sections.isEmpty() -> LoadingState()
            uiState.errorMessage != null && uiState.sections.isEmpty() -> ErrorState(
                message = uiState.errorMessage,
                onRetry = onRetry,
            )
            uiState.isEmpty -> ErrorState(
                message = "No content available yet.",
                onRetry = onRetry,
            )
            else -> HomeContent(
                uiState = uiState,
                onSelectHeroMovie = onSelectHeroMovie,
                onTapFavorite = onTapFavorite,
                onTapSearch = onTapSearch,
                onOpenMovie = onOpenMovie,
                onOpenSection = onOpenSection,
            )
        }
    }
}

@Composable
private fun HomeContent(
    uiState: HomeUiState,
    onSelectHeroMovie: (Int) -> Unit,
    onTapFavorite: () -> Unit,
    onTapSearch: () -> Unit,
    onOpenMovie: (String) -> Unit,
    onOpenSection: (String) -> Unit,
) {
    val selectedMovie = uiState.selectedMovie ?: return
    val previewMovies = uiState.previewMovies

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 16.dp, top = 14.dp, end = 16.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        item {
            HomeHeroSection(
                selectedMovie = selectedMovie,
                previewMovies = previewMovies,
                onSelectMovie = onSelectHeroMovie,
                onTapFavorite = onTapFavorite,
                onTapSearch = onTapSearch,
                onOpenMovie = onOpenMovie,
            )
        }

        items(uiState.contentSections) { section ->
            SectionRail(
                section = section,
                onOpenMovie = onOpenMovie,
                onOpenSection = onOpenSection,
            )
        }
    }
}

@Composable
private fun HomeHeroSection(
    selectedMovie: MovieCard,
    previewMovies: List<MovieCard>,
    onSelectMovie: (Int) -> Unit,
    onTapFavorite: () -> Unit,
    onTapSearch: () -> Unit,
    onOpenMovie: (String) -> Unit,
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            FocusActionButton(
                text = "Favorite",
                icon = Icons.Outlined.FavoriteBorder,
                filled = true,
                modifier = Modifier.weight(1f),
                onClick = onTapFavorite,
            )
            FocusActionButton(
                text = "Tìm kiếm",
                icon = Icons.Outlined.Search,
                filled = false,
                modifier = Modifier.weight(1f),
                onClick = onTapSearch,
            )
        }

        HeroCard(
            selectedMovie = selectedMovie,
            onTapSearch = onTapSearch,
            onOpenMovie = onOpenMovie,
        )

        PreviewStrip(
            previewMovies = previewMovies,
            onSelectMovie = onSelectMovie,
        )
    }
}

@Composable
private fun HeroCard(
    selectedMovie: MovieCard,
    onTapSearch: () -> Unit,
    onOpenMovie: (String) -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(280.dp)
            .background(
                color = Color(0xFF1A1A1A),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(28.dp),
            ),
    ) {
        MotchillRemoteImage(
            url = selectedMovie.displayBanner,
            modifier = Modifier.fillMaxSize(),
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.22f)),
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.horizontalGradient(
                        colors = listOf(
                            Color(0xFF131313).copy(alpha = 0.96f),
                            Color(0xFF131313).copy(alpha = 0.80f),
                            Color(0xFF131313).copy(alpha = 0.14f),
                        ),
                    ),
                ),
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(20.dp),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = "CINEMATIC CHOICE",
                color = Color(0xFFE50914),
                fontSize = 20.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.ExtraBold,
                letterSpacing = 1.2.sp,
            )

            Column(
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.fillMaxWidth(0.82f),
            ) {
                Text(
                    text = selectedMovie.displayTitle,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    color = Color.White,
                    fontSize = 34.sp,
                    fontWeight = androidx.compose.ui.text.font.FontWeight.ExtraBold,
                    lineHeight = 32.sp,
                    letterSpacing = (-0.6).sp,
                )
                Text(
                    text = selectedMovie.displaySubtitle.ifBlank { selectedMovie.statusTitle },
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    color = Color.White.copy(alpha = 0.70f),
                    fontSize = 13.sp,
                    lineHeight = 19.sp,
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    FocusActionButton(
                        text = "Xem ngay",
                        icon = Icons.Outlined.PlayArrow,
                        filled = true,
                        onClick = { onOpenMovie(selectedMovie.link) },
                        modifier = Modifier.width(140.dp)
                    )
                    FocusActionButton(
                        text = "Tìm kiếm",
                        icon = Icons.Outlined.Search,
                        filled = false,
                        onClick = onTapSearch,
                        modifier = Modifier.width(140.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun PreviewStrip(
    previewMovies: List<MovieCard>,
    onSelectMovie: (Int) -> Unit,
) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        contentPadding = PaddingValues(end = 2.dp),
    ) {
        items(previewMovies, key = { it.id }) { movie ->
            PreviewCard(
                movie = movie,
                onClick = { onSelectMovie(movie.id) },
            )
        }
    }
}

@Composable
private fun PreviewCard(
    movie: MovieCard,
    onClick: () -> Unit,
) {
    MotchillFocusCard(
        modifier = Modifier
            .width(104.dp)
            .height(138.dp),
        onClick = onClick,
        borderRadius = androidx.compose.foundation.shape.RoundedCornerShape(18.dp),
        focusedBorderColor = Color(0xFFFFD15C),
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
            ) {
                MotchillRemoteImage(
                    url = movie.displayPoster,
                    modifier = Modifier.fillMaxSize(),
                )
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Black.copy(alpha = 0.45f),
                                    Color.Transparent,
                                ),
                            ),
                        ),
                )
                if (movie.rating.isNotBlank()) {
                    RatingBadge(
                        text = movie.rating,
                        modifier = Modifier
                            .padding(start = 8.dp, top = 8.dp)
                            .align(Alignment.TopStart),
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionRail(
    section: HomeSection,
    onOpenMovie: (String) -> Unit,
    onOpenSection: (String) -> Unit,
) {
    val products = section.products
    if (products.isEmpty()) return

    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = section.title.ifBlank { section.key },
                modifier = Modifier.weight(1f),
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.ExtraBold,
                letterSpacing = (-0.2).sp,
            )
            FocusTextButton(
                text = "Xem tất cả",
                onClick = { onOpenSection(sectionSearchSlug(section)) },
            )
        }

        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(end = 2.dp),
        ) {
            items(products, key = { it.id }) { movie ->
                SectionMovieCard(
                    movie = movie,
                    onClick = { onOpenMovie(movie.link) },
                )
            }
        }
    }
}

@Composable
private fun SectionMovieCard(
    movie: MovieCard,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier.width(132.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        MotchillFocusCard(
            modifier = Modifier
                .fillMaxWidth()
                .height(226.dp),
            onClick = onClick,
            borderRadius = androidx.compose.foundation.shape.RoundedCornerShape(18.dp),
            focusedBorderColor = Color(0xFFFFD15C),
        ) {
            Box(modifier = Modifier.fillMaxSize()) {
                MotchillRemoteImage(
                    url = movie.displayPoster,
                    modifier = Modifier.fillMaxSize(),
                )
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(
                                    Color.Black.copy(alpha = 0.48f),
                                    Color.Transparent,
                                ),
                            ),
                        ),
                )
                if (movie.rating.isNotBlank()) {
                    RatingBadge(
                        text = movie.rating,
                        modifier = Modifier
                            .padding(start = 10.dp, top = 10.dp)
                            .align(Alignment.TopStart),
                    )
                }
            }
        }

        Text(
            text = movie.displayTitle,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            color = Color.White,
            fontSize = 13.sp,
            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
        )
        Text(
            text = movie.displaySubtitle.ifBlank { movie.statusTitle },
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = Color.White.copy(alpha = 0.60f),
            fontSize = 11.sp,
        )
    }
}

@Composable
private fun RatingBadge(
    text: String,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .background(
                color = Color.Black.copy(alpha = 0.72f),
                shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
            )
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            text = text,
            color = Color.White,
            fontSize = 10.sp,
            fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
        )
    }
}

@Composable
private fun LoadingState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
private fun ErrorState(
    message: String?,
    onRetry: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = message.orEmpty(),
            color = Color.White,
            fontSize = 16.sp,
        )
        Spacer(modifier = Modifier.height(16.dp))
        FocusTextButton(text = "Thử lại", onClick = onRetry)
    }
}

@Composable
private fun FocusActionButton(
    text: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    filled: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    MotchillFocusCard(
        modifier = modifier.height(48.dp),
        onClick = onClick,
        borderRadius = androidx.compose.foundation.shape.RoundedCornerShape(14.dp),
        focusedBorderColor = if (filled) Color(0xFFE50914) else Color(0xFFFFD15C),
        focusScale = 1.02f,
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    color = if (filled) {
                        MaterialTheme.colorScheme.primary
                    } else {
                        Color(0xFF1A1A1A)
                    },
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(14.dp),
                )
                .border(
                    width = 1.dp,
                    color = if (filled) Color(0xFFB9131C) else Color.White.copy(alpha = 0.12f),
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(14.dp),
                ),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 14.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                androidx.compose.material3.Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = Color.White,
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = text,
                    color = Color.White,
                    fontSize = 14.sp,
                    fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
private fun FocusTextButton(
    text: String,
    onClick: () -> Unit,
) {
    MotchillFocusCard(
        onClick = onClick,
        borderRadius = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
        focusedBorderColor = Color(0xFFFFD15C),
        focusScale = 1.02f,
    ) {
        Box(
            modifier = Modifier
                .background(
                    color = Color.White.copy(alpha = 0.04f),
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(999.dp),
                ),
        ) {
            Text(
                text = text,
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold,
            )
        }
    }
}
