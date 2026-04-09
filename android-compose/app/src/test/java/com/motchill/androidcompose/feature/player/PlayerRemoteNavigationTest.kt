package com.motchill.androidcompose.feature.player

import android.content.pm.ActivityInfo
import org.junit.Assert.assertEquals
import org.junit.Test

class PlayerRemoteNavigationTest {
    @Test
    fun `showing controls focuses play pause by default`() {
        assertEquals(
            PlayerFocusedControl.Transport(index = 1),
            playerFocusAfterShowingControls(),
        )
    }

    @Test
    fun `transport left moves to previous control`() {
        val decision = playerHandleVisibleKey(
            focusedControl = PlayerFocusedControl.Transport(index = 1),
            key = PlayerRemoteKey.Left,
            sourceCount = 3,
            selectedSourceIndex = 1,
            durationMs = 200_000L,
        )

        assertEquals(PlayerFocusedControl.Transport(index = 0), decision?.nextFocus)
        assertEquals(PlayerRemoteEffect.NoOp, decision?.effect)
    }

    @Test
    fun `transport up focuses progress`() {
        val decision = playerHandleVisibleKey(
            focusedControl = PlayerFocusedControl.Transport(index = 1),
            key = PlayerRemoteKey.Up,
            sourceCount = 3,
            selectedSourceIndex = 1,
            durationMs = 200_000L,
        )

        assertEquals(PlayerFocusedControl.Progress, decision?.nextFocus)
    }

    @Test
    fun `progress left seeks by flutter step`() {
        val decision = playerHandleVisibleKey(
            focusedControl = PlayerFocusedControl.Progress,
            key = PlayerRemoteKey.Left,
            sourceCount = 3,
            selectedSourceIndex = 1,
            durationMs = 200_000L,
        )

        assertEquals(PlayerFocusedControl.Progress, decision?.nextFocus)
        assertEquals(PlayerRemoteEffect.SeekBy(deltaMs = -6_000L), decision?.effect)
    }

    @Test
    fun `progress up focuses selected source`() {
        val decision = playerHandleVisibleKey(
            focusedControl = PlayerFocusedControl.Progress,
            key = PlayerRemoteKey.Up,
            sourceCount = 3,
            selectedSourceIndex = 2,
            durationMs = 200_000L,
        )

        assertEquals(PlayerFocusedControl.Source(index = 2), decision?.nextFocus)
    }

    @Test
    fun `progress down focuses play pause transport`() {
        val decision = playerHandleVisibleKey(
            focusedControl = PlayerFocusedControl.Progress,
            key = PlayerRemoteKey.Down,
            sourceCount = 3,
            selectedSourceIndex = 1,
            durationMs = 200_000L,
        )

        assertEquals(PlayerFocusedControl.Transport(index = 1), decision?.nextFocus)
    }

    @Test
    fun `source up focuses back button`() {
        val decision = playerHandleVisibleKey(
            focusedControl = PlayerFocusedControl.Source(index = 1),
            key = PlayerRemoteKey.Up,
            sourceCount = 3,
            selectedSourceIndex = 1,
            durationMs = 200_000L,
        )

        assertEquals(PlayerFocusedControl.Back, decision?.nextFocus)
    }

    @Test
    fun `source down focuses progress`() {
        val decision = playerHandleVisibleKey(
            focusedControl = PlayerFocusedControl.Source(index = 1),
            key = PlayerRemoteKey.Down,
            sourceCount = 3,
            selectedSourceIndex = 1,
            durationMs = 200_000L,
        )

        assertEquals(PlayerFocusedControl.Progress, decision?.nextFocus)
    }

    @Test
    fun `source activate selects focused source`() {
        val decision = playerHandleVisibleKey(
            focusedControl = PlayerFocusedControl.Source(index = 1),
            key = PlayerRemoteKey.Activate,
            sourceCount = 3,
            selectedSourceIndex = 0,
            durationMs = 200_000L,
        )

        assertEquals(PlayerFocusedControl.Source(index = 1), decision?.nextFocus)
        assertEquals(PlayerRemoteEffect.SelectSource(index = 1), decision?.effect)
    }

    @Test
    fun `back activate triggers back effect`() {
        val decision = playerHandleVisibleKey(
            focusedControl = PlayerFocusedControl.Back,
            key = PlayerRemoteKey.Activate,
            sourceCount = 3,
            selectedSourceIndex = 0,
            durationMs = 200_000L,
        )

        assertEquals(PlayerFocusedControl.Back, decision?.nextFocus)
        assertEquals(PlayerRemoteEffect.Back, decision?.effect)
    }

    @Test
    fun `transport activate on play pause toggles playback`() {
        val decision = playerHandleVisibleKey(
            focusedControl = PlayerFocusedControl.Transport(index = 1),
            key = PlayerRemoteKey.Activate,
            sourceCount = 3,
            selectedSourceIndex = 1,
            durationMs = 200_000L,
        )

        assertEquals(PlayerFocusedControl.Transport(index = 1), decision?.nextFocus)
        assertEquals(PlayerRemoteEffect.TogglePlayback, decision?.effect)
    }

    @Test
    fun `player requested orientation locks to sensor landscape`() {
        assertEquals(
            ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE,
            playerRequestedOrientation(),
        )
    }
}
