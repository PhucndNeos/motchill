package com.motchill.androidcompose.feature.home

import com.motchill.androidcompose.domain.model.HomeSection
import com.motchill.androidcompose.domain.model.MovieCard

data class HomeUiState(
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
    val sections: List<HomeSection> = emptyList(),
    val popupAdTitle: String? = null,
    val selectedHeroIndex: Int = 0,
) {
    val heroMovies: List<MovieCard>
        get() {
            val slideSection = slideSection(sections)
            val slideMovies = slideSection?.products.orEmpty()
            if (slideMovies.isNotEmpty()) return slideMovies
            return contentSections(sections).flatMap { it.products }
        }

    val contentSections: List<HomeSection>
        get() = contentSections(sections)

    val selectedMovie: MovieCard?
        get() {
            val movies = heroMovies
            if (movies.isEmpty()) return null
            val safeIndex = selectedHeroIndex.coerceIn(0, movies.lastIndex)
            return movies[safeIndex]
        }

    val previewMovies: List<MovieCard>
        get() {
            val selected = selectedMovie ?: return emptyList()
            return heroMovies.filterNot { it.id == selected.id }
        }

    val isEmpty: Boolean
        get() = heroMovies.isEmpty() && contentSections.isEmpty()
}

internal fun slideSection(sections: List<HomeSection>): HomeSection? {
    for (section in sections) {
        if (section.key == "slide") return section
    }
    return sections.firstOrNull()
}

internal fun contentSections(sections: List<HomeSection>): List<HomeSection> {
    return sections.filterNot { it.key == "slide" }
}

internal fun sectionSearchSlug(section: HomeSection): String {
    val key = section.key.trim().lowercase()
    if (key.isNotEmpty() && key != "slide") {
        return key
    }

    val normalized = section.title.trim().lowercase()
    if (normalized.isEmpty()) return ""

    return normalized
        .replace(Regex("[^a-z0-9]+"), "-")
        .replace(Regex("-+"), "-")
        .trim('-')
}
