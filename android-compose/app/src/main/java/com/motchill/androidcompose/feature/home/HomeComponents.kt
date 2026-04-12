package com.motchill.androidcompose.feature.home

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Devices
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.motchill.androidcompose.core.designsystem.MotchillFocusCard
import com.motchill.androidcompose.core.designsystem.MotchillRemoteImage
import com.motchill.androidcompose.domain.model.HomeSection
import com.motchill.androidcompose.domain.model.MovieCard

@Composable
internal fun HomeScreenContent(
    uiState: HomeUiState,
    onRetry: () -> Unit,
    onSelectHeroMovie: (Int) -> Unit,
    onTapFavorite: () -> Unit,
    onTapSearch: () -> Unit,
    onOpenMovie: (String) -> Unit,
    onOpenSection: (String, String) -> Unit,
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
            uiState.isLoading && uiState.sections.isEmpty() -> HomeLoadingState()
            uiState.errorMessage != null && uiState.sections.isEmpty() -> HomeErrorState(
                message = uiState.errorMessage,
                onRetry = onRetry,
            )
            uiState.isEmpty -> HomeErrorState(
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
    onOpenSection: (String, String) -> Unit,
) {
    val selectedMovie = uiState.selectedMovie ?: return

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        if (maxWidth < 900.dp) {
            HomeStackContent(
                uiState = uiState,
                onTapSearch = onTapSearch,
                onOpenMovie = onOpenMovie,
                onOpenSection = onOpenSection,
            )
        } else {
            HomeSplitContent(
                uiState = uiState,
                selectedMovie = selectedMovie,
                onSelectHeroMovie = onSelectHeroMovie,
                onTapSearch = onTapSearch,
                onOpenMovie = onOpenMovie,
                onOpenSection = onOpenSection,
            )
        }
    }
}

@Composable
private fun HomeStackContent(
    uiState: HomeUiState,
    onTapSearch: () -> Unit,
    onOpenMovie: (String) -> Unit,
    onOpenSection: (String, String) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 16.dp, top = 14.dp, end = 16.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                HomeActionButton(
                    text = "Tìm kiếm",
                    icon = Icons.Outlined.Search,
                    filled = false,
                    modifier = Modifier.fillMaxWidth(),
                    onClick = onTapSearch,
                )
            }
        }

        items(uiState.contentSections) { section ->
            HomeSectionRail(
                section = section,
                selectedMovieId = null,
                onMovieClick = { movie -> onOpenMovie(movie.link) },
                onOpenMovie = onOpenMovie,
                onOpenSection = onOpenSection,
            )
        }
    }
}

@Composable
private fun HomeSplitContent(
    uiState: HomeUiState,
    selectedMovie: MovieCard,
    onSelectHeroMovie: (Int) -> Unit,
    onTapSearch: () -> Unit,
    onOpenMovie: (String) -> Unit,
    onOpenSection: (String, String) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxSize()
            .padding(start = 16.dp, top = 14.dp, end = 16.dp, bottom = 24.dp),
        horizontalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        LazyColumn(
            modifier = Modifier.weight(1f).fillMaxHeight(),
            verticalArrangement = Arrangement.spacedBy(22.dp),
            contentPadding = PaddingValues(end = 4.dp),
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    HomeActionButton(
                        text = "Tìm kiếm",
                        icon = Icons.Outlined.Search,
                        filled = false,
                        modifier = Modifier.fillMaxWidth(),
                        onClick = onTapSearch,
                    )
                }
            }

            items(uiState.contentSections) { section ->
                HomeSectionRail(
                    section = section,
                    selectedMovieId = selectedMovie.id,
                    onMovieClick = { movie -> onSelectHeroMovie(movie.id) },
                    onOpenMovie = onOpenMovie,
                    onOpenSection = onOpenSection,
                )
            }
        }

        HomeSpotlightPanel(
            modifier = Modifier
                .weight(0.95f)
                .fillMaxHeight()
                .widthIn(max = 560.dp),
            selectedMovie = selectedMovie,
            onOpenMovie = onOpenMovie,
            onTapSearch = onTapSearch,
        )
    }
}

@Composable
private fun HomeSectionRail(
    section: HomeSection,
    selectedMovieId: Int?,
    onMovieClick: (MovieCard) -> Unit,
    onOpenMovie: (String) -> Unit,
    onOpenSection: (String, String) -> Unit,
) {
    val products = section.products
    if (products.isEmpty()) return

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = section.title.ifBlank { section.key },
                modifier = Modifier.weight(1f),
                color = Color.White,
                fontSize = 18.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = (-0.2).sp,
            )
            HomeTextButton(
                text = "Xem tất cả",
                onClick = { onOpenSection(sectionSearchSlug(section), section.title) },
            )
        }

        LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(end = 2.dp)) {
            items(products, key = { it.id }) { movie ->
                val isSelected = movie.id == selectedMovieId
                HomeSectionCard(
                    movie = movie,
                    selected = isSelected,
                    onClick = {
                        if (isSelected) onOpenMovie(movie.link) else onMovieClick(movie)
                    },
                )
            }
        }
    }
}

@Composable
private fun HomeSectionCard(
    movie: MovieCard,
    selected: Boolean,
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
            borderRadius = RoundedCornerShape(18.dp),
            focusedBorderColor = if (selected) Color(0xFFE50914) else Color(0xFFFFD15C),
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
                if (selected) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color(0xFFE50914).copy(alpha = 0.10f)),
                    )
                }
                if (movie.rating.isNotBlank()) {
                    HomeRatingBadge(
                        text = movie.rating,
                        modifier = Modifier.padding(start = 10.dp, top = 10.dp).align(Alignment.TopStart),
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
            fontWeight = FontWeight.Bold,
        )
        Text(
            text = movie.displaySubtitle.ifBlank { movie.statusTitle },
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = if (selected) Color(0xFFFFD15C) else Color.White.copy(alpha = 0.60f),
            fontSize = 11.sp,
        )
    }
}

