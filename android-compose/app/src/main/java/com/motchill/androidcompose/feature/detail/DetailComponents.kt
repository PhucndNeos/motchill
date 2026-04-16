package com.motchill.androidcompose.feature.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material.icons.outlined.PlayCircleOutline
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.motchill.androidcompose.core.designsystem.PhucTVFocusCard
import com.motchill.androidcompose.core.designsystem.PhucTVRemoteImage
import com.motchill.androidcompose.core.storage.PlaybackProgressSnapshot
import com.motchill.androidcompose.domain.model.MovieCard
import com.motchill.androidcompose.domain.model.MovieDetail
import com.motchill.androidcompose.domain.model.MovieEpisode
import com.motchill.androidcompose.domain.model.displayBackdrop

@Composable
internal fun DetailScreenContent(
    uiState: DetailUiState,
    onBack: () -> Unit,
    onOpenSearch: () -> Unit,
    onOpenDetail: (String) -> Unit,
    onOpenEpisode: (Int, Int, String, String) -> Unit,
    onRetry: () -> Unit,
    onSelectTab: (DetailSectionTab) -> Unit,
    onToggleLike: () -> Unit,
    onOpenTrailer: (String) -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(Color(0xFF141414), Color(0xFF0F0F0F), Color(0xFF050505)),
                ),
            ),
    ) {
        when {
            uiState.isLoading && uiState.detail == null -> DetailLoadingState()
            uiState.errorMessage != null && uiState.detail == null -> DetailErrorState(uiState.errorMessage, onRetry)
            uiState.detail == null -> Unit
            else -> DetailContent(
                detail = uiState.detail,
                selectedTab = uiState.effectiveSelectedTab,
                availableTabs = uiState.availableTabs,
                isLiked = uiState.isLiked,
                episodeProgressById = uiState.episodeProgressById,
                onBack = onBack,
                onOpenSearch = onOpenSearch,
                onOpenDetail = onOpenDetail,
                onOpenEpisode = onOpenEpisode,
                onToggleLike = onToggleLike,
                onSelectTab = onSelectTab,
                onOpenTrailer = onOpenTrailer,
            )
        }
    }
}

