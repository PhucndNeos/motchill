package com.motchill.androidcompose.feature.player

import android.content.pm.ActivityInfo
import kotlin.math.roundToLong

enum class PlayerRemoteKey {
    Activate,
    Left,
    Right,
    Up,
    Down,
    Other,
}

sealed interface PlayerFocusedControl {
    data object Back : PlayerFocusedControl
    data object Progress : PlayerFocusedControl
    data class Source(val index: Int) : PlayerFocusedControl
    data class Transport(val index: Int) : PlayerFocusedControl
}

sealed interface PlayerRemoteEffect {
    data object NoOp : PlayerRemoteEffect
    data object Back : PlayerRemoteEffect
    data object TogglePlayback : PlayerRemoteEffect
    data class SeekBy(val deltaMs: Long) : PlayerRemoteEffect
    data class SelectSource(val index: Int) : PlayerRemoteEffect
}

data class PlayerRemoteDecision(
    val nextFocus: PlayerFocusedControl,
    val effect: PlayerRemoteEffect = PlayerRemoteEffect.NoOp,
)

fun playerDefaultFocusedControl(): PlayerFocusedControl {
    return PlayerFocusedControl.Transport(index = 1)
}

fun playerFocusAfterShowingControls(): PlayerFocusedControl {
    return playerDefaultFocusedControl()
}

fun playerHandleVisibleKey(
    focusedControl: PlayerFocusedControl,
    key: PlayerRemoteKey,
    sourceCount: Int,
    selectedSourceIndex: Int,
    durationMs: Long,
): PlayerRemoteDecision? {
    return when (focusedControl) {
        PlayerFocusedControl.Back -> handleBackKey(
            key = key,
            sourceCount = sourceCount,
        )

        PlayerFocusedControl.Progress -> handleProgressKey(
            key = key,
            sourceCount = sourceCount,
            selectedSourceIndex = selectedSourceIndex,
            durationMs = durationMs,
        )

        is PlayerFocusedControl.Source -> handleSourceKey(
            focusedControl = focusedControl,
            key = key,
            sourceCount = sourceCount,
        )

        is PlayerFocusedControl.Transport -> handleTransportKey(
            focusedControl = focusedControl,
            key = key,
            durationMs = durationMs,
        )
    }
}

fun playerHandleHiddenKey(key: PlayerRemoteKey): PlayerRemoteDecision? {
    return when (key) {
        PlayerRemoteKey.Activate -> PlayerRemoteDecision(
            nextFocus = playerDefaultFocusedControl(),
        )

        PlayerRemoteKey.Left -> PlayerRemoteDecision(
            nextFocus = playerDefaultFocusedControl(),
            effect = PlayerRemoteEffect.SeekBy(deltaMs = -10_000L),
        )

        PlayerRemoteKey.Right -> PlayerRemoteDecision(
            nextFocus = playerDefaultFocusedControl(),
            effect = PlayerRemoteEffect.SeekBy(deltaMs = 10_000L),
        )

        PlayerRemoteKey.Up,
        PlayerRemoteKey.Down,
        PlayerRemoteKey.Other,
        -> null
    }
}

fun playerDoubleTapSeekDelta(
    tapX: Float,
    surfaceWidthPx: Int,
): Long? {
    if (surfaceWidthPx <= 0) return null
    return if (tapX < surfaceWidthPx / 2f) {
        -10_000L
    } else {
        10_000L
    }
}

private fun handleBackKey(
    key: PlayerRemoteKey,
    sourceCount: Int,
): PlayerRemoteDecision? {
    return when (key) {
        PlayerRemoteKey.Activate -> PlayerRemoteDecision(
            nextFocus = PlayerFocusedControl.Back,
            effect = PlayerRemoteEffect.Back,
        )

        PlayerRemoteKey.Down -> PlayerRemoteDecision(
            nextFocus = if (sourceCount > 0) {
                PlayerFocusedControl.Source(index = 0)
            } else {
                PlayerFocusedControl.Progress
            },
        )

        PlayerRemoteKey.Left,
        PlayerRemoteKey.Right,
        PlayerRemoteKey.Up,
        -> PlayerRemoteDecision(nextFocus = PlayerFocusedControl.Back)

        PlayerRemoteKey.Other -> null
    }
}

