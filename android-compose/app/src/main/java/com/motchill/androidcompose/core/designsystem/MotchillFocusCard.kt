package com.motchill.androidcompose.core.designsystem

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.dp

@Composable
fun MotchillFocusCard(
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
    enabled: Boolean = true,
    borderRadius: RoundedCornerShape = RoundedCornerShape(18.dp),
    focusedBorderColor: Color = Color(0xFFFFD15C),
    focusedBackgroundColor: Color? = null,
    focusScale: Float = 1.03f,
    content: @Composable () -> Unit,
) {
    var isFocused by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(
        targetValue = if (isFocused) focusScale else 1f,
        label = "motchillFocusScale",
    )

    val borderColor = if (isFocused) focusedBorderColor else Color.White.copy(alpha = 0.10f)
    val background = focusedBackgroundColor?.takeIf { isFocused }
        ?: if (isFocused) Color.White.copy(alpha = 0.06f) else Color.Transparent

    Box(
        modifier = modifier
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
                transformOrigin = TransformOrigin.Center
            }
            .shadow(
                elevation = if (isFocused) 10.dp else 0.dp,
                shape = borderRadius,
                ambientColor = focusedBorderColor.copy(alpha = 0.20f),
                spotColor = focusedBorderColor.copy(alpha = 0.20f),
            )
            .background(background, borderRadius)
            .border(width = if (isFocused) 2.dp else 1.dp, color = borderColor, shape = borderRadius)
            .clip(borderRadius)
            .onFocusChanged { isFocused = it.isFocused }
            .clickable(
                enabled = enabled,
                indication = null,
                interactionSource = remember { MutableInteractionSource() },
                onClick = onClick,
            )
            .padding(0.dp),
    ) {
        content()
    }
}