@Composable
private fun DetailContent(
    detail: MovieDetail,
    selectedTab: DetailSectionTab,
    availableTabs: List<DetailSectionTab>,
    isLiked: Boolean,
    episodeProgressById: Map<Int, PlaybackProgressSnapshot>,
    onBack: () -> Unit,
    onOpenSearch: () -> Unit,
    onOpenDetail: (String) -> Unit,
    onOpenEpisode: (Int, Int, String, String) -> Unit,
    onToggleLike: () -> Unit,
    onSelectTab: (DetailSectionTab) -> Unit,
    onOpenTrailer: (String) -> Unit,
) {
    LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 28.dp)) {
        item {
            DetailHero(
                detail = detail,
                isLiked = isLiked,
                onBack = onBack,
                onLike = onToggleLike,
                onPlay = detail.episodes.firstOrNull()?.let { episode ->
                    { onOpenEpisode(detail.id, episode.id, detail.title, episode.label) }
                },
                onOpenInformation = {
                    if (DetailSectionTab.information in availableTabs) onSelectTab(DetailSectionTab.information)
                },
                onOpenTrailer = {
                    val trailer = detail.trailer.trim()
                    if (trailer.isNotEmpty()) onOpenTrailer(trailer)
                },
            )
        }

        item {
            Column(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 18.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                DetailHeader(detail = detail, onOpenTrailer = { onOpenTrailer(detail.trailer) })
                DetailMetadataRow(detail = detail)
            }
        }

        if (availableTabs.isNotEmpty()) {
            item {
                Column(
                    modifier = Modifier.padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    DetailTabStrip(tabs = availableTabs, selectedTab = selectedTab, onTabSelected = onSelectTab)
                    DetailSectionCard(modifier = Modifier.fillMaxWidth()) {
                        DetailTabBody(
                            detail = detail,
                            selectedTab = selectedTab,
                            episodeProgressById = episodeProgressById,
                            onOpenEpisode = onOpenEpisode,
                            onOpenDetail = onOpenDetail,
                            onOpenSearch = onOpenSearch,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DetailHero(
    detail: MovieDetail,
    isLiked: Boolean,
    onBack: () -> Unit,
    onLike: () -> Unit,
    onPlay: (() -> Unit)?,
    onOpenInformation: () -> Unit,
    onOpenTrailer: () -> Unit,
) {
    Box(modifier = Modifier.fillMaxWidth().height(420.dp)) {
        PhucTVRemoteImage(url = detail.displayBackdrop, modifier = Modifier.fillMaxSize())
        Box(modifier = Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.15f), Color.Black.copy(alpha = 0.55f), Color(0xFF141414)))))
        Row(modifier = Modifier.fillMaxWidth().padding(start = 16.dp, top = 16.dp, end = 16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            DetailIconButton(icon = Icons.AutoMirrored.Outlined.ArrowBack, onClick = onBack, label = "Back")
            DetailIconButton(icon = if (isLiked) Icons.Outlined.Favorite else Icons.Outlined.FavoriteBorder, onClick = onLike, label = "Like")
        }
        Column(
            modifier = Modifier.align(Alignment.BottomStart).fillMaxWidth().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(text = detail.title, maxLines = 2, overflow = TextOverflow.Ellipsis, color = Color.White, fontSize = 30.sp, fontWeight = FontWeight.Black, lineHeight = 30.sp, letterSpacing = (-0.4).sp)
            if (detail.otherName.trim().isNotEmpty()) {
                Text(text = detail.otherName, maxLines = 2, overflow = TextOverflow.Ellipsis, color = Color.White.copy(alpha = 0.70f), fontSize = 14.sp, lineHeight = 19.sp)
            }
            FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)) {
                detail.year.takeIf { it > 0 }?.let { DetailMetaPill(it.toString()) }
                detail.quality.takeIf { it.trim().isNotEmpty() }?.let { DetailMetaPill(it) }
                detail.statusTitle.takeIf { it.trim().isNotEmpty() }?.let { DetailMetaPill(it) }
                detail.ratePoint.takeIf { it > 0 }?.let { DetailMetaPill(it.toStringAsOneDecimal()) }
                detail.viewNumber.takeIf { it > 0 }?.let { DetailMetaPill(formatCount(it)) }
                detail.time.takeIf { it.trim().isNotEmpty() }?.let { DetailMetaPill(it) }
                detail.episodesTotal.takeIf { it > 0 }?.let { DetailMetaPill("${it} eps") }
            }
            Row(horizontalArrangement = Arrangement.SpaceEvenly,
                modifier = Modifier.fillMaxWidth()) {
                DetailActionButton(text = "Xem ngay", icon = Icons.Outlined.PlayArrow, filled = true, onClick = { onPlay?.invoke() })
                DetailActionButton(text = "Trailer", icon = Icons.Outlined.PlayCircleOutline, filled = false, onClick = onOpenTrailer)
            }
        }
    }
}

@Composable
private fun DetailHeader(detail: MovieDetail, onOpenTrailer: () -> Unit) {
    Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(text = detail.title, modifier = Modifier.weight(1f), color = Color.White, fontSize = 24.sp, fontWeight = FontWeight.Black, letterSpacing = (-0.2).sp)
        if (detail.trailer.trim().isNotEmpty()) DetailTextButton(text = "Trailer", onClick = onOpenTrailer)
    }
}

@Composable
private fun DetailMetadataRow(detail: MovieDetail) {
    val items = buildList {
        if (detail.year > 0) add(detail.year.toString())
        if (detail.ratePoint > 0) add(detail.ratePoint.toStringAsOneDecimal())
        if (detail.quality.trim().isNotEmpty()) add(detail.quality)
        if (detail.statusText.trim().isNotEmpty()) add(detail.statusText)
        if (detail.statusRaw.trim().isNotEmpty()) add(detail.statusRaw)
        if (detail.viewNumber > 0) add(formatCount(detail.viewNumber))
        if (detail.time.trim().isNotEmpty()) add(detail.time)
        if (detail.episodesTotal > 0) add("${detail.episodesTotal} eps")
    }
    if (items.isEmpty()) return
    FlowRow(horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)) { items.forEach { DetailMetaPill(it) } }
}

@Composable
private fun DetailTabStrip(tabs: List<DetailSectionTab>, selectedTab: DetailSectionTab, onTabSelected: (DetailSectionTab) -> Unit) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        items(tabs) { tab ->
            DetailTabChip(label = tab.label, selected = tab == selectedTab, onClick = { onTabSelected(tab) })
        }
    }
}

