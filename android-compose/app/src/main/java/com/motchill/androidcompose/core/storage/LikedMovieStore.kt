package com.motchill.androidcompose.core.storage

import android.content.Context
import com.motchill.androidcompose.domain.model.MovieCard
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import androidx.core.content.edit

class LikedMovieStore(context: Context) {
    private val prefs = context.getSharedPreferences(LIKED_MOVIE_PREFS, Context.MODE_PRIVATE)

    suspend fun loadMovies(): List<MovieCard> = withContext(Dispatchers.IO) {
        val encodedMovies = prefs.getStringSet(LIKED_MOVIE_CARDS_KEY, null)
            ?.toList()
            .orEmpty()
        if (encodedMovies.isNotEmpty()) {
            return@withContext MovieSnapshotCodec.decodeMovies(encodedMovies)
        }

        val ids = prefs.getStringSet(LIKED_MOVIE_IDS_KEY, null).orEmpty()
        return@withContext ids.mapNotNull { id -> id.toIntOrNull()?.let(::movieFromId) }
    }

    suspend fun loadIds(): Set<Int> {
        return loadMovies().map { it.id }.toSet()
    }

    suspend fun isLiked(movieId: Int): Boolean {
        return loadIds().contains(movieId)
    }

    suspend fun toggleMovie(movie: MovieCard): List<MovieCard> = withContext(Dispatchers.IO) {
        val current = loadMovies().toMutableList()
        val index = current.indexOfFirst { it.id == movie.id }
        if (index == -1) {
            current.add(movie)
        } else {
            current.removeAt(index)
        }
        saveMovies(current)
        current
    }

    suspend fun toggle(movieId: Int): Set<Int> = withContext(Dispatchers.IO) {
        val current = loadMovies().toMutableList()
        val index = current.indexOfFirst { it.id == movieId }
        if (index == -1) {
            current.add(movieFromId(movieId))
        } else {
            current.removeAt(index)
        }
        saveMovies(current)
        current.map { it.id }.toSet()
    }

    private fun saveMovies(movies: List<MovieCard>) {
        prefs.edit {
            putStringSet(
                LIKED_MOVIE_CARDS_KEY,
                MovieSnapshotCodec.encodeMovies(movies).toSet(),
            )
                .putStringSet(
                    LIKED_MOVIE_IDS_KEY,
                    movies.map { it.id.toString() }.toSet(),
                )
        }
    }

    private fun movieFromId(movieId: Int): MovieCard {
        return MovieCard(
            id = movieId,
            name = "Movie $movieId",
            otherName = "",
            avatar = "",
            bannerThumb = "",
            avatarThumb = "",
            description = "",
            banner = "",
            imageIcon = "",
            link = "",
            quantity = "",
            rating = "",
            year = 0,
            statusTitle = "",
        )
    }
}

