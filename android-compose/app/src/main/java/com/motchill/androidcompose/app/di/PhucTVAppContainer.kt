package com.motchill.androidcompose.app.di

import android.content.Context
import com.motchill.androidcompose.BuildConfig
import com.motchill.androidcompose.core.supabase.DefaultSyncCoordinator
import com.motchill.androidcompose.core.supabase.SupabaseAuthManager
import com.motchill.androidcompose.core.supabase.SupabaseConfig
import com.motchill.androidcompose.core.supabase.SupabaseLikedMovieStore
import com.motchill.androidcompose.core.supabase.SupabasePlaybackPositionStore
import com.motchill.androidcompose.core.supabase.SupabaseRestClient
import com.motchill.androidcompose.core.supabase.SupabaseSessionStore
import com.motchill.androidcompose.core.network.PhucTVApiClient
import com.motchill.androidcompose.core.storage.LikedMovieStore
import com.motchill.androidcompose.core.storage.PlaybackPositionStore
import com.motchill.androidcompose.data.repository.DefaultPhucTVRepository
import com.motchill.androidcompose.data.repository.PhucTVRepository

object PhucTVAppContainer {
    private lateinit var appContext: Context
    private var initialized = false

    fun initialize(context: Context) {
        appContext = context.applicationContext
        initialized = true
    }

    val apiClient: PhucTVApiClient by lazy {
        PhucTVApiClient()
    }

    val supabaseConfig: SupabaseConfig by lazy {
        SupabaseConfig(
            baseUrl = BuildConfig.SUPABASE_URL,
            anonKey = BuildConfig.SUPABASE_ANON_KEY,
        )
    }

    val supabaseClient: SupabaseRestClient by lazy {
        SupabaseRestClient(supabaseConfig)
    }

    val authManager: SupabaseAuthManager by lazy {
        checkInitialized()
        SupabaseAuthManager(
            sessionStore = SupabaseSessionStore(appContext),
            client = supabaseClient,
        )
    }

    val remoteLikedMovieStore: SupabaseLikedMovieStore by lazy {
        SupabaseLikedMovieStore(supabaseClient, authManager)
    }

    val remotePlaybackPositionStore: SupabasePlaybackPositionStore by lazy {
        SupabasePlaybackPositionStore(supabaseClient, authManager)
    }

    val repository: PhucTVRepository by lazy {
        DefaultPhucTVRepository(apiClient)
    }

    val likedMovieStore: LikedMovieStore by lazy {
        checkInitialized()
        LikedMovieStore(
            context = appContext,
            authSessionProvider = authManager,
            remoteStore = remoteLikedMovieStore,
        )
    }

    val playbackPositionStore: PlaybackPositionStore by lazy {
        checkInitialized()
        PlaybackPositionStore(
            context = appContext,
            authSessionProvider = authManager,
            remoteStore = remotePlaybackPositionStore,
        )
    }

    val syncCoordinator: DefaultSyncCoordinator by lazy {
        DefaultSyncCoordinator(
            localLikedMovieStore = likedMovieStore,
            remoteLikedMovieStore = remoteLikedMovieStore,
            localPlaybackStore = playbackPositionStore,
            remotePlaybackStore = remotePlaybackPositionStore,
        ).also { authManager.attachSyncCoordinator(it) }
    }

    private fun checkInitialized() {
        check(initialized) {
            "PhucTVAppContainer must be initialized before accessing storage."
        }
    }
}
