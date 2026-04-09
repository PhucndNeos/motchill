package com.motchill.androidcompose.feature.player

import com.motchill.androidcompose.domain.model.PlaySource
import com.motchill.androidcompose.domain.model.PlayTrack

data class PlayerTrackSelection(
    val audioTrack: PlayTrack?,
    val subtitleTrack: PlayTrack?,
    val frameTrack: PlayTrack? = null,
)

data class PlayerUiState(
    val movieId: Int,
    val episodeId: Int,
    val movieTitle: String = "",
    val episodeLabel: String = "",
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
    val sources: List<PlaySource> = emptyList(),
    val selectedSourceIndex: Int = 0,
    val selectedAudioTrack: PlayTrack? = null,
    val selectedSubtitleTrack: PlayTrack? = null,
) {
    val playableSources: List<PlaySource>
        get() = playableSources(sources)

    val selectedSource: PlaySource?
        get() = playableSources.getOrNull(selectedSourceIndex)

    val canShowSourceRail: Boolean
        get() = playableSources.size > 1

    companion object {
        fun loading(movieId: Int, episodeId: Int): PlayerUiState {
            return PlayerUiState(movieId = movieId, episodeId = episodeId)
        }

        fun loaded(
            movieId: Int,
            episodeId: Int,
            movieTitle: String = "",
            episodeLabel: String = "",
            sources: List<PlaySource>,
        ): PlayerUiState {
            val playable = playableSources(sources)
            val selectedSource = playable.firstOrNull()
            val trackSelection = selectedSource?.let(::defaultTrackSelection)
            return PlayerUiState(
                movieId = movieId,
                episodeId = episodeId,
                movieTitle = movieTitle,
                episodeLabel = episodeLabel,
                isLoading = false,
                errorMessage = null,
                sources = playable,
                selectedSourceIndex = if (playable.isEmpty()) 0 else 0,
                selectedAudioTrack = trackSelection?.audioTrack,
                selectedSubtitleTrack = trackSelection?.subtitleTrack,
            )
        }
    }
}

fun playableSources(sources: List<PlaySource>): List<PlaySource> {
    return sources.filter { it.isStream }
}

fun defaultSelectedSourceIndex(sources: List<PlaySource>): Int {
    return if (playableSources(sources).isEmpty()) -1 else 0
}

fun defaultTrackSelection(source: PlaySource): PlayerTrackSelection {
    return PlayerTrackSelection(
        audioTrack = source.defaultAudioTrack,
        subtitleTrack = source.defaultSubtitleTrack,
    )
}
