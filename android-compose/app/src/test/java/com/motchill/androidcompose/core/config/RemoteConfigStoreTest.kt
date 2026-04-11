package com.motchill.androidcompose.core.config

import org.junit.Assert.assertEquals
import org.junit.Test

class RemoteConfigStoreTest {
    @Test
    fun parsesDomainAndKeyFromJson() {
        val config = RemoteConfigStore.parse(
            """
            {
              "domain": "https://motchilltv.date",
              "key": "secret-value"
            }
            """.trimIndent(),
        )

        assertEquals("https://motchilltv.date", config.domain)
        assertEquals("secret-value", config.key)
    }
}
