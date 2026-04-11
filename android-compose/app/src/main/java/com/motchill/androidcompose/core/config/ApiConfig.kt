package com.motchill.androidcompose.core.config

import java.util.concurrent.TimeUnit

object ApiConfig {
    val baseUrl: String
        get() = RemoteConfigStore.requireBaseUrl()
    val requestTimeoutMillis: Long = TimeUnit.SECONDS.toMillis(20)

    fun headers(): Map<String, String> {
        return mapOf(
            "User-Agent" to "Mozilla/5.0 (MotchillAndroidCompose)",
            "Accept" to "application/json,text/plain,*/*",
        )
    }
}

