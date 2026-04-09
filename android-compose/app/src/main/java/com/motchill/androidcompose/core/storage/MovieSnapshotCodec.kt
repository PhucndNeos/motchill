package com.motchill.androidcompose.core.storage

import com.motchill.androidcompose.data.remote.toMovieCard
import com.motchill.androidcompose.domain.model.MovieCard
import org.json.JSONArray
import org.json.JSONObject

object MovieSnapshotCodec {
    fun encodeMovies(movies: List<MovieCard>): List<String> {
        return movies.map { encodeMovie(it) }
    }

    fun decodeMovies(encodedMovies: List<String>): List<MovieCard> {
        return encodedMovies.mapNotNull { decodeMovie(it) }
    }

    fun encodeMovie(movie: MovieCard): String {
        val json = JSONObject()
            .put("Id", movie.id)
            .put("Name", movie.name)
            .put("OtherName", movie.otherName)
            .put("Avatar", movie.avatar)
            .put("BannerThumb", movie.bannerThumb)
            .put("AvatarThumb", movie.avatarThumb)
            .put("Description", movie.description)
            .put("Banner", movie.banner)
            .put("ImageIcon", movie.imageIcon)
            .put("Link", movie.link)
            .put("Quanlity", movie.quantity)
            .put("Rating", movie.rating)
            .put("Year", movie.year)
            .put("StatusTitle", movie.statusTitle)
            .put("StatusRaw", movie.statusRaw)
            .put("StatusTMText", movie.statusText)
            .put("Director", movie.director)
            .put("Time", movie.time)
            .put("Trailer", movie.trailer)
            .put("ShowTimes", movie.showTimes)
            .put("MoreInfo", movie.moreInfo)
            .put("CastString", movie.castString)
            .put("EpisodesTotal", movie.episodesTotal)
            .put("ViewNumber", movie.viewNumber)
            .put("RatePoint", movie.ratePoint)
            .put("Photos", JSONArray(movie.photoUrls))
            .put("PreviewPhotos", JSONArray(movie.previewPhotoUrls))
        return json.toString()
    }

    fun decodeMovie(encodedMovie: String): MovieCard? {
        return runCatching { JSONObject(encodedMovie).toMovieCard() }.getOrNull()
    }
}