@Composable
private fun DetailTabBody(
    detail: MovieDetail,
    selectedTab: DetailSectionTab,
    episodeProgressById: Map<Int, PlaybackProgressSnapshot>,
    onOpenEpisode: (Int, Int, String, String) -> Unit,
    onOpenDetail: (String) -> Unit,
    onOpenSearch: () -> Unit,
) {
    when (selectedTab) {
        DetailSectionTab.episodes -> DetailEpisodesTab(detail, episodeProgressById, onOpenEpisode)
        DetailSectionTab.synopsis -> DetailSynopsisTab(detail)
        DetailSectionTab.information -> DetailInformationTab(detail)
        DetailSectionTab.classification -> DetailClassificationTab(detail)
        DetailSectionTab.gallery -> DetailGalleryTab(detail)
        DetailSectionTab.related -> DetailRelatedTab(detail, onOpenDetail, onOpenSearch)
    }
}

@Composable
private fun DetailEpisodesTab(
    detail: MovieDetail,
    episodeProgressById: Map<Int, PlaybackProgressSnapshot>,
    onOpenEpisode: (Int, Int, String, String) -> Unit,
) {
    if (detail.episodes.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row {
            Text(text = "Episodes", modifier = Modifier.weight(1f), color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
            Text(text = detail.episodes.size.toString(), color = Color.White.copy(alpha = 0.54f), fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            detail.episodes.forEach { episode ->
                DetailEpisodeTile(
                    episode = episode,
                    progress = episodeProgressById[episode.id],
                    onClick = { onOpenEpisode(detail.id, episode.id, detail.title, episode.label) },
                )
            }
        }
    }
}

@Composable
private fun DetailSynopsisTab(detail: MovieDetail) {
    if (detail.description.trim().isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        DetailSectionTitle("Synopsis")
        Text(text = detail.description, color = Color.White.copy(alpha = 0.70f), fontSize = 14.sp, lineHeight = 22.sp)
    }
}

@Composable
private fun DetailInformationTab(detail: MovieDetail) {
    val items = buildList {
        if (detail.director.trim().isNotEmpty()) add("Director" to detail.director)
        if (detail.castString.trim().isNotEmpty()) add("Cast" to detail.castString)
        if (detail.showTimes.trim().isNotEmpty()) add("Show times" to detail.showTimes)
        if (detail.moreInfo.trim().isNotEmpty()) add("More info" to detail.moreInfo)
        if (detail.trailer.trim().isNotEmpty()) add("Trailer" to detail.trailer)
        if (detail.statusRaw.trim().isNotEmpty()) add("Status raw" to detail.statusRaw)
        if (detail.statusText.trim().isNotEmpty()) add("Status text" to detail.statusText)
    }
    if (items.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        DetailSectionTitle("Information")
        items.forEach { (label, value) -> DetailInfoCard(label = label, value = value) }
    }
}

@Composable
private fun DetailClassificationTab(detail: MovieDetail) {
    if (detail.countries.isEmpty() && detail.categories.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        DetailSectionTitle("Classification")
        if (detail.countries.isNotEmpty()) {
            DetailMiniLabel("Countries")
            DetailLabelFlow(labels = detail.countries.map { it.name })
        }
        if (detail.countries.isNotEmpty() && detail.categories.isNotEmpty()) Spacer(modifier = Modifier.height(2.dp))
        if (detail.categories.isNotEmpty()) {
            DetailMiniLabel("Categories")
            DetailLabelFlow(labels = detail.categories.map { it.name })
        }
    }
}

@Composable
private fun DetailGalleryTab(detail: MovieDetail) {
    val images = buildSet { addAll(detail.photoUrls); addAll(detail.previewPhotoUrls) }.filter { it.trim().isNotEmpty() }
    if (images.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        DetailSectionTitle("Gallery")
        LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) { items(images) { url -> DetailGalleryImage(url) } }
    }
}

@Composable
private fun DetailRelatedTab(detail: MovieDetail, onOpenDetail: (String) -> Unit, onOpenSearch: () -> Unit) {
    if (detail.relatedMovies.isEmpty()) return
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            DetailSectionTitle("Related", modifier = Modifier.weight(1f))
            DetailTextButton(text = "VIEW MORE", onClick = onOpenSearch)
        }
        LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            items(detail.relatedMovies) { movie -> DetailRelatedMovieCard(movie = movie, onClick = onOpenDetail) }
        }
    }
}

@Composable
private fun DetailSectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(text = text, modifier = modifier, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
}

@Composable
private fun DetailMiniLabel(text: String) {
    Text(text = text, color = Color.White.copy(alpha = 0.54f), fontSize = 11.sp, fontWeight = FontWeight.Bold)
}

@Composable
private fun DetailLabelFlow(labels: List<String>) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) { labels.forEach { DetailLabelChip(it) } }
}

