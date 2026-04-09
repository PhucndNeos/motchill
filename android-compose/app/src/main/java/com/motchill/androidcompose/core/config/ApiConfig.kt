package com.motchill.androidcompose.core.config

import com.motchill.androidcompose.BuildConfig
import java.util.concurrent.TimeUnit

object ApiConfig {
    val baseUrl: String = BuildConfig.MOTCHILL_PUBLIC_API_BASE_URL.trimEnd('/')
    val requestTimeoutMillis: Long = TimeUnit.SECONDS.toMillis(20)

    fun headers(): Map<String, String> {
        return mapOf(
            "User-Agent" to "Mozilla/5.0 (MotchillAndroidCompose)",
            "Accept" to "application/json,text/plain,*/*",
        )
    }
}

