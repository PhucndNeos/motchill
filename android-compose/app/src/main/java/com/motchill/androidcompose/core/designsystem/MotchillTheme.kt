package com.motchill.androidcompose.core.designsystem

import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val MotchillDarkColorScheme = darkColorScheme(
    background = Color(0xFF050505),
    surface = Color(0xFF101010),
    surfaceVariant = Color(0xFF1A1A1A),
    primary = Color(0xFFE50914),
    secondary = Color(0xFFE0B85D),
    tertiary = Color(0xFFB0B0B0),
    outline = Color(0xFF2A2A2A),
    onPrimary = Color.White,
    onSecondary = Color.Black,
    onBackground = Color.White,
    onSurface = Color.White,
    onSurfaceVariant = Color(0xFFE0E0E0),
)

@Composable
fun MotchillTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = MotchillDarkColorScheme,
        typography = MotchillTypography,
        content = content,
    )
}
