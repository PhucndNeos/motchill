package com.motchill.androidcompose.app.di

import android.content.Context
import com.motchill.androidcompose.core.network.MotchillApiClient
import com.motchill.androidcompose.core.storage.LikedMovieStore
import com.motchill.androidcompose.core.storage.PlaybackPositionStore
import com.motchill.androidcompose.data.repository.DefaultMotchillRepository
import com.motchill.androidcompose.data.repository.MotchillRepository

object MotchillAppContainer {
    private lateinit var appContext: Context
    private var initialized = false

    fun initialize(context: Context) {
        appContext = context.applicationContext
        initialized = true
    }

    val apiClient: MotchillApiClient by lazy {
        MotchillApiClient()
    }

    val repository: MotchillRepository by lazy {
        DefaultMotchillRepository(apiClient)
    }

    val likedMovieStore: LikedMovieStore by lazy {
        checkInitialized()
        LikedMovieStore(appContext)
    }

    val playbackPositionStore: PlaybackPositionStore by lazy {
        checkInitialized()
        PlaybackPositionStore(appContext)
    }

    private fun checkInitialized() {
        check(initialized) {
            "MotchillAppContainer must be initialized before accessing storage."
        }
    }
}
