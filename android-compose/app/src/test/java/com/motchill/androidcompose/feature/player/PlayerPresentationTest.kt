package com.motchill.androidcompose.feature.player

import com.motchill.androidcompose.domain.model.PlaySource
import com.motchill.androidcompose.domain.model.PlayTrack
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PlayerPresentationTest {
    @Test
    fun `playable sources exclude frame sources`() {
        val sources = listOf(
            playSource(sourceId = 1, isFrame = false),
            playSource(sourceId = 2, isFrame = true),
            playSource(sourceId = 3, isFrame = false),
        )

        val result = playableSources(sources)

        assertEquals(listOf(1, 3), result.map { it.sourceId })
    }

    @Test
    fun `default selected source index points at first playable source`() {
        val sources = listOf(
            playSource(sourceId = 11, isFrame = true),
            playSource(sourceId = 12, isFrame = false),
            playSource(sourceId = 13, isFrame = false),
        )

        assertEquals(0, defaultSelectedSourceIndex(sources))
    }

    @Test
    fun `track selection prefers default tracks from selected source`() {
        val source = playSource(
            sourceId = 21,
            isFrame = false,
            tracks = listOf(
                playTrack(kind = "audio", file = "en.m3u8", label = "English", isDefault = false),
                playTrack(kind = "audio", file = "vi.m3u8", label = "Vietnamese", isDefault = true),
                playTrack(kind = "subtitle", file = "vi.vtt", label = "VI", isDefault = true),
            ),
        )

        val selection = defaultTrackSelection(source)

        assertEquals("Vietnamese", selection.audioTrack?.displayLabel)
        assertEquals("VI", selection.subtitleTrack?.displayLabel)
        assertNull(selection.frameTrack)
    }

    @Test
    fun `loaded ui state filters frame sources and selects the first playable source`() {
        val state = PlayerUiState.loaded(
            movieId = 99,
            episodeId = 7,
            sources = listOf(
                playSource(sourceId = 1, isFrame = true),
                playSource(
                    sourceId = 2,
                    isFrame = false,
                    tracks = listOf(
                        playTrack(
                            kind = "subtitle",
                            file = "https://example.com/sub.vtt",
                            label = "VI",
                            isDefault = true,
                        ),
                    ),
                ),
                playSource(sourceId = 3, isFrame = false),
            ),
        )

        assertEquals(false, state.isLoading)
        assertEquals(listOf(2, 3), state.playableSources.map { it.sourceId })
        assertEquals(0, state.selectedSourceIndex)
        assertEquals(2, state.selectedSource?.sourceId)
        assertEquals("VI", state.selectedSubtitleTrack?.displayLabel)
    }

    private fun playSource(
        sourceId: Int,
        isFrame: Boolean,
        tracks: List<PlayTrack> = emptyList(),
    ): PlaySource {
        return PlaySource(
            sourceId = sourceId,
            serverName = "Server $sourceId",
            link = "https://cdn.example.com/$sourceId.m3u8",
            subtitle = "",
            type = 0,
            isFrame = isFrame,
            quality = "1080p",
            tracks = tracks,
        )
    }

    private fun playTrack(
        kind: String,
        file: String,
        label: String,
        isDefault: Boolean,
    ): PlayTrack {
        return PlayTrack(
            kind = kind,
            file = file,
            label = label,
            isDefault = isDefault,
        )
    }
}