@Composable
private fun HomeSpotlightPanel(
    modifier: Modifier = Modifier,
    selectedMovie: MovieCard,
    onOpenMovie: (String) -> Unit,
    onTapSearch: () -> Unit,
) {
    LazyColumn(
        modifier = modifier
            .clip(RoundedCornerShape(28.dp))
            .background(Color(0xFF0F0F0F)),
        contentPadding = PaddingValues(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(420.dp)
                    .clickable(
                        indication = null,
                        interactionSource = MutableInteractionSource(),
                    ) {
                        onOpenMovie(selectedMovie.link)
                    }
                    .background(
                        color = Color(0xFF141414),
                        shape = RoundedCornerShape(28.dp),
                    ),
            ) {
                MotchillRemoteImage(
                    url = selectedMovie.displayBanner,
                    modifier = Modifier.fillMaxSize(),
                )
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.28f)),
                )

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    verticalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = "SPOTLIGHT",
                        color = Color(0xFFE50914),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.ExtraBold,
                        letterSpacing = 1.2.sp,
                    )

                    Column(verticalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth(0.86f)) {
                        Text(
                            text = selectedMovie.displayTitle,
                            color = Color.White,
                            fontSize = 34.sp,
                            lineHeight = 34.sp,
                            fontWeight = FontWeight.ExtraBold,
                            maxLines = 3,
                            overflow = TextOverflow.Ellipsis,
                        )
                        Text(
                            text = selectedMovie.displaySubtitle.ifBlank { selectedMovie.statusTitle },
                            color = Color.White.copy(alpha = 0.74f),
                            fontSize = 13.sp,
                            lineHeight = 20.sp,
                            maxLines = 4,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                HomeMetaPill(selectedMovie.year.takeIf { it > 0 }?.toString())
                HomeMetaPill(selectedMovie.rating.takeIf { it.isNotBlank() })
                HomeMetaPill(selectedMovie.statusTitle.takeIf { it.isNotBlank() })
                HomeMetaPill(selectedMovie.quantity.takeIf { it.isNotBlank() })
            }
        }

        item {
            Text(
                text = selectedMovie.description.ifBlank { selectedMovie.moreInfo }.ifBlank { selectedMovie.displaySubtitle },
                color = Color.White.copy(alpha = 0.72f),
                fontSize = 14.sp,
                lineHeight = 22.sp,
                maxLines = 7,
                overflow = TextOverflow.Ellipsis,
            )
        }

        item {
            HomeActionButton(
                text = "Xem phim",
                icon = Icons.Outlined.PlayArrow,
                filled = true,
                modifier = Modifier.fillMaxWidth(),
                onClick = { onOpenMovie(selectedMovie.link) },
            )
        }
    }
}

@Composable
private fun HomeMetaPill(text: String?) {
    val value = text?.trim().orEmpty()
    if (value.isBlank()) return
    Box(
        modifier = Modifier
            .background(Color.White.copy(alpha = 0.06f), RoundedCornerShape(999.dp))
            .border(1.dp, Color.White.copy(alpha = 0.10f), RoundedCornerShape(999.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp),
    ) {
        Text(
            text = value,
            color = Color.White,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
internal fun HomeLoadingState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
internal fun HomeErrorState(
    message: String?,
    onRetry: () -> Unit,
) {
    val displayMessage = message?.trim().orEmpty().ifBlank {
        "An error occurred. Please retry."
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        ) {
        Text(
            text = displayMessage,
            color = Color.White,
            fontSize = 16.sp,
        )
        Spacer(modifier = Modifier.height(16.dp))
        HomeTextButton(text = "Thử lại", onClick = onRetry)
    }
}

@Composable
private fun HomeActionButton(
    text: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    filled: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    MotchillFocusCard(
        modifier = modifier.height(48.dp),
        onClick = onClick,
        borderRadius = RoundedCornerShape(14.dp),
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
                    shape = RoundedCornerShape(14.dp),
                )
                .border(
                    width = 1.dp,
                    color = if (filled) Color(0xFFB9131C) else Color.White.copy(alpha = 0.12f),
                    shape = RoundedCornerShape(14.dp),
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
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
}

@Composable
private fun HomeTextButton(
    text: String,
    onClick: () -> Unit,
) {
    MotchillFocusCard(
        onClick = onClick,
        borderRadius = RoundedCornerShape(999.dp),
        focusedBorderColor = Color(0xFFFFD15C),
        focusScale = 1.02f,
    ) {
        Box(
            modifier = Modifier.background(
                color = Color.White.copy(alpha = 0.04f),
                shape = RoundedCornerShape(999.dp),
            ),
        ) {
            Text(
                text = text,
                modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
                color = Color.White,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun HomeRatingBadge(
    text: String,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .background(
                color = Color.Black.copy(alpha = 0.72f),
                shape = RoundedCornerShape(999.dp),
            )
            .padding(horizontal = 8.dp, vertical = 3.dp),
    ) {
        Text(
            text = text,
            color = Color.White,
            fontSize = 10.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF101010, device = Devices.TABLET)
@Composable
private fun HomeScreenPreview() {
    HomeScreenContent(
        uiState = HomeMockData.homeLoadedState(),
        onRetry = {},
        onSelectHeroMovie = {},
        onTapFavorite = {},
        onTapSearch = {},
        onOpenMovie = {},
        onOpenSection = { _, _ -> },
    )
}
