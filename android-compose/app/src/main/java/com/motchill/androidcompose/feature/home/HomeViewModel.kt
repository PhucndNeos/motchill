package com.motchill.androidcompose.feature.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.motchill.androidcompose.core.config.RemoteConfigStore
import com.motchill.androidcompose.data.repository.MotchillRepository
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

internal class HomeViewModel(
    private val repository: MotchillRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                errorMessage = null,
            )

            runCatching {
                RemoteConfigStore.clear()
                RemoteConfigStore.refreshFromRemote()
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = error.message ?: error::class.java.simpleName,
                )
                return@launch
            }

            runCatching {
                coroutineScope {
                    val sectionsDeferred = async { repository.loadHome() }
                    val popupDeferred = async { repository.loadPopupAd() }
                    val sections = sectionsDeferred.await()
                    val popupAd = popupDeferred.await()
                    _uiState.value = HomeUiState(
                        isLoading = false,
                        errorMessage = null,
                        sections = sections,
                        popupAdTitle = popupAd?.name?.trim().orEmpty().ifBlank { null },
                        selectedHeroIndex = 0,
                    )
                }
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = error.message ?: error::class.java.simpleName,
                )
            }
        }
    }

    fun selectHeroMovie(movieId: Int) {
        val movies = _uiState.value.heroMovies
        val nextIndex = movies.indexOfFirst { it.id == movieId }
        if (nextIndex == -1) return
        _uiState.value = _uiState.value.copy(selectedHeroIndex = nextIndex)
    }

    companion object {
        fun factory(repository: MotchillRepository): ViewModelProvider.Factory {
            return object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    if (modelClass.isAssignableFrom(HomeViewModel::class.java)) {
                        return HomeViewModel(repository) as T
                    }
                    throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
                }
            }
        }
    }
}

