package com.motchill.androidcompose.core.security

import org.junit.Assert.assertEquals
import org.junit.Test

class MotchillPayloadCipherTest {
    @Test
    fun decryptsSaltedPayloadWithOpenSslDerivation() {
        val cipher = "U2FsdGVkX19k2YTnEqBrdNQKqsRFTVMRa1o7Bz2KdZ8cKzJUHhnJ0jj/Q83Afoc/"

        assertEquals(
            "{\"hello\":\"world\"}",
            MotchillPayloadCipher.decrypt(cipher),
        )
    }
}