@Composable
private fun DetailInfoCard(label: String, value: String) {
    Box(
        modifier = Modifier.fillMaxWidth().background(Color(0xFF1B1B1B), RoundedCornerShape(18.dp)).border(1.dp, Color(0xFF2C2C2C), RoundedCornerShape(18.dp)).padding(14.dp),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(text = label, color = Color.White.copy(alpha = 0.54f), fontSize = 11.sp, fontWeight = FontWeight.Bold)
            Text(text = value, color = Color.White, fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun DetailEpisodeTile(
    episode: MovieEpisode,
    progress: PlaybackProgressSnapshot?,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    val progressFraction = progress?.progressFraction ?: 0f

    PhucTVFocusCard(
        onClick = onClick,
        borderRadius = shape,
        focusedBorderColor = Color(0xFFE8A7A7),
        focusedBackgroundColor = Color(0xFF251717),
        focusScale = 1.01f,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(shape)
                .drawWithContent {
                    drawRoundRect(
                        color = Color(0xFF171717),
                        size = size,
                        cornerRadius = CornerRadius(16.dp.toPx(), 16.dp.toPx()),
                    )
                    if (progressFraction > 0f) {
                        drawRoundRect(
                            color = Color(0xFFE50914).copy(alpha = 0.60f),
                            size = Size(width = size.width * progressFraction, height = size.height),
                            cornerRadius = CornerRadius(16.dp.toPx(), 16.dp.toPx()),
                        )
                    }
                    drawContent()
                }
                .border(1.dp, Color(0xFF2D2D2D), shape),
        ) {
            Column(
                modifier = Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text(text = episode.label, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold)
                val subtitleParts = buildList {
                    if (episode.type.trim().isNotEmpty()) add(episode.type.trim())
                    if (episode.status != null) add("${episode.status}")
                    progress?.takeIf { it.durationMillis > 0L }?.let {
                        add("đã xem ${formatDuration(it.positionMillis)} / ${formatDuration(it.durationMillis)}")
                    }
                }
                Text(
                    text = if (subtitleParts.isEmpty()) "Episode detail from public API" else subtitleParts.joinToString(" • "),
                    color = Color.White.copy(alpha = 0.60f),
                    fontSize = 12.sp,
                )
            }
        }
    }
}

private fun formatDuration(positionMs: Long): String {
    val totalSeconds = positionMs.coerceAtLeast(0L) / 1000L
    val hours = totalSeconds / 3600L
    val minutes = (totalSeconds % 3600L) / 60L
    val seconds = totalSeconds % 60L
    return if (hours > 0L) {
        String.format(java.util.Locale.US, "%d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format(java.util.Locale.US, "%02d:%02d", minutes, seconds)
    }
}

@Composable
private fun DetailTabChip(label: String, selected: Boolean, onClick: () -> Unit) {
    PhucTVFocusCard(onClick = onClick, borderRadius = RoundedCornerShape(999.dp), focusedBorderColor = Color(0xFFFFD15C), focusedBackgroundColor = Color(0xFFE50914).copy(alpha = 0.22f), focusScale = 1.02f) {
        Box(
            modifier = Modifier.background(if (selected) Color(0xFFE50914).copy(alpha = 0.20f) else Color(0xFF191919), RoundedCornerShape(999.dp)).border(1.dp, if (selected) Color(0xFFE50914).copy(alpha = 0.35f) else Color(0xFF2C2C2C), RoundedCornerShape(999.dp)),
        ) {
            Text(text = label, modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp), color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun DetailMetaPill(text: String) {
    Box(modifier = Modifier.background(Color(0xFF1E1E1E), RoundedCornerShape(999.dp)).border(1.dp, Color(0xFF2C2C2C), RoundedCornerShape(999.dp)).padding(horizontal = 10.dp, vertical = 5.dp)) {
        Text(text = text, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun DetailLabelChip(text: String) {
    Box(modifier = Modifier.background(Color(0xFF1E1E1E), RoundedCornerShape(999.dp)).border(1.dp, Color(0xFF2C2C2C), RoundedCornerShape(999.dp)).padding(horizontal = 10.dp, vertical = 5.dp)) {
        Text(text = text, color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun DetailSectionCard(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    Box(modifier = modifier.background(Color(0xFF111111), RoundedCornerShape(20.dp)).border(1.dp, Color(0xFF2A2A2A), RoundedCornerShape(20.dp)).padding(16.dp)) { content() }
}

@Composable
private fun DetailIconButton(icon: ImageVector, onClick: () -> Unit, label: String) {
    PhucTVFocusCard(onClick = onClick, borderRadius = RoundedCornerShape(999.dp), focusedBorderColor = Color(0xFFFFD15C), focusedBackgroundColor = Color.White.copy(alpha = 0.06f), focusScale = 1.02f) {
        Box(modifier = Modifier.background(Color.Black.copy(alpha = 0.32f), RoundedCornerShape(999.dp)).border(1.dp, Color.White.copy(alpha = 0.10f), RoundedCornerShape(999.dp))) {
            Icon(imageVector = icon, contentDescription = label, tint = Color.White, modifier = Modifier.padding(10.dp))
        }
    }
}

@Composable
private fun DetailActionButton(text: String, icon: ImageVector, filled: Boolean, onClick: () -> Unit) {
    PhucTVFocusCard(onClick = onClick, borderRadius = RoundedCornerShape(14.dp), focusedBorderColor = if (filled) Color(0xFFE50914) else Color(0xFFFFD15C), focusScale = 1.02f) {
        Box(
            modifier = Modifier.background(if (filled) Color(0xFFE50914) else Color(0xFF1A1A1A), RoundedCornerShape(14.dp)).border(1.dp, if (filled) Color(0xFFB9131C) else Color.White.copy(alpha = 0.12f), RoundedCornerShape(14.dp)),
        ) {
            Row(modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                Icon(imageVector = icon, contentDescription = null, tint = Color.White)
                Spacer(modifier = Modifier.width(8.dp))
                Text(text = text, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
private fun DetailTextButton(text: String, onClick: () -> Unit) {
    PhucTVFocusCard(onClick = onClick, borderRadius = RoundedCornerShape(999.dp), focusedBorderColor = Color(0xFFFFD15C), focusScale = 1.02f) {
        Box(modifier = Modifier.background(Color.White.copy(alpha = 0.04f), RoundedCornerShape(999.dp)).border(1.dp, Color(0xFF2C2C2C), RoundedCornerShape(999.dp))) {
            Text(text = text, modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp), color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun DetailGalleryImage(url: String) {
    Box(modifier = Modifier.height(160.dp).aspectRatio(0.7f).background(Color(0xFF1A1A1A), RoundedCornerShape(16.dp))) {
        PhucTVRemoteImage(url = url, modifier = Modifier.fillMaxSize())
    }
}

@Composable
private fun DetailRelatedMovieCard(movie: MovieCard, onClick: (String) -> Unit) {
    Column(modifier = Modifier.width(140.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        PhucTVFocusCard(modifier = Modifier.fillMaxWidth().height(245.dp), onClick = { if (movie.link.trim().isNotEmpty()) onClick(movie.link) }, borderRadius = RoundedCornerShape(16.dp), focusedBorderColor = Color(0xFFFFD15C), focusScale = 1.02f) {
            Box(modifier = Modifier.fillMaxSize().background(Color(0xFF1A1A1A), RoundedCornerShape(16.dp))) {
                PhucTVRemoteImage(url = movie.displayPoster, modifier = Modifier.fillMaxSize())
                Box(modifier = Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Black.copy(alpha = 0.48f), Color.Transparent))))
                if (movie.rating.isNotBlank()) DetailMetaPill(text = movie.rating)
            }
        }
        Text(text = movie.displayTitle, maxLines = 2, overflow = TextOverflow.Ellipsis, color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
        Text(text = movie.displaySubtitle.ifBlank { movie.statusTitle }, maxLines = 1, overflow = TextOverflow.Ellipsis, color = Color.White.copy(alpha = 0.60f), fontSize = 11.sp)
    }
}

@Composable
internal fun DetailLoadingState() {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
    }
}

@Composable
internal fun DetailErrorState(message: String?, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(text = message.orEmpty(), color = Color.White, fontSize = 16.sp)
        Spacer(modifier = Modifier.height(16.dp))
        DetailTextButton(text = "Thử lại", onClick = onRetry)
    }
}

@Preview(showBackground = true, backgroundColor = 0xFF101010)
@Composable
private fun DetailScreenPreview() {
    DetailScreenContent(
        uiState = DetailUiState(isLoading = false, detail = DetailMockData.detail(), selectedTab = DetailSectionTab.episodes, isLiked = true),
        onBack = {},
        onOpenSearch = {},
        onOpenDetail = {},
        onOpenEpisode = { _, _, _, _ -> },
        onRetry = {},
        onSelectTab = {},
        onToggleLike = {},
        onOpenTrailer = {},
    )
}

private fun Double.toStringAsOneDecimal(): String = String.format("%.1f", this)

private fun formatCount(value: Int): String = when {
    value >= 1_000_000 -> String.format("%.1fM", value / 1_000_000.0)
    value >= 1_000 -> String.format("%.1fk", value / 1_000.0)
    else -> value.toString()
}
