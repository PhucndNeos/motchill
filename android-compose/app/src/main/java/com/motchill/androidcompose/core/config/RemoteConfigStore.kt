package com.motchill.androidcompose.core.config

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

data class RemoteConfig(
    val domain: String,
    val key: String,
)

object RemoteConfigStore {
    private const val CONFIG_URL =
        "https://gist.githubusercontent.com/phucnd0604/72a74d2e9bfeee2a004400cb5016dac1/raw/"

    @Volatile
    private var currentConfig: RemoteConfig? = null

    private val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .callTimeout(20, TimeUnit.SECONDS)
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .writeTimeout(20, TimeUnit.SECONDS)
            .build()
    }

    suspend fun refreshFromRemote(): RemoteConfig {
        val configText = withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url(CONFIG_URL)
                .get()
                .build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    throw IOException("HTTP ${response.code} for ${response.request.url}")
                }
                response.body?.string().orEmpty()
            }
        }

        val config = parse(configText)
        setCurrentConfig(config)
        return config
    }

    fun clear() {
        currentConfig = null
    }

    fun requireBaseUrl(): String {
        return requireNotNull(currentConfig) {
            "Remote config has not been loaded yet"
        }.domain.trimEnd('/')
    }

    fun requireKey(): String {
        return requireNotNull(currentConfig) {
            "Remote config has not been loaded yet"
        }.key
    }

    internal fun setCurrentConfig(remoteConfig: RemoteConfig) {
        currentConfig = remoteConfig
    }

    internal fun parse(jsonText: String): RemoteConfig {
        val json = JSONObject(jsonText)
        val domain = json.optString("domain").trim()
        val key = json.optString("key").trim()
        require(domain.isNotEmpty()) { "Remote config is missing domain" }
        require(key.isNotEmpty()) { "Remote config is missing key" }
        return RemoteConfig(
            domain = domain,
            key = key,
        )
    }
}
