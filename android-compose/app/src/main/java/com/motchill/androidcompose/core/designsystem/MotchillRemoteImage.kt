package com.motchill.androidcompose.core.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BrokenImage
import androidx.compose.material.icons.outlined.MovieCreation
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil.compose.SubcomposeAsyncImage
import coil.request.ImageRequest

@Composable
fun MotchillRemoteImage(
    url: String,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Crop,
    placeholderColor: Color = Color(0xFF1A1A1A),
    placeholderIconColor: Color = Color.White.copy(alpha = 0.24f),
    errorIconColor: Color = Color.White.copy(alpha = 0.38f),
    iconSize: Dp = 42.dp,
) {
    if (url.isBlank()) {
        MotchillImagePlaceholder(
            modifier = modifier,
            color = placeholderColor,
            iconTint = errorIconColor,
            iconSize = iconSize,
        )
        return
    }

    val context = LocalContext.current
    SubcomposeAsyncImage(
        model = ImageRequest.Builder(context)
            .data(url)
            .addHeader("User-Agent", "Mozilla/5.0 (MotchillApiBase)")
            .addHeader("Accept", "image/avif,image/webp,image/apng,image/*,*/*;q=0.8")
            .crossfade(true)
            .build(),
        contentDescription = null,
        contentScale = contentScale,
        modifier = modifier,
        loading = {
            MotchillImagePlaceholder(
                modifier = Modifier.fillMaxSize(),
                iconTint = placeholderIconColor,
                iconSize = iconSize,
            )
        },
        error = {
            MotchillBrokenImagePlaceholder(
                modifier = Modifier.fillMaxSize(),
                iconTint = errorIconColor,
                iconSize = iconSize,
            )
        },
    )
}

@Composable
fun MotchillImagePlaceholder(
    modifier: Modifier = Modifier,
    color: Color = Color(0xFF1A1A1A),
    iconTint: Color = Color.White.copy(alpha = 0.24f),
    iconSize: Dp = 42.dp,
) {
    Box(
        modifier = modifier.background(color),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = Icons.Outlined.MovieCreation,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier.size(iconSize),
        )
    }
}

@Composable
fun MotchillBrokenImagePlaceholder(
    modifier: Modifier = Modifier,
    color: Color = Color(0xFF1A1A1A),
    iconTint: Color = Color.White.copy(alpha = 0.38f),
    iconSize: Dp = 42.dp,
) {
    Box(
        modifier = modifier.background(color),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = Icons.Outlined.BrokenImage,
            contentDescription = null,
            tint = iconTint,
            modifier = Modifier.size(iconSize),
        )
    }
}
