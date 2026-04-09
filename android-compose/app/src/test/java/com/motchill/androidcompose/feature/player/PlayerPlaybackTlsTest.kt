package com.motchill.androidcompose.feature.player

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import java.security.cert.X509Certificate

class PlayerPlaybackTlsTest {
    @Test
    fun `playback trust manager accepts server certificates without throwing`() {
        val trustManager = playbackTrustManager()

        assertNotNull(trustManager)
        assertEquals(0, trustManager.acceptedIssuers.size)
        trustManager.checkServerTrusted(emptyArray<X509Certificate>(), "RSA")
    }
}
