package com.motchill.androidcompose.feature.player

import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import com.motchill.androidcompose.core.config.ApiConfig
import okhttp3.OkHttpClient
import androidx.media3.datasource.okhttp.OkHttpDataSource
import java.security.KeyManagementException
import java.security.NoSuchAlgorithmException
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocketFactory
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

fun playbackTrustManager(): X509TrustManager {
    return object : X509TrustManager {
        override fun checkClientTrusted(chain: Array<out X509Certificate>, authType: String) = Unit

        override fun checkServerTrusted(chain: Array<out X509Certificate>, authType: String) = Unit

        override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
    }
}

fun playbackSslSocketFactory(
    trustManager: X509TrustManager = playbackTrustManager(),
): SSLSocketFactory {
    return try {
        val context = SSLContext.getInstance("TLS")
        context.init(null, arrayOf<TrustManager>(trustManager), SecureRandom())
        context.socketFactory
    } catch (exception: NoSuchAlgorithmException) {
        throw IllegalStateException("TLS is unavailable", exception)
    } catch (exception: KeyManagementException) {
        throw IllegalStateException("Unable to initialize playback SSL context", exception)
    }
}

fun playbackHttpClient(): OkHttpClient {
    val trustManager = playbackTrustManager()
    val sslSocketFactory = playbackSslSocketFactory(trustManager)
    val hostnameVerifier = HostnameVerifier { _, _ -> true }

    return OkHttpClient.Builder()
        .sslSocketFactory(sslSocketFactory, trustManager)
        .hostnameVerifier(hostnameVerifier)
        .followRedirects(true)
        .followSslRedirects(true)
        .build()
}

@OptIn(UnstableApi::class)
fun playbackDataSourceFactory(): OkHttpDataSource.Factory {
    return OkHttpDataSource.Factory(playbackHttpClient())
        .setDefaultRequestProperties(ApiConfig.headers())
}
