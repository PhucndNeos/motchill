package com.motchill.androidcompose.core.security

import com.motchill.androidcompose.core.config.RemoteConfig
import com.motchill.androidcompose.core.config.RemoteConfigStore
import org.junit.Assert.assertEquals
import org.junit.Test

class MotchillPayloadCipherTest {
    @Test
    fun decryptsSaltedPayloadWithOpenSslDerivation() {
        RemoteConfigStore.setCurrentConfig(
            RemoteConfig(
                domain = "https://motchilltv.date",
                key = "sB7hP!c9X3@rVn\$5mGqT1eLzK!fU8dA2",
            ),
        )
        val cipher = "U2FsdGVkX19k2YTnEqBrdNQKqsRFTVMRa1o7Bz2KdZ8cKzJUHhnJ0jj/Q83Afoc/"

        assertEquals(
            "{\"hello\":\"world\"}",
            MotchillPayloadCipher.decrypt(cipher),
        )
    }
}
