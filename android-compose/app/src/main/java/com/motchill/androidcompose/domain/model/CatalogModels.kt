package com.motchill.androidcompose.domain.model

data class SimpleLabel(
    val id: Int,
    val name: String,
    val link: String,
    val displayColumn: Int,
)

data class HomeSection(
    val title: String,
    val key: String,
    val products: List<MovieCard>,
    val isCarousel: Boolean,
)

data class MovieCard(
    val id: Int,
    val name: String,
    val otherName: String,
    val avatar: String,
    val bannerThumb: String,
    val avatarThumb: String,
    val description: String,
    val banner: String,
    val imageIcon: String,
    val link: String,
    val quantity: String,
    val rating: String,
    val year: Int,
    val statusTitle: String,
    val statusRaw: String = "",
    val statusText: String = "",
    val director: String = "",
    val time: String = "",
    val trailer: String = "",
    val showTimes: String = "",
    val moreInfo: String = "",
    val castString: String = "",
    val episodesTotal: Int = 0,
    val viewNumber: Int = 0,
    val ratePoint: Double = 0.0,
    val photoUrls: List<String> = emptyList(),
    val previewPhotoUrls: List<String> = emptyList(),
) {
    val displayTitle: String
        get() = name.trim().ifEmpty { "Untitled" }

    val displaySubtitle: String
        get() = otherName.trim().ifEmpty { description.trim() }

    val displayPoster: String
        get() = avatarThumb.ifEmpty { avatar }

    val displayBanner: String
        get() = banner.ifEmpty { bannerThumb }
}

data class NavbarItem(
    val id: Int,
    val name: String,
    val slug: String,
    val items: List<NavbarItem>,
    val isExistChild: Boolean,
)

data class PopupAdConfig(
    val id: Int,
    val name: String,
    val type: String,
    val desktopLink: String,
    val mobileLink: String,
)

data class MovieEpisode(
    val id: Int,
    val episodeNumber: Any?,
    val name: String,
    val fullLink: String,
    val status: Any?,
    val type: String,
) {
    val label: String
        get() = when {
            name.trim().isNotEmpty() -> name.trim()
            episodeNumber != null -> "Tập $episodeNumber"
            else -> "Episode"
        }
}

data class MovieDetail(
    val movie: MovieCard,
    val relatedMovies: List<MovieCard>,
    val countries: List<SimpleLabel>,
    val categories: List<SimpleLabel>,
    val episodes: List<MovieEpisode>,
) {
    val id: Int
        get() = movie.id

    val title: String
        get() = movie.name

    val otherName: String
        get() = movie.otherName

    val avatar: String
        get() = movie.avatar

    val avatarThumb: String
        get() = movie.avatarThumb

    val banner: String
        get() = movie.banner

    val bannerThumb: String
        get() = movie.bannerThumb

    val description: String
        get() = movie.description

    val quality: String
        get() = movie.quantity

    val statusTitle: String
        get() = movie.statusTitle

    val statusRaw: String
        get() = movie.statusRaw

    val statusText: String
        get() = movie.statusText

    val director: String
        get() = movie.director

    val time: String
        get() = movie.time

    val trailer: String
        get() = movie.trailer

    val showTimes: String
        get() = movie.showTimes

    val moreInfo: String
        get() = movie.moreInfo

    val castString: String
        get() = movie.castString

    val year: Int
        get() = movie.year

    val episodesTotal: Int
        get() = movie.episodesTotal

    val viewNumber: Int
        get() = movie.viewNumber

    val ratePoint: Double
        get() = movie.ratePoint

    val photoUrls: List<String>
        get() = movie.photoUrls

    val previewPhotoUrls: List<String>
        get() = movie.previewPhotoUrls
}

class SectionIndex(
    val value: Int,
    val label: String,
)

val MovieDetail.displayBackdrop: String
    get() = when {
        banner.isNotEmpty() -> banner
        avatar.isNotEmpty() -> avatar
        bannerThumb.isNotEmpty() -> bannerThumb
        else -> avatarThumb
    }
