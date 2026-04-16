package com.motchill.androidcompose.core.supabase

import com.motchill.androidcompose.domain.model.MovieCard

class SupabaseLikedMovieStore(
    private val client: SupabaseRestClient,
    private val authSessionProvider: AuthSessionProvider,
) : LikedMovieRemoteStore {
    override suspend fun loadMovies(): List<MovieCard> {
        val user = authSessionProvider.userId ?: return emptyList()
        val accessToken = authSessionProvider.accessToken ?: return emptyList()
        return client.loadLikedMovies(user, accessToken)
    }

    override suspend fun toggleMovie(movie: MovieCard): List<MovieCard> {
        val user = authSessionProvider.userId ?: return emptyList()
        val accessToken = authSessionProvider.accessToken ?: return emptyList()
        return client.toggleLikedMovie(user, accessToken, movie)
    }

    override suspend fun importLegacyMovies(movies: List<MovieCard>) {
        if (movies.isEmpty()) return
        val user = authSessionProvider.userId ?: return
        val accessToken = authSessionProvider.accessToken ?: return
        client.upsertLikedMovies(user, accessToken, movies)
    }
}