private fun handleSourceKey(
    focusedControl: PlayerFocusedControl.Source,
    key: PlayerRemoteKey,
    sourceCount: Int,
): PlayerRemoteDecision? {
    if (sourceCount <= 0) {
        return PlayerRemoteDecision(nextFocus = PlayerFocusedControl.Progress)
    }

    return when (key) {
        PlayerRemoteKey.Activate -> PlayerRemoteDecision(
            nextFocus = focusedControl,
            effect = PlayerRemoteEffect.SelectSource(focusedControl.index),
        )

        PlayerRemoteKey.Left -> PlayerRemoteDecision(
            nextFocus = PlayerFocusedControl.Source(
                index = (focusedControl.index - 1).coerceAtLeast(0),
            ),
        )

        PlayerRemoteKey.Right -> PlayerRemoteDecision(
            nextFocus = PlayerFocusedControl.Source(
                index = (focusedControl.index + 1).coerceAtMost(sourceCount - 1),
            ),
        )

        PlayerRemoteKey.Up -> PlayerRemoteDecision(nextFocus = PlayerFocusedControl.Back)
        PlayerRemoteKey.Down -> PlayerRemoteDecision(nextFocus = PlayerFocusedControl.Progress)
        PlayerRemoteKey.Other -> null
    }
}

private fun handleProgressKey(
    key: PlayerRemoteKey,
    sourceCount: Int,
    selectedSourceIndex: Int,
    durationMs: Long,
): PlayerRemoteDecision? {
    return when (key) {
        PlayerRemoteKey.Activate -> PlayerRemoteDecision(nextFocus = PlayerFocusedControl.Progress)
        PlayerRemoteKey.Left -> PlayerRemoteDecision(
            nextFocus = PlayerFocusedControl.Progress,
            effect = PlayerRemoteEffect.SeekBy(deltaMs = -playerSeekStep(durationMs)),
        )

        PlayerRemoteKey.Right -> PlayerRemoteDecision(
            nextFocus = PlayerFocusedControl.Progress,
            effect = PlayerRemoteEffect.SeekBy(deltaMs = playerSeekStep(durationMs)),
        )

        PlayerRemoteKey.Up -> PlayerRemoteDecision(
            nextFocus = if (sourceCount > 0) {
                PlayerFocusedControl.Source(
                    index = selectedSourceIndex.coerceIn(0, sourceCount - 1),
                )
            } else {
                PlayerFocusedControl.Back
            },
        )

        PlayerRemoteKey.Down -> PlayerRemoteDecision(
            nextFocus = playerDefaultFocusedControl(),
        )

        PlayerRemoteKey.Other -> null
    }
}

private fun handleTransportKey(
    focusedControl: PlayerFocusedControl.Transport,
    key: PlayerRemoteKey,
    durationMs: Long,
): PlayerRemoteDecision? {
    return when (key) {
        PlayerRemoteKey.Activate -> PlayerRemoteDecision(
            nextFocus = focusedControl,
            effect = when (focusedControl.index) {
                0 -> PlayerRemoteEffect.SeekBy(deltaMs = -10_000L)
                1 -> PlayerRemoteEffect.TogglePlayback
                2 -> PlayerRemoteEffect.SeekBy(deltaMs = 10_000L)
                else -> PlayerRemoteEffect.NoOp
            },
        )

        PlayerRemoteKey.Left -> PlayerRemoteDecision(
            nextFocus = PlayerFocusedControl.Transport(
                index = (focusedControl.index - 1).coerceAtLeast(0),
            ),
        )

        PlayerRemoteKey.Right -> PlayerRemoteDecision(
            nextFocus = PlayerFocusedControl.Transport(
                index = (focusedControl.index + 1).coerceAtMost(2),
            ),
        )

        PlayerRemoteKey.Up -> PlayerRemoteDecision(nextFocus = PlayerFocusedControl.Progress)
        PlayerRemoteKey.Down -> PlayerRemoteDecision(nextFocus = focusedControl)
        PlayerRemoteKey.Other -> null
    }
}

fun playerSeekStep(durationMs: Long): Long {
    if (durationMs <= 0L) {
        return 10_000L
    }

    val scaled = (durationMs * 0.03).roundToLong().coerceAtLeast(0L)
    return scaled.coerceIn(5_000L, 30_000L)
}

fun playerRequestedOrientation(): Int {
    return ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
}
