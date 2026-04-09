package com.motchill.androidcompose.feature.detail

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.motchill.androidcompose.core.storage.LikedMovieStore
import com.motchill.androidcompose.data.repository.MotchillRepository
import com.motchill.androidcompose.domain.model.MovieCard
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class DetailViewModel(
    private val repository: MotchillRepository,
    private val likedMovieStore: LikedMovieStore,
    private val slug: String,
) : ViewModel() {
    private val _uiState = MutableStateFlow(DetailUiState())
    val uiState: StateFlow<DetailUiState> = _uiState.asStateFlow()

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
                val detail = repository.loadDetail(slug)
                val liked = detail.id > 0 && likedMovieStore.isLiked(detail.id)
                _uiState.value = DetailUiState(
                    isLoading = false,
                    errorMessage = null,
                    detail = detail,
                    selectedTab = defaultDetailTab(detail),
                    isLiked = liked,
                )
            }.onFailure { error ->
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    errorMessage = error.message ?: error::class.java.simpleName,
                )
            }
        }
    }

    fun selectTab(tab: DetailSectionTab) {
        _uiState.value = _uiState.value.copy(selectedTab = tab)
    }

    fun toggleLike() {
        val detail = _uiState.value.detail ?: return
        if (detail.id == 0) return

        viewModelScope.launch {
            likedMovieStore.toggleMovie(
                MovieCard(
                    id = detail.id,
                    name = detail.title,
                    otherName = detail.otherName,
                    avatar = detail.avatar,
                    bannerThumb = detail.bannerThumb,
                    avatarThumb = detail.avatarThumb,
                    description = detail.description,
                    banner = detail.banner,
                    imageIcon = "",
                    link = detail.movie.link,
                    quantity = detail.quality,
                    rating = if (detail.ratePoint > 0) detail.ratePoint.toString() else "",
                    year = detail.year,
                    statusTitle = detail.statusTitle,
                    statusRaw = detail.statusRaw,
                    statusText = detail.statusText,
                    director = detail.director,
                    time = detail.time,
                    trailer = detail.trailer,
                    showTimes = detail.showTimes,
                    moreInfo = detail.moreInfo,
                    castString = detail.castString,
                    episodesTotal = detail.episodesTotal,
                    viewNumber = detail.viewNumber,
                    ratePoint = detail.ratePoint,
                    photoUrls = detail.photoUrls,
                    previewPhotoUrls = detail.previewPhotoUrls,
                ),
            )
            _uiState.value = _uiState.value.copy(isLiked = !_uiState.value.isLiked)
        }
    }

    companion object {
        fun factory(
            repository: MotchillRepository,
            likedMovieStore: LikedMovieStore,
            slug: String,
        ): ViewModelProvider.Factory {
            return object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    if (modelClass.isAssignableFrom(DetailViewModel::class.java)) {
                        return DetailViewModel(repository, likedMovieStore, slug) as T
                    }
                    throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
                }
            }
        }
    }
}

