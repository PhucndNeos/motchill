package com.motchill.androidcompose.feature.player

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.motchill.androidcompose.data.repository.MotchillRepository
import com.motchill.androidcompose.domain.model.PlayTrack
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class PlayerViewModel(
    private val repository: MotchillRepository,
    private val movieId: Int,
    private val episodeId: Int,
    movieTitle: String,
    episodeLabel: String,
) : ViewModel() {
    private val _uiState = MutableStateFlow(
        PlayerUiState.loading(movieId = movieId, episodeId = episodeId).copy(
            movieTitle = movieTitle,
            episodeLabel = episodeLabel,
        ),
    )
    val uiState: StateFlow<PlayerUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun load() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                errorMessage = null,
            )

            runCatching {
                val sources = repository.loadEpisodeSources(movieId, episodeId)
                val playable = playableSources(sources)
                if (playable.isEmpty()) {
                    _uiState.value = PlayerUiState(
                        movieId = movieId,
                        episodeId = episodeId,
                        movieTitle = _uiState.value.movieTitle,
                        episodeLabel = _uiState.value.episodeLabel,
                        isLoading = false,
                        errorMessage = "No source available, try again later",
                        sources = emptyList(),
                        selectedSourceIndex = 0,
                    )
                    return@runCatching
                }

                val firstSource = playable.first()
                val selection = defaultTrackSelection(firstSource)
                _uiState.value = PlayerUiState(
                    movieId = movieId,
                    episodeId = episodeId,
                    movieTitle = _uiState.value.movieTitle,
                    episodeLabel = _uiState.value.episodeLabel,
                    isLoading = false,
                    errorMessage = null,
                    sources = playable,
                    selectedSourceIndex = 0,
                    selectedAudioTrack = selection.audioTrack,
                    selectedSubtitleTrack = selection.subtitleTrack,
                )
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = error.message ?: error::class.java.simpleName,
                )
            }
        }
    }

    fun selectSource(index: Int) {
        val sources = _uiState.value.playableSources
        if (index !in sources.indices) return

        val source = sources[index]
        val selection = defaultTrackSelection(source)
        _uiState.value = _uiState.value.copy(
            selectedSourceIndex = index,
            selectedAudioTrack = selection.audioTrack,
            selectedSubtitleTrack = selection.subtitleTrack,
        )
    }

    fun selectAudioTrack(track: PlayTrack?) {
        if (track != null && track !in selectedSourceTracks().audioTracks) return
        _uiState.value = _uiState.value.copy(selectedAudioTrack = track)
    }

    fun selectSubtitleTrack(track: PlayTrack?) {
        if (track != null && track !in selectedSourceTracks().subtitleTracks) return
        _uiState.value = _uiState.value.copy(selectedSubtitleTrack = track)
    }

    private fun selectedSourceTracks(): PlayerSourceTracks {
        val source = _uiState.value.selectedSource ?: return PlayerSourceTracks(
            audioTracks = emptyList(),
            subtitleTracks = emptyList(),
        )
        return PlayerSourceTracks(
            audioTracks = source.audioTracks,
            subtitleTracks = source.subtitleTracks,
        )
    }

    private data class PlayerSourceTracks(
        val audioTracks: List<PlayTrack>,
        val subtitleTracks: List<PlayTrack>,
    )

    companion object {
        fun factory(
            repository: MotchillRepository,
            movieId: Int,
            episodeId: Int,
            movieTitle: String,
            episodeLabel: String,
        ): ViewModelProvider.Factory {
            return object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    if (modelClass.isAssignableFrom(PlayerViewModel::class.java)) {
                        return PlayerViewModel(
                            repository = repository,
                            movieId = movieId,
                            episodeId = episodeId,
                            movieTitle = movieTitle,
                            episodeLabel = episodeLabel,
                        ) as T
                    }
                    throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
                }
            }
        }
    }
}
